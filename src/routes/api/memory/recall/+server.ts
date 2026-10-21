import { json, type RequestHandler } from '@sveltejs/kit';
import { apiRead } from '$lib/server/api';
import { noteContext } from '$lib/server/memory';
import { isRecord } from '$lib/server/atomic-memory';

// Finds the holder's notes on similar saved cases for a finished consultation. The query is
// built on the server from the reviewed result, never from the original message or links. Failures
// return no notes: recall is optional context and must never delay or alter the verdict.
export const POST: RequestHandler = async ({ cookies, request, getClientAddress }) => {
  const context = await noteContext(cookies);
  if (context.failure) return context.failure;
  const body: unknown = await request.json().catch(() => null);
  if (!isRecord(body) || typeof body.case_id !== 'string' || !/^[a-f0-9-]{36}$/.test(body.case_id)) return json({ notes: [] }, { status: 400 });
  try {
    const result = await apiRead(`cases/${body.case_id}`, cookies, context.session.access, getClientAddress());
    if (!isRecord(result) || result.analysis_status !== 'completed' || typeof result.summary !== 'string' || typeof result.id !== 'string' || !Array.isArray(result.signals)) return json({ notes: [] });
    // Only the fixed summary and static signal codes form the query, never message text.
    const notes = await context.memory.recall(context.subject, { summary: result.summary, signals: result.signals.map(signal => isRecord(signal) ? signal.id : null), caseId: result.id });
    return json({ notes }, { headers: { 'cache-control': 'no-store' } });
  } catch { return json({ notes: [], unavailable: true }, { headers: { 'cache-control': 'no-store' } }); }
};
