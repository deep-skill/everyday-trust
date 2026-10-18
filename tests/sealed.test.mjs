import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { sealPayload, openPayload } from '../src/lib/server/sealed.ts';

test('session ciphertext cannot be replayed under another row or purpose', () => {
  const key = randomBytes(32);
  const payload = { access: 'synthetic-access', refresh: 'synthetic-refresh' };
  const sealed = sealPayload(payload, key, 'session:alice');
  assert.deepEqual(openPayload(sealed, key, 'session:alice'), payload);
  assert.throws(() => openPayload(sealed, key, 'session:bob'));
  assert.throws(() => openPayload(sealed, key, 'attempt:alice'));
  assert.ok(!sealed.includes(payload.refresh));
});
test('modified ciphertext and a rotated encryption key are rejected', () => {
  const key = randomBytes(32);
  const sealed = sealPayload({ access: 'synthetic' }, key, 'session:alice');
  const bytes = Buffer.from(sealed, 'base64');
  bytes[bytes.length - 1] ^= 1;
  assert.throws(() => openPayload(bytes.toString('base64'), key, 'session:alice'));
  assert.throws(() => openPayload(sealed, randomBytes(32), 'session:alice'));
  assert.notEqual(sealed, sealPayload({ access: 'synthetic' }, key, 'session:alice'));
});
