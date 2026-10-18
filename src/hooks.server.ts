import { json, type Handle, type HandleServerError } from '@sveltejs/kit';

export const handleError: HandleServerError = () => ({ message: 'El servicio no está disponible en este momento. Inténtalo de nuevo más tarde.' });

export const handle: Handle = async ({ event, resolve }) => {
  if (!['GET', 'HEAD', 'OPTIONS'].includes(event.request.method)) {
    if (event.request.headers.get('origin') !== event.url.origin) return json({ error: { code: 'invalid_origin', message: 'Recarga la página e inténtalo de nuevo.' } }, { status: 403 });
    const length = Number(event.request.headers.get('content-length') ?? '0');
    if (length > 32_768) return json({ error: { code: 'body_too_large', message: 'El mensaje es demasiado largo.' } }, { status: 413 });
  }
  const response = await resolve(event);
  if (!event.url.pathname.startsWith('/_app/')) response.headers.set('cache-control', 'no-store');
  response.headers.set('x-content-type-options', 'nosniff');
  response.headers.set('referrer-policy', 'no-referrer');
  response.headers.set('permissions-policy', 'camera=(), microphone=(), geolocation=()');
  return response;
};
