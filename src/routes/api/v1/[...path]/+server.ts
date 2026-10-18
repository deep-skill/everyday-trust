import { json, type RequestHandler } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { authCookie, cookieOptions, currentSession, visitor } from '$lib/server/auth';
import { database } from '$lib/server/database';
import { createHmac } from 'node:crypto';

const allowed: Record<string, RegExp> = {
  GET: /^(health|stats|me|history|history\/[a-f0-9-]{36}|cases\/[a-f0-9-]{36})$/,
  POST: /^(visits|cases|cases\/[a-f0-9-]{36}\/(save|messages|feedback|review))$/,
  DELETE: /^(me|history\/[a-f0-9-]{36}|cases\/[a-f0-9-]{36}\/review)$/
};
const proxy: RequestHandler = async ({ cookies, params, request, url, getClientAddress }) => {
  const path = params.path ?? '';
  if (!allowed[request.method]?.test(path)) return json({ error: { message: 'Ruta no disponible.' } }, { status: 404 });
  if (!env.API_BASE_URL || !env.API_SERVICE_TOKEN) return json({ error: { code: 'api_unavailable', message: 'El servicio está iniciando. Inténtalo en unos momentos.' } }, { status: 503 });
  try {
    const session = await currentSession(cookies);
    const headers = new Headers({ 'content-type': 'application/json', 'x-service-token': env.API_SERVICE_TOKEN, 'x-session-id': visitor(cookies) });
    headers.set('x-network-id', createHmac('sha256', env.API_SERVICE_TOKEN).update(path === 'health' ? 'health-check' : getClientAddress()).digest('hex'));
    if (session) headers.set('authorization', `Bearer ${session.access}`);
    let body: string | undefined;
    if (request.method === 'POST') {
      const reader = request.body?.getReader();
      const chunks: Uint8Array[] = []; let size = 0;
      if (reader) {
        while (true) {
          const { value, done } = await reader.read(); if (done) break;
          size += value.length;
          if (size > 32_768) { await reader.cancel(); return json({ error: { message: 'El mensaje es demasiado largo.' } }, { status: 413 }); }
          chunks.push(value);
        }
      }
      body = Buffer.concat(chunks).toString('utf8');
    }
    const target = new URL(`/api/v1/${path}`, env.API_BASE_URL);
    if (path === 'history' && url.searchParams.has('cursor')) target.searchParams.set('cursor', url.searchParams.get('cursor')!.slice(0, 300));
    const response = await fetch(target, { method: request.method, headers, body, signal: AbortSignal.timeout(12_000), redirect: 'error' });
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
