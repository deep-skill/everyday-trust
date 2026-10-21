import { createHmac } from 'node:crypto';
import type { CaseNote, CaseVerdict } from '../cases';

// Personal notes about saved cases, stored in Atomic Memory through its HTTP API
// (POST /v1/memories/ingest/quick, POST /v1/memories/search/fast, GET /v1/memories/list,
// DELETE /v1/memories/:id). Notes are reference context for the account holder only:
// they never change a verdict, a signal or an emergency step.
//
// Only three things cross to the provider: the fixed server summary of the verdict, the
// static signal codes (for example `asks_credentials`) and the holder's redacted note.
// The original message, links, numbers and signal texts never do.

export interface MemoryConfig { apiUrl: URL; apiKey: string; subjectKey: string; timeoutMs: number }
type Fetch = typeof fetch;
type Environment = Record<string, string | undefined>;
type JsonRecord = Record<string, unknown>;

/** The provider failed, timed out or answered outside its documented contract. */
export class MemoryUnavailable extends Error {}
/** Some notes were removed and others could not be; `removed` counts the confirmed ones. */
export class PurgeIncomplete extends Error {
  readonly removed: number;
  readonly remaining: number;
  constructor(removed: number, remaining: number) { super('Atomic Memory cleanup incomplete'); this.removed = removed; this.remaining = remaining; }
}

const app = 'everyday-trust';
const uuid = /^[a-f0-9-]{36}$/;
const signalCode = /^[a-z][a-z0-9_]{1,47}$/;
const verdicts: readonly CaseVerdict[] = ['high_risk', 'suspicious', 'no_signals_detected', 'inconclusive'];
export const noteLimit = 280;
const pageSize = 100, maxPages = 50, maxBodyBytes = 1_048_576;

export const isRecord = (value: unknown): value is JsonRecord => typeof value === 'object' && value !== null && !Array.isArray(value);
export const parseVerdict = (value: unknown): CaseVerdict | null => verdicts.find(verdict => verdict === value) ?? null;
const text = (value: unknown, limit: number) => typeof value === 'string' ? value.slice(0, limit) : null;
export const signalCodes = (ids: readonly unknown[]) => [...new Set(ids.filter((id): id is string => typeof id === 'string' && signalCode.test(id)))].slice(0, 8);

export function memoryConfig(env: Environment): MemoryConfig | null {
  const apiKey = env.ATOMICMEMORY_API_KEY, subjectKey = env.ATOMICMEMORY_SUBJECT_KEY;
  if (env.ATOMICMEMORY_ENABLED !== 'true' || !env.ATOMICMEMORY_API_URL || !apiKey || !subjectKey || subjectKey.length < 32) return null;
  let apiUrl: URL;
  try { apiUrl = new URL(env.ATOMICMEMORY_API_URL); } catch { return null; }
  // HTTPS is required; plain HTTP is only accepted on loopback for the local fixture.
  const loopback = apiUrl.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(apiUrl.hostname);
  if ((apiUrl.protocol !== 'https:' && !loopback) || apiUrl.username || apiUrl.password || apiUrl.search || apiUrl.hash) return null;
  const timeout = Number(env.ATOMICMEMORY_TIMEOUT_MS ?? 2500);
  return { apiUrl, apiKey, subjectKey, timeoutMs: Number.isFinite(timeout) ? Math.min(Math.max(timeout, 500), 5000) : 2500 };
}

// The Atomic Memory user is an HMAC of the verified Cognito subject: stable per account,
// never chosen by the browser and not the raw identity-provider id.
export function memorySubject(config: MemoryConfig, subject: string) {
  return `et_${createHmac('sha256', config.subjectKey).update(`atomicmemory-user:${subject}`).digest('hex')}`;
}

// Text leaves the site, so obvious contact and payment data is masked before saving.
export function redactNote(value: string) {
  return value.normalize('NFC').replace(/\s+/g, ' ').trim().slice(0, noteLimit)
    .replace(/[^\s@]+@[^\s@]+\.[^\s@]+/g, '[dato omitido]')
    .replace(/\b(?:https?:\/\/|www\.)\S+/gi, '[enlace omitido]')
    .replace(/\+?\d(?:[\s.-]?\d){3,}/g, '[número omitido]');
}

export function toNote(memory: unknown, expectedSubject?: string): CaseNote | null {
  if (!isRecord(memory) || typeof memory.id !== 'string' || !isRecord(memory.metadata)) return null;
  if (expectedSubject !== undefined && memory.user_id !== undefined && memory.user_id !== expectedSubject) return null;
  const metadata = memory.metadata;
  const savedCaseId = text(metadata.saved_case_id, 36), caseId = text(metadata.case_id, 36), verdict = parseVerdict(metadata.verdict);
  const analyzedAt = text(metadata.analyzed_at, 40), summary = text(metadata.summary, 400), note = text(metadata.note, noteLimit), updatedAt = text(metadata.updated_at, 40);
  if (metadata.app !== app || !savedCaseId || !uuid.test(savedCaseId) || !caseId || !uuid.test(caseId) || metadata.externalId !== `saved-case:${savedCaseId}`) return null;
  if (!verdict || analyzedAt === null || summary === null || !note || updatedAt === null) return null;
  return { id: memory.id, saved_case_id: savedCaseId, case_id: caseId, analyzed_at: analyzedAt, verdict, summary, note, updated_at: updatedAt };
}

async function readBody(response: Response): Promise<JsonRecord> {
  if (Number(response.headers.get('content-length') ?? 0) > maxBodyBytes || !response.body) throw new MemoryUnavailable();
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = []; let size = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > maxBodyBytes) { await reader.cancel(); throw new MemoryUnavailable(); }
    chunks.push(value);
  }
  let value: unknown;
  try { value = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw new MemoryUnavailable(); }
  if (!isRecord(value)) throw new MemoryUnavailable();
  return value;
}

