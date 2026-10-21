import { test } from 'node:test';
import assert from 'node:assert/strict';
import { memoryClient, memoryConfig, memorySubject, redactNote, toNote, MemoryUnavailable, PurgeIncomplete } from '../src/lib/server/atomic-memory.ts';
import { startAtomicMemoryFixture } from './fixtures/atomic-memory-fixture.mjs';

// All Atomic Memory traffic here goes to the local labelled fixture, never the real service.
const subjectKey = 'synthetic-subject-key-for-tests-only-0123456789';
const environment = url => ({ ATOMICMEMORY_ENABLED: 'true', ATOMICMEMORY_API_URL: url, ATOMICMEMORY_API_KEY: 'fixture-key', ATOMICMEMORY_SUBJECT_KEY: subjectKey, ATOMICMEMORY_TIMEOUT_MS: '600' });
const bankCase = {
  savedCaseId: '11111111-1111-4111-8111-111111111111', caseId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', analyzedAt: '2026-10-18T10:00:00Z', verdict: 'high_risk',
  summary: 'Hay varias señales de riesgo. Haz una pausa y verifica antes de actuar.',
  signals: ['asks_credentials', 'urgency', 'Texto libre https://bcp.example/x', 42],
  note: 'Me escribieron como el banco; llamé al número de mi tarjeta y no era real.'
};
const caseId = index => `${String(index).padStart(8, '0')}-2222-4222-8222-222222222222`;

async function withFixture(run) {
  const fixture = await startAtomicMemoryFixture();
  const config = memoryConfig(environment(fixture.url));
  try { await run({ fixture, config, client: memoryClient(config) }); } finally { await fixture.close(); }
}

test('the feature stays off unless it is explicitly and completely configured', () => {
  assert.equal(memoryConfig({}), null);
  assert.equal(memoryConfig({ ...environment('http://127.0.0.1:1'), ATOMICMEMORY_ENABLED: 'false' }), null);
  assert.equal(memoryConfig({ ...environment('http://127.0.0.1:1'), ATOMICMEMORY_API_KEY: '' }), null);
  assert.equal(memoryConfig({ ...environment('http://127.0.0.1:1'), ATOMICMEMORY_SUBJECT_KEY: 'short' }), null);
  assert.equal(memoryConfig(environment('http://memory.example.com')), null, 'plain HTTP is only accepted on loopback');
  assert.equal(memoryConfig(environment('https://user:pass@api.atomicstrata.ai')), null);
  assert.equal(memoryConfig(environment('https://api.atomicstrata.ai?x=1')), null);
  assert.equal(memoryConfig(environment('https://api.atomicstrata.ai#fragment')), null);
  assert.ok(memoryConfig(environment('https://api.atomicstrata.ai')));
});

test('the memory user is a stable keyed hash of the verified subject', () => {
  const config = memoryConfig(environment('https://api.atomicstrata.ai'));
  assert.equal(memorySubject(config, 'cognito-alice'), memorySubject(config, 'cognito-alice'));
  assert.notEqual(memorySubject(config, 'cognito-alice'), memorySubject(config, 'cognito-bob'));
  assert.ok(!memorySubject(config, 'cognito-alice').includes('alice'));
  assert.notEqual(memorySubject(config, 'cognito-alice'), memorySubject({ ...config, subjectKey: `${subjectKey}-rotated` }, 'cognito-alice'));
});

test('contact and payment data is masked before a note leaves the site', () => {
  assert.equal(redactNote('Me llamó el +51 987 654 321, escribí a ana@example.com y abrí https://bcp-valida.example/x'),
    'Me llamó el [número omitido], escribí a [dato omitido] y abrí [enlace omitido]');
  assert.equal(redactNote('Código 4821'), 'Código [número omitido]');
  assert.equal(redactNote('x'.repeat(400)).length, 280);
});

