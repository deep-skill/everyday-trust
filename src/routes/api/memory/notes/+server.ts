import { json, type RequestHandler } from '@sveltejs/kit';
import { apiRead } from '$lib/server/api';
import { MemoryUnavailable, isRecord, parseVerdict } from '$lib/server/atomic-memory';
import { memoryError, memoryUnavailable, noteContext } from '$lib/server/memory';

export const GET: RequestHandler = async ({ cookies }) => {
  const context = await noteContext(cookies);
  if (context.failure) return context.failure;
  try { return json({ notes: await context.memory.list(context.subject) }, { headers: { 'cache-control': 'no-store' } }); }
  catch (error) { if (error instanceof MemoryUnavailable) return memoryError(503, 'memory_unavailable', 'No pudimos cargar tus notas ahora.'); throw error; }
};

// Saves or corrects the note for one saved case. The case summary and verdict come from
// Phoenix through the holder's own token, so the browser cannot attach a note to a case
// it does not own or rewrite the reviewed result. `case_id` is the saved row's original case,
// used only so a case is not shown its own note.
export const POST: RequestHandler = async ({ cookies, request, getClientAddress }) => {
  const context = await noteContext(cookies);
  if (context.failure) return context.failure;
  const body: unknown = await request.json().catch(() => null);
  if (!isRecord(body) || typeof body.saved_case_id !== 'string' || !/^[a-f0-9-]{36}$/.test(body.saved_case_id) || typeof body.note !== 'string' || !body.note.trim() || body.note.length > 280)
    return memoryError(400, 'invalid_note', 'Escribe una nota de hasta 280 caracteres.');
  let saved: unknown;
  try { saved = await apiRead(`history/${body.saved_case_id}`, cookies, context.session.access, getClientAddress()); }
  catch { return memoryError(503, 'service_unavailable', 'No pudimos comprobar el resultado guardado.'); }
  if (!isRecord(saved) || !isRecord(saved.result)) return memoryError(404, 'not_found', 'No encontramos ese resultado guardado.');
  const { result } = saved, verdict = parseVerdict(result.verdict);
  if (!verdict || saved.id !== body.saved_case_id || typeof result.summary !== 'string' || typeof result.analyzed_at !== 'string' || typeof saved.case_id !== 'string')
    return memoryError(503, 'service_unavailable', 'No pudimos comprobar el resultado guardado.');
  try {
    const signals = Array.isArray(result.signals) ? result.signals.map(signal => isRecord(signal) ? signal.id : null) : [];
    const note = await context.memory.save(context.subject, { savedCaseId: body.saved_case_id, caseId: saved.case_id, analyzedAt: result.analyzed_at, verdict, summary: result.summary, signals, note: body.note });
    return json({ note }, { headers: { 'cache-control': 'no-store' } });
  } catch (error) {
    if (error instanceof MemoryUnavailable) return memoryUnavailable();
    if (error instanceof TypeError) return memoryError(400, 'invalid_note', 'Escribe una nota de hasta 280 caracteres.');
    throw error;
  }
};
