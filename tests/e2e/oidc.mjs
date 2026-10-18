import { writeFileSync } from 'node:fs';
import { randomUUID, createHash } from 'node:crypto';
import { generateKeyPair, exportJWK, SignJWT } from 'jose';
if (process.env.E2E_IDENTITY_MOCK !== 'true') throw new Error('This helper requires an explicit local test environment');
const issuer = 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_qa';
const { privateKey, publicKey } = await generateKeyPair('RS256');
const jwk = { ...await exportJWK(publicKey), kid: 'qa-key', alg: 'RS256', use: 'sig' };
writeFileSync(process.env.E2E_JWKS_FILE ?? '/private/tmp/everyday-trust-jwks.json', JSON.stringify({ keys: [jwk] }));
const refreshTokens = new Map();
const original = globalThis.fetch;
async function sign(claims, subject, lifetime) {
  return new SignJWT(claims).setProtectedHeader({ alg: 'RS256', kid: 'qa-key' }).setIssuer(issuer)
    .setSubject(subject).setIssuedAt().setExpirationTime(lifetime).sign(privateKey);
}
globalThis.fetch = async (input, init) => {
  const url = String(input instanceof Request ? input.url : input);
  if (url === issuer + '/.well-known/jwks.json') return Response.json({ keys: [jwk] });
  if (url === 'https://everyday-trust-qa.auth.us-east-1.amazoncognito.com/oauth2/token') {
    const params = new URLSearchParams(init.body);
    const isRefresh = params.get('grant_type') === 'refresh_token';
    let subject, nonce = '', authTime;
    if (isRefresh) {
      const previous = refreshTokens.get(params.get('refresh_token'));
      if (!previous) return Response.json({ error: 'invalid_grant' }, { status: 400 });
      refreshTokens.delete(params.get('refresh_token'));
      ({ subject, authTime } = previous);
    } else {
      const parts = params.get('code').split('~');
      [nonce, subject = 'qa-alice'] = parts;
      if (createHash('sha256').update(params.get('code_verifier') ?? '').digest('base64url') !== parts[2]) return Response.json({ error: 'invalid_grant' }, { status: 400 });
      authTime = Math.floor(Date.now() / 1000);
    }
    const access = await sign({ token_use: 'access', client_id: 'qa-client', auth_time: authTime }, subject, '45s');
    const id = await sign({ token_use: 'id', aud: 'qa-client', nonce, auth_time: authTime }, subject, '1h');
    const refresh = 'synthetic-refresh-' + randomUUID();
    refreshTokens.set(refresh, { subject, authTime });
    return Response.json({ access_token: access, id_token: id, refresh_token: refresh, expires_in: 45 });
  }
  if (url.includes('everyday-trust-qa.auth.us-east-1.amazoncognito.com/oauth2/revoke')) return new Response(null, { status: 200 });
  return original(input, init);
};
