// FIXTURE ONLY: a local fake of the Atomic Memory HTTP routes Everyday Trust uses, for
// tests and recorded demos. It is not Atomic Memory and must never be configured in
// production. Request and response fields follow the published atomicmemory-core OpenAPI
// (ingest/quick, search/fast, list, DELETE /v1/memories/:id); ranking is naive word overlap.
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

const words = text => new Set(String(text).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').match(/[a-z]{4,}/g) ?? []);

export function startAtomicMemoryFixture({ port = 0, apiKey = 'fixture-key' } = {}) {
  const memories = new Map();
  // mode: ok | error | slow | no-ids | null-body | malformed | delete-false | delete-empty.
  // failDeletesAfter: number of DELETEs that succeed before the rest answer 503.
  const state = { mode: 'ok', failDeletesAfter: Infinity, deletes: 0, requests: [] };
  const server = createServer(async (request, response) => {
    const url = new URL(request.url, 'http://fixture');
    let body = '';
    for await (const chunk of request) body += chunk;
    const input = body ? JSON.parse(body) : {};
    const userId = request.method === 'GET' || request.method === 'DELETE' ? url.searchParams.get('user_id') : input.user_id;
    state.requests.push({ method: request.method, path: url.pathname, query: Object.fromEntries(url.searchParams), userId, body: input });
    const send = (status, value) => { response.writeHead(status, { 'content-type': 'application/json' }); response.end(JSON.stringify(value)); };
    if (request.headers.authorization !== `Bearer ${apiKey}`) return send(401, { error: 'unauthorized' });
    if (state.mode === 'slow') return setTimeout(() => send(200, {}), 10_000).unref();
    if (state.mode === 'error') return send(503, { error: 'fixture unavailable', retryable: true });
    if (state.mode === 'null-body') { response.writeHead(200, { 'content-type': 'application/json' }); return response.end('null'); }
    if (state.mode === 'malformed') return send(200, { unexpected: true });
    if (!userId) return send(400, { error: 'user_id (string) is required' });
    const own = [...memories.values()].filter(memory => memory.user_id === userId && memory.deleted_at === null);
    if (request.method === 'POST' && url.pathname === '/v1/memories/ingest/quick') {
      if (!input.conversation || !input.source_site || input.skip_extraction !== true) return send(400, { error: 'conversation and source_site are required' });
      if (!['summary', 'redacted'].includes(input.content_class)) return send(422, { error_code: 'raw_content_rejected', error: 'supply content_class' });
      const existing = own.find(memory => input.metadata?.externalId && memory.metadata.externalId === input.metadata.externalId);
      const now = new Date().toISOString();
      if (existing) Object.assign(existing, { content: input.conversation, metadata: { ...existing.metadata, ...input.metadata }, observed_at: now });
      const memory = existing ?? { id: randomUUID(), user_id: userId, content: input.conversation, source_site: input.source_site, metadata: input.metadata ?? {}, created_at: now, observed_at: now, deleted_at: null };
      memories.set(memory.id, memory);
      if (state.mode === 'no-ids') return send(200, { episode_id: randomUUID(), facts_extracted: 0, memories_stored: 0, memories_updated: 0, memories_deleted: 0, memories_skipped: 1, stored_memory_ids: [], updated_memory_ids: [], links_created: 0, composites_created: 0 });
      return send(200, { episode_id: randomUUID(), facts_extracted: 0, memories_stored: existing ? 0 : 1, memories_updated: existing ? 1 : 0, memories_deleted: 0, memories_skipped: 0, stored_memory_ids: existing ? [] : [memory.id], updated_memory_ids: existing ? [memory.id] : [], links_created: 0, composites_created: 0 });
    }
    if (request.method === 'POST' && url.pathname === '/v1/memories/search/fast') {
      const query = words(input.query);
      const ranked = own.filter(memory => !input.source_site || memory.source_site === input.source_site).map(memory => {
        const content = words(memory.content);
        const relevance = query.size ? [...query].filter(word => content.has(word)).length / query.size : 0;
        return { ...memory, relevance, similarity: relevance, score: relevance };
      }).filter(memory => memory.relevance >= (input.threshold ?? 0)).sort((a, b) => b.relevance - a.relevance).slice(0, input.limit ?? 10);
      return send(200, { count: ranked.length, retrieval_mode: 'flat', scope: { kind: 'user', userId }, retrieval: {}, memories: ranked, budget_constrained: false, deterministic: true });
    }
    if (request.method === 'GET' && url.pathname === '/v1/memories/list') {
      const offset = Number(url.searchParams.get('offset') ?? 0), limit = Math.min(Number(url.searchParams.get('limit') ?? 20), 100);
      const listed = own.filter(memory => !url.searchParams.get('source_site') || memory.source_site === url.searchParams.get('source_site')).slice(offset, offset + limit);
      return send(200, { count: listed.length, memories: listed });
    }
    const match = url.pathname.match(/^\/v1\/memories\/([A-Za-z0-9-]+)$/);
    if (request.method === 'DELETE' && match) {
      const memory = memories.get(match[1]);
      if (!memory || memory.user_id !== userId || memory.deleted_at) return send(404, { error: 'Memory not found' });
      if (state.mode === 'delete-false') return send(200, { success: false });
      if (state.mode === 'delete-empty') return send(200, {});
      if (++state.deletes > state.failDeletesAfter) return send(503, { error: 'fixture unavailable', retryable: true });
      memory.deleted_at = new Date().toISOString();
      return send(200, { success: true });
    }
    send(404, { error: 'not found' });
  });
  return new Promise(resolve => server.listen(port, '127.0.0.1', () => resolve({
    url: `http://127.0.0.1:${server.address().port}`, state, memories,
    close: () => new Promise(done => { server.closeAllConnections(); server.close(done); })
  })));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.argv[process.argv.indexOf('--port') + 1] || 4612);
  const fixture = await startAtomicMemoryFixture({ port, apiKey: process.env.ATOMICMEMORY_API_KEY ?? 'fixture-key' });
  console.log(`FIXTURE: local fake Atomic Memory provider (not the real service) at ${fixture.url}`);
}