function memories(body: JsonRecord) {
  if (!Array.isArray(body.memories)) throw new MemoryUnavailable();
  return body.memories;
}

export function memoryClient(config: MemoryConfig, fetcher: Fetch = fetch) {
  async function call(path: string, init: { method?: string; query?: Record<string, string>; body?: unknown } = {}) {
    const url = new URL(path, config.apiUrl);
    for (const [name, value] of Object.entries(init.query ?? {})) url.searchParams.set(name, value);
    let response: Response;
    try {
      response = await fetcher(url, {
        method: init.method ?? 'GET', redirect: 'error', signal: AbortSignal.timeout(config.timeoutMs),
        headers: { authorization: `Bearer ${config.apiKey}`, 'content-type': 'application/json' },
        ...(init.body === undefined ? {} : { body: JSON.stringify(init.body) })
      });
    } catch { throw new MemoryUnavailable(); }
    if (response.status === 404) { await response.body?.cancel(); return null; }
    if (!response.ok) { await response.body?.cancel(); throw new MemoryUnavailable(); }
    try { return await readBody(response); }
    catch (error) { throw error instanceof MemoryUnavailable ? error : new MemoryUnavailable(); }
  }
  async function required(path: string, init?: Parameters<typeof call>[1]) {
    const body = await call(path, init);
    if (!body) throw new MemoryUnavailable();
    return body;
  }
  // Every page of the documented limit/offset listing, so cleanup never stops at the first page.
  async function listAll(subject: string) {
    const all: CaseNote[] = [];
    for (let page = 0; page < maxPages; page++) {
      const rows = memories(await required('/v1/memories/list', { query: { user_id: subject, source_site: app, limit: String(pageSize), offset: String(page * pageSize) } }));
      for (const row of rows) {
        const note = toNote(row, subject);
        // Cleanup cannot promise completion if a returned row cannot be attributed and parsed.
        if (!note) throw new MemoryUnavailable();
        all.push(note);
      }
      if (rows.length < pageSize) return all;
    }
    throw new MemoryUnavailable();
  }
  // DELETE /v1/memories/:id documents `{ success: true }`. A 404 means already absent;
  // any other answer is treated as not deleted.
  async function remove(subject: string, id: string) {
    if (!/^[A-Za-z0-9-]{1,64}$/.test(id)) return false;
    const body = await call(`/v1/memories/${encodeURIComponent(id)}`, { method: 'DELETE', query: { user_id: subject } });
    if (body === null) return false;
    if (body.success !== true) throw new MemoryUnavailable();
    return true;
  }
  return {
    // Verbatim ingest keyed by externalId: saving again for the same saved case corrects
    // the existing record in place instead of adding a second note.
    async save(subject: string, input: { savedCaseId: string; caseId: string; analyzedAt: string; verdict: CaseVerdict; summary: string; signals: readonly unknown[]; note: string }): Promise<CaseNote> {
      const note = redactNote(input.note), summary = redactNote(input.summary), signals = signalCodes(input.signals);
      if (!note || !uuid.test(input.savedCaseId) || !uuid.test(input.caseId) || !parseVerdict(input.verdict)) throw new TypeError('Invalid note');
      const metadata = { externalId: `saved-case:${input.savedCaseId}`, app, saved_case_id: input.savedCaseId, case_id: input.caseId, analyzed_at: input.analyzedAt.slice(0, 40), verdict: input.verdict, summary, signals, note, updated_at: new Date().toISOString() };
      const result = await required('/v1/memories/ingest/quick', { method: 'POST', body: {
        user_id: subject, source_site: app, skip_extraction: true, content_class: 'redacted', metadata,
        conversation: `Nota personal sobre un caso guardado en Everyday Trust. Resultado revisado: ${summary} Señales: ${signals.join(' ') || 'ninguna'}. Nota: ${note}`
      } });
      const stored = result.stored_memory_ids, updated = result.updated_memory_ids;
      if (!Array.isArray(stored) || !Array.isArray(updated)) throw new MemoryUnavailable();
      const id: unknown = [...stored, ...updated][0];
      if (typeof id !== 'string') throw new MemoryUnavailable();
      return { id, saved_case_id: metadata.saved_case_id, case_id: metadata.case_id, analyzed_at: metadata.analyzed_at, verdict: input.verdict, summary, note, updated_at: metadata.updated_at };
    },
    list: listAll,
    // Exclude the same analysis by its ID, so simultaneous analyses remain independent.
    async recall(subject: string, input: { summary: string; signals: readonly unknown[]; caseId: string }): Promise<CaseNote[]> {
      const query = `${redactNote(input.summary)} Señales: ${signalCodes(input.signals).join(' ')}`;
      const result = await required('/v1/memories/search/fast', { method: 'POST', body: { user_id: subject, source_site: app, query, limit: 5, threshold: 0.3 } });
      return memories(result).map(row => toNote(row, subject)).filter((note): note is CaseNote => note !== null && note.case_id !== input.caseId).slice(0, 2);
    },
    remove,
    // Removes every matching note, reporting exactly how many were confirmed deleted.
    async purge(subject: string, matches: (note: CaseNote) => boolean) {
      const targets = (await listAll(subject)).filter(matches);
      let removed = 0;
      for (const note of targets) {
        try { await remove(subject, note.id); removed++; }
        catch { throw new PurgeIncomplete(removed, targets.length - removed); }
      }
      return removed;
    }
  };
}
export type MemoryClient = ReturnType<typeof memoryClient>;
