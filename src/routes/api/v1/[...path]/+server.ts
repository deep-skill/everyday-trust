import { json, type RequestHandler } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { authCookie, cookieOptions, currentSession } from '$lib/server/auth';
import { database } from '$lib/server/database';
import { apiHeaders } from '$lib/server/api';
import { caseMemory } from '$lib/server/memory';
import { PurgeIncomplete } from '$lib/server/atomic-memory';

const allowed: Record<string, RegExp> = {
  GET: /^(health|stats|radar|me|history|history\/[a-f0-9-]{36}|cases\/[a-f0-9-]{36})$/,
  POST: /^(visits|cases|image-cases|cases\/[a-f0-9-]{36}\/(save|messages|feedback|review|community))$/,
  DELETE: /^(me|history\/[a-f0-9-]{36}|cases\/[a-f0-9-]{36}\/review)$/
};
const proxy: RequestHandler = async ({ cookies, params, request, url, getClientAddress }) => {
  const path = params.path ?? '';
  if (path === 'image-cases' && env.IMAGE_INPUT_ENABLED !== 'true') return json({ error: { message: 'Ruta no disponible.' } }, { status: 404 });
  if (!allowed[request.method]?.test(path)) return json({ error: { message: 'Ruta no disponible.' } }, { status: 404 });
  if (!env.API_BASE_URL || !env.API_SERVICE_TOKEN) return json({ error: { code: 'api_unavailable', message: 'El servicio está iniciando. Inténtalo en unos momentos.' } }, { status: 503 });
  try {
    const session = await currentSession(cookies);
    const headers = apiHeaders(cookies, session?.access ?? null, path === 'health' ? 'health-check' : getClientAddress());
    // Deleting a saved case or the account also removes the matching notes from Atomic
    // Memory first; if any note remains, the case or account is not deleted and the user can retry.
    // Account deletion only cleans up when Phoenix will accept it (login within five minutes).
    const memory = caseMemory();
    const recentLogin = session && Date.now() / 1000 - session.authTime <= 300;
    const cleanup = request.method !== 'DELETE' ? null : path === 'me' ? (recentLogin ? 'all' : null) : path.startsWith('history/') ? path.slice(8) : null;
    if (session && memory && cleanup) {
      const subject = memory.subject(session.subject);
      try { await memory.client.purge(subject, note => cleanup === 'all' || note.saved_case_id === cleanup); }
      catch (error) {
        const what = cleanup === 'all' ? 'Tu cuenta y tus resultados siguen activos' : 'El resultado guardado sigue en tu historial';
        const message = error instanceof PurgeIncomplete && error.removed > 0
          ? `Borramos ${error.removed} de tus notas, pero ${error.remaining} siguen guardadas. ${what}; inténtalo de nuevo.`
          : `No pudimos borrar tus notas guardadas. ${what}; inténtalo de nuevo.`;
        return json({ error: { code: 'memory_cleanup_failed', message } }, { status: 503 });
      }
    }
    let body: string | undefined;
    if (request.method === 'POST') {
      const reader = request.body?.getReader();
      const chunks: Uint8Array[] = []; let size = 0;
      if (reader) {
        while (true) {
          const { value, done } = await reader.read(); if (done) break;
          size += value.length;
          if (size > (path === 'image-cases' && env.IMAGE_INPUT_ENABLED === 'true' ? 3_145_728 : 32_768)) { await reader.cancel(); return json({ error: { message: 'El mensaje es demasiado largo.' } }, { status: 413 }); }
          chunks.push(value);
        }
      }
      body = Buffer.concat(chunks).toString('utf8');
    }
    const target = new URL(`/api/v1/${path}`, env.API_BASE_URL);
    if (path === 'history' && url.searchParams.has('cursor')) target.searchParams.set('cursor', url.searchParams.get('cursor')!.slice(0, 300));
    const response = await fetch(target, { method: request.method, headers, body, signal: AbortSignal.timeout(path === 'image-cases' ? 20_000 : 12_000), redirect: 'error' });
    const output = await response.text();
    if (path === 'me' && request.method === 'DELETE' && response.ok && session) {
      await database().query('DELETE FROM bff.web_sessions WHERE subject=$1', [session.subject]);
      cookies.delete(authCookie, cookieOptions);
    }
    return new Response(output, { status: response.status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store', ...(response.headers.has('retry-after') ? { 'retry-after': response.headers.get('retry-after')! } : {}) } });
  } catch {
    return json({ error: { code: 'service_unavailable', message: 'No pudimos completar la consulta. Inténtalo de nuevo en un momento.' } }, { status: 503 });
  }
};
export const GET = proxy;
export const POST = proxy;
export const DELETE = proxy;