test('only the fixed summary, static signal codes and the redacted note reach the provider', () => withFixture(async ({ fixture, config, client }) => {
  const alice = memorySubject(config, 'cognito-alice');
  await client.save(alice, { ...bankCase, note: 'Me pidieron el código 123456 desde https://bcp-valida.example' });
  await client.recall(alice, { summary: bankCase.summary, signals: bankCase.signals, caseId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' });
  const sent = JSON.stringify(fixture.state.requests.map(entry => entry.body));
  for (const leaked of ['123456', 'bcp-valida', 'bcp.example', 'Texto libre']) assert.ok(!sent.includes(leaked), leaked);
  const ingest = fixture.state.requests.find(entry => entry.path === '/v1/memories/ingest/quick').body;
  assert.deepEqual(ingest.metadata.signals, ['asks_credentials', 'urgency']);
  assert.equal(ingest.content_class, 'redacted');
  assert.equal(ingest.skip_extraction, true);
  assert.ok(!('session_id' in ingest) && !('workspace_id' in ingest) && !('agent_id' in ingest), 'identity is user scope only, never a shared thread');
}));

test('a saved note is recalled for a similar later case and a correction updates it in place', () => withFixture(async ({ fixture, config, client }) => {
  const alice = memorySubject(config, 'cognito-alice');
  const saved = await client.save(alice, bankCase);
  assert.equal(saved.note, bankCase.note);
  assert.equal(fixture.state.requests.at(-1).body.metadata.externalId, `saved-case:${bankCase.savedCaseId}`);

  const later = await client.recall(alice, { summary: bankCase.summary, signals: ['asks_credentials'], caseId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' });
  assert.deepEqual(later.map(note => note.note), [bankCase.note]);
  assert.deepEqual(await client.recall(alice, { summary: bankCase.summary, signals: ['asks_credentials'], caseId: bankCase.caseId }), [], 'the same analysis is not offered its own note');

  const corrected = await client.save(alice, { ...bankCase, note: 'Corrección: era el banco falso; lo reporté y bloqueé el número.' });
  assert.equal(corrected.id, saved.id);
  const notes = await client.list(alice);
  assert.equal(notes.length, 1);
  assert.equal(notes[0].note, 'Corrección: era el banco falso; lo reporté y bloqueé el número.');
}));

test('one account never lists, recalls or deletes another account notes', () => withFixture(async ({ config, client }) => {
  const alice = memorySubject(config, 'cognito-alice'), bob = memorySubject(config, 'cognito-bob');
  const saved = await client.save(alice, bankCase);
  const query = { summary: bankCase.summary, signals: bankCase.signals, caseId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' };
  assert.deepEqual(await client.list(bob), []);
  assert.deepEqual(await client.recall(bob, query), []);
  assert.equal(await client.remove(bob, saved.id), false);
  assert.equal(await client.purge(bob, () => true), 0);
  assert.equal((await client.list(alice)).length, 1);
  assert.equal(await client.remove(alice, saved.id), true);
  assert.deepEqual(await client.list(alice), []);
  assert.deepEqual(await client.recall(alice, query), []);
}));

test('a delete is confirmed only by the documented success:true body', () => withFixture(async ({ fixture, config, client }) => {
  const alice = memorySubject(config, 'cognito-alice');
  const saved = await client.save(alice, bankCase);
  for (const mode of ['delete-false', 'delete-empty', 'null-body', 'error']) {
    fixture.state.mode = mode;
    await assert.rejects(client.remove(alice, saved.id), MemoryUnavailable, mode);
    fixture.state.mode = 'ok';
    assert.equal((await client.list(alice)).length, 1, `${mode} leaves the note in place`);
  }
  assert.equal(await client.remove(alice, saved.id), true);
}));

test('cleanup pages past the first 100 notes and removes every one of them', () => withFixture(async ({ fixture, config, client }) => {
  const alice = memorySubject(config, 'cognito-alice'), bob = memorySubject(config, 'cognito-bob');
  for (let index = 0; index < 230; index++) await client.save(alice, { ...bankCase, savedCaseId: caseId(index) });
  await client.save(bob, bankCase);
  assert.equal((await client.list(alice)).length, 230);
  const offsets = fixture.state.requests.filter(entry => entry.path === '/v1/memories/list').map(entry => entry.query.offset);
  assert.deepEqual(offsets, ['0', '100', '200']);
  assert.equal(await client.purge(alice, () => true), 230);
  assert.deepEqual(await client.list(alice), []);
  assert.equal((await client.list(bob)).length, 1, 'another account is untouched');
}));

test('a partial cleanup reports exactly how many notes were removed and how many remain', () => withFixture(async ({ fixture, config, client }) => {
  const alice = memorySubject(config, 'cognito-alice');
  for (let index = 0; index < 5; index++) await client.save(alice, { ...bankCase, savedCaseId: caseId(index) });
  fixture.state.failDeletesAfter = 2;
  const failure = await client.purge(alice, () => true).catch(error => error);
  assert.ok(failure instanceof PurgeIncomplete);
  assert.equal(failure.removed, 2);
  assert.equal(failure.remaining, 3);
  assert.equal((await client.list(alice)).length, 3);
  fixture.state.failDeletesAfter = Infinity;
  assert.equal(await client.purge(alice, () => true), 3, 'a retry finishes the cleanup');
}));

test('provider errors, timeouts and malformed success bodies never report a note as saved or listed', () => withFixture(async ({ fixture, config, client }) => {
  const alice = memorySubject(config, 'cognito-alice');
  const query = { summary: bankCase.summary, signals: bankCase.signals, caseId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' };
  for (const mode of ['error', 'slow', 'no-ids', 'null-body', 'malformed']) {
    fixture.state.mode = mode;
    const started = Date.now();
    await assert.rejects(client.save(alice, bankCase), MemoryUnavailable, mode);
    assert.ok(Date.now() - started < 2000, `${mode} stays within the request bound`);
    if (mode !== 'no-ids') {
      await assert.rejects(client.recall(alice, query), MemoryUnavailable, `recall ${mode}`);
      await assert.rejects(client.list(alice), MemoryUnavailable, `list ${mode}`);
    }
  }
  fixture.state.mode = 'ok';
  await assert.rejects(memoryClient({ ...config, apiKey: 'wrong' }).save(alice, bankCase), MemoryUnavailable);
}));

test('oversized provider bodies are rejected without being buffered', async () => {
  const config = memoryConfig(environment('http://127.0.0.1:1'));
  const huge = async () => new Response(JSON.stringify({ memories: ['x'.repeat(1_100_000)] }), { status: 200 });
  await assert.rejects(memoryClient(config, huge).list('subject'), MemoryUnavailable);
  const declared = async () => new Response('{}', { status: 200, headers: { 'content-length': '5000000' } });
  await assert.rejects(memoryClient(config, declared).list('subject'), MemoryUnavailable);
});

test('records this app did not write, or with altered metadata, are ignored', () => {
  const metadata = { externalId: `saved-case:${bankCase.savedCaseId}`, app: 'everyday-trust', saved_case_id: bankCase.savedCaseId, case_id: bankCase.caseId, analyzed_at: bankCase.analyzedAt, verdict: 'high_risk', summary: bankCase.summary, note: bankCase.note, updated_at: 'now' };
  assert.ok(toNote({ id: 'ok', metadata }));
  for (const memory of [null, 7, 'text', [], { id: 'x' }, { id: 'x', metadata: null }, { id: 'x', metadata: [] },
    { id: 'x', metadata: { ...metadata, app: 'other-app' } }, { id: 'x', metadata: { ...metadata, verdict: 'safe' } },
    { id: 'x', metadata: { ...metadata, externalId: 'saved-case:other' } }, { id: 'x', metadata: { ...metadata, note: 12 } }])
    assert.equal(toNote(memory), null, JSON.stringify(memory));
});

test('cleanup refuses malformed or explicitly foreign rows instead of claiming all notes were removed', async () => {
  const config = memoryConfig(environment('http://127.0.0.1:1'));
  for (const row of [{ id: 'broken', metadata: { app: 'everyday-trust' } }, {
    id: '11111111-1111-4111-8111-111111111111', user_id: 'another-subject',
    metadata: { app: 'everyday-trust', externalId: `saved-case:${bankCase.savedCaseId}`, saved_case_id: bankCase.savedCaseId, case_id: bankCase.caseId,
      verdict: bankCase.verdict, analyzed_at: bankCase.analyzedAt, summary: bankCase.summary, note: bankCase.note, updated_at: bankCase.analyzedAt }
  }]) {
    const calls = [];
    const client = memoryClient(config, async (url, init) => {
      calls.push(init.method);
      return new Response(JSON.stringify({ memories: [row] }), { headers: { 'content-type': 'application/json' } });
    });
    await assert.rejects(client.purge('my-subject', () => true), MemoryUnavailable);
    assert.deepEqual(calls, ['GET']);
  }
});

test('another case analyzed at the same instant still recalls the saved note', () => withFixture(async ({ config, client }) => {
  const subject = memorySubject(config, 'alice');
  await client.save(subject, bankCase);
  const notes = await client.recall(subject, { summary: bankCase.summary, signals: bankCase.signals, caseId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' });
  assert.deepEqual(notes.map(note => note.note), [bankCase.note]);
  assert.deepEqual(await client.recall(subject, { summary: bankCase.summary, signals: bankCase.signals, caseId: bankCase.caseId }), []);
}));
