import { error, redirect } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { authConfigured, attemptCookie, cognitoUrl, cookieOptions, digest, opaque, seal } from '$lib/server/auth';
import { database } from '$lib/server/database';

export const GET = async ({ cookies, url }) => {
  if (!authConfigured()) error(503, 'El registro todavía no está configurado en este entorno. Puedes consultar sin cuenta.');
  const state = opaque(), verifier = opaque(), nonce = opaque();
  const candidate = url.searchParams.get('return_case');
  const returnCase = candidate && /^[a-f0-9-]{36}$/.test(candidate) ? candidate : null;
  await database().query('INSERT INTO bff.auth_attempts (state_hash,payload,expires_at) VALUES ($1,$2,now()+interval \'10 minutes\')', [digest(state), seal({ verifier, nonce, returnCase }, `attempt:${digest(state)}`)]);
  cookies.set(attemptCookie, state, { ...cookieOptions, maxAge: 600 });
  const location = cognitoUrl('/oauth2/authorize');
  location.search = new URLSearchParams({ response_type: 'code', lang: 'es', client_id: env.COGNITO_CLIENT_ID!, redirect_uri: `${url.origin}/auth/callback`, scope: 'openid aws.cognito.signin.user.admin', state, nonce, code_challenge: Buffer.from(digest(verifier), 'hex').toString('base64url'), code_challenge_method: 'S256' }).toString();
  if (url.searchParams.get('reauth') === '1') { location.searchParams.set('prompt', 'login'); location.searchParams.set('max_age', '0'); }
  redirect(303, location.toString());
};
