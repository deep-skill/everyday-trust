import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { env } from '$env/dynamic/private';
import { dev } from '$app/environment';
import type { Cookies } from '@sveltejs/kit';
import { database } from './database';
import { sealPayload, openPayload } from './sealed';

export const authCookie = dev ? 'trust-session' : '__Host-trust-session';
export const attemptCookie = dev ? 'trust-login' : '__Host-trust-login';
export const visitorCookie = dev ? 'trust-visitor' : '__Host-trust-visitor';
export const cookieOptions = { path: '/', secure: !dev, httpOnly: true, sameSite: 'lax' as const };
export const digest = (value: string) => createHash('sha256').update(value).digest('hex');
export const opaque = () => randomBytes(32).toString('base64url');
export const authConfigured = () => Boolean(env.COGNITO_ISSUER && env.COGNITO_CLIENT_ID && env.COGNITO_DOMAIN && env.WEB_DATABASE_URL && env.SESSION_ENCRYPTION_KEY);

function key() {
  const value = Buffer.from(env.SESSION_ENCRYPTION_KEY ?? '', 'base64');
  if (value.length !== 32) throw new Error('Session encryption is not configured');
  return value;
}
export function seal(value: unknown, binding: string) { return sealPayload(value, key(), binding); }
export function unseal<T>(value: string, binding: string): T { return openPayload<T>(value, key(), binding); }
export function equal(a: string, b: string) {
  const aa = Buffer.from(a), bb = Buffer.from(b);
  return aa.length === bb.length && timingSafeEqual(aa, bb);
}

let jwks: ReturnType<typeof createRemoteJWKSet> | undefined;
async function verify(token: string, kind: 'access' | 'id') {
  const issuer = env.COGNITO_ISSUER;
  if (!issuer || !/^https:\/\/cognito-idp\.[a-z0-9-]+\.amazonaws\.com\/[A-Za-z0-9_-]+$/.test(issuer)) throw new Error('Invalid issuer');
  jwks ??= createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`), { timeoutDuration: 3000 });
  const { payload } = await jwtVerify(token, jwks, { issuer, algorithms: ['RS256'], ...(kind === 'id' ? { audience: env.COGNITO_CLIENT_ID } : {}) });
  if (payload.token_use !== kind || !payload.sub || (kind === 'access' && payload.client_id !== env.COGNITO_CLIENT_ID)) throw new Error('Invalid token');
  return payload;
}

export function cognitoUrl(path: string) {
  const base = new URL(env.COGNITO_DOMAIN ?? 'https://not-configured.invalid');
  if (base.protocol !== 'https:' || base.username || base.password || base.pathname !== '/') throw new Error('Invalid identity endpoint');
  return new URL(path, base);
}
class InvalidGrant extends Error {}
export class SessionUnavailable extends Error {}
export async function exchange(parameters: Record<string, string>) {
  const form = new URLSearchParams({ client_id: env.COGNITO_CLIENT_ID ?? '', ...parameters });
  if (env.COGNITO_CLIENT_SECRET) form.set('client_secret', env.COGNITO_CLIENT_SECRET);
  const response = await fetch(cognitoUrl('/oauth2/token'), {
    method: 'POST', body: form, signal: AbortSignal.timeout(6000), redirect: 'error'
  });
  if (!response.ok) {
    const failure = await response.json().catch(() => null);
    if (response.status === 400 && failure?.error === 'invalid_grant') throw new InvalidGrant();
    throw new SessionUnavailable();
  }
  return await response.json() as { access_token: string; id_token: string; refresh_token?: string; expires_in: number };
}
interface Session {
  access: string;
  refresh: string;
  expiresAt: number;
  subject: string;
  authTime: number;
}
export async function completeLogin(tokens: Awaited<ReturnType<typeof exchange>>, nonce: string) {
  const [id, access] = await Promise.all([verify(tokens.id_token, 'id'), verify(tokens.access_token, 'access')]);
  if (id.nonce !== nonce || id.sub !== access.sub || !tokens.refresh_token || typeof id.auth_time !== 'number') throw new Error('Invalid login');
  const session: Session = { access: tokens.access_token, refresh: tokens.refresh_token, expiresAt: Number(access.exp) * 1000, subject: id.sub!, authTime: id.auth_time };
  const identifier = opaque();
  await database().query('INSERT INTO bff.web_sessions (id_hash,payload,subject,expires_at) VALUES ($1,$2,$3,now()+interval \'7 days\')', [digest(identifier), seal(session, `session:${digest(identifier)}`), session.subject]);
  return identifier;
}
export async function currentSession(cookies: Cookies): Promise<Session | null> {
  const identifier = cookies.get(authCookie);
  if (!identifier || !authConfigured()) return null;
  const client = await database().connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query('SELECT payload FROM bff.web_sessions WHERE id_hash=$1 AND expires_at>now() FOR UPDATE', [digest(identifier)]);
    if (!rows[0]) { await client.query('COMMIT'); cookies.delete(authCookie, cookieOptions); return null; }
    let session = unseal<Session>(rows[0].payload, `session:${digest(identifier)}`);
    if (session.expiresAt < Date.now() + 60_000) {
      const tokens = await exchange({ grant_type: 'refresh_token', refresh_token: session.refresh });
      const claims = await verify(tokens.access_token, 'access');
      if (claims.sub !== session.subject) throw new Error('Session subject changed');
      session = { ...session, access: tokens.access_token, refresh: tokens.refresh_token ?? session.refresh, expiresAt: Number(claims.exp) * 1000 };
      await client.query('UPDATE bff.web_sessions SET payload=$2 WHERE id_hash=$1', [digest(identifier), seal(session, `session:${digest(identifier)}`)]);
    }
    await client.query('COMMIT');
    return session;
  } catch (error) {
    await client.query('ROLLBACK');
    if (error instanceof InvalidGrant) {
      await client.query('DELETE FROM bff.web_sessions WHERE id_hash=$1', [digest(identifier)]);
      cookies.delete(authCookie, cookieOptions);
      return null;
    }
    throw new SessionUnavailable();
  } finally { client.release(); }
}
export function visitor(cookies: Cookies) {
  let value = cookies.get(visitorCookie);
  if (!value || !/^[A-Za-z0-9_-]{43}$/.test(value)) {
    value = opaque();
    cookies.set(visitorCookie, value, { ...cookieOptions, maxAge: 14_400 });
  }
  return digest(value);
}
