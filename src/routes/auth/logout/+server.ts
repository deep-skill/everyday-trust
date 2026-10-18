import { json, redirect } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { authCookie, cognitoUrl, cookieOptions, currentSession, digest } from '$lib/server/auth';
import { database } from '$lib/server/database';

export const POST = async ({ cookies, url, request }) => {
  const id = cookies.get(authCookie);
  if (id) {
    const session = await currentSession(cookies).catch(() => null);
    await database().query('DELETE FROM bff.web_sessions WHERE id_hash=$1', [digest(id)]);
    if (session) {
      const body = new URLSearchParams({ client_id: env.COGNITO_CLIENT_ID!, token: session.refresh });
      if (env.COGNITO_CLIENT_SECRET) body.set('client_secret', env.COGNITO_CLIENT_SECRET);
      await fetch(cognitoUrl('/oauth2/revoke'), { method: 'POST', body, signal: AbortSignal.timeout(3000), redirect: 'error' }).catch(() => undefined);
    }
  }
  cookies.delete(authCookie, cookieOptions);
  const destination = env.COGNITO_DOMAIN ? cognitoUrl('/logout') : new URL('/', url);
  if (env.COGNITO_DOMAIN) destination.search = new URLSearchParams({ client_id: env.COGNITO_CLIENT_ID!, logout_uri: url.origin }).toString();
  if (request.headers.get('accept')?.includes('application/json')) return json({ redirect_to: destination.toString() });
  redirect(303, destination.toString());
};
