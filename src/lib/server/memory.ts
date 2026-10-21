import { env } from '$env/dynamic/private';
import { json, type Cookies } from '@sveltejs/kit';
import { currentSession } from './auth';
import { memoryClient, memoryConfig, memorySubject } from './atomic-memory';

// Atomic Memory is optional: without complete server configuration the routes answer 404
// and the consultation, history and verdicts work exactly as before.
export function caseMemory() {
  const config = memoryConfig(env);
  if (!config) return null;
  const client = memoryClient(config);
  return { client, subject: (identity: string) => memorySubject(config, identity) };
}

export const memoryError = (status: number, code: string, message: string) => json({ error: { code, message } }, { status, headers: { 'cache-control': 'no-store' } });

// Every note route needs the feature enabled and a verified account session; the
// Atomic Memory user is always derived from that session, never from the request.
export async function noteContext(cookies: Cookies) {
  const memory = caseMemory();
  if (!memory) return { failure: memoryError(404, 'memory_disabled', 'Ruta no disponible.') };
  let session;
  try { session = await currentSession(cookies); }
  catch { return { failure: memoryError(503, 'service_unavailable', 'No pudimos comprobar tu sesión. Inténtalo de nuevo.') }; }
  if (!session) return { failure: memoryError(401, 'unauthorized', 'Inicia sesión para usar tus notas.') };
  return { memory: memory.client, session, subject: memory.subject(session.subject) };
}
export const memoryUnavailable = () => memoryError(503, 'memory_unavailable', 'No pudimos confirmar que tu nota se guardó. Puedes intentarlo de nuevo sin duplicarla.');
