import { redirect } from '@sveltejs/kit';
import { attemptCookie, authCookie, completeLogin, cookieOptions, digest, equal, exchange, unseal } from '$lib/server/auth';
import { database } from '$lib/server/database';

export const GET = async ({ cookies, url }) => {
  const state = url.searchParams.get('state') ?? '', expected = cookies.get(attemptCookie) ?? '';
  cookies.delete(attemptCookie, cookieOptions);
  let destination = '/?auth=failed';
  if (state && expected && equal(state, expected) && url.searchParams.has('code')) {
    try {
      const { rows } = await database().query('DELETE FROM bff.auth_attempts WHERE state_hash=$1 AND expires_at>now() RETURNING payload', [digest(state)]);
      if (!rows[0]) throw new Error('Expired login');
      const attempt = unseal<{ verifier: string; nonce: string; returnCase: string | null }>(rows[0].payload, `attempt:${digest(state)}`);
      const tokens = await exchange({ grant_type: 'authorization_code', code: url.searchParams.get('code')!, code_verifier: attempt.verifier, redirect_uri: `${url.origin}/auth/callback` });
      const session = await completeLogin(tokens, attempt.nonce);
      const previous = cookies.get(authCookie);
      if (previous) await database().query('DELETE FROM bff.web_sessions WHERE id_hash=$1', [digest(previous)]);
      cookies.set(authCookie, session, { ...cookieOptions, maxAge: 604_800 });
      destination = attempt.returnCase ? `/?case=${encodeURIComponent(attempt.returnCase)}` : '/';
    } catch { /* The redirect contains no provider diagnostic or token. */ }
  }
  redirect(303, destination);
};
