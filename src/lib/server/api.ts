import { env } from '$env/dynamic/private';
import { createHmac } from 'node:crypto';
import type { Cookies } from '@sveltejs/kit';
import { visitor } from './auth';

// Headers for calls from the BFF to the Phoenix API on behalf of the current browser.
export function apiHeaders(cookies: Cookies, access: string | null, network: string) {
  const headers = new Headers({ 'content-type': 'application/json', 'x-service-token': env.API_SERVICE_TOKEN ?? '', 'x-session-id': visitor(cookies) });
  headers.set('x-network-id', createHmac('sha256', env.API_SERVICE_TOKEN ?? '').update(network).digest('hex'));
  if (access) headers.set('authorization', `Bearer ${access}`);
  return headers;
}

// Reads an owned resource through Phoenix so ownership stays enforced by the API.
export async function apiRead(path: string, cookies: Cookies, access: string, network: string): Promise<unknown> {
  if (!env.API_BASE_URL || !env.API_SERVICE_TOKEN) return null;
  const response = await fetch(new URL(`/api/v1/${path}`, env.API_BASE_URL), { headers: apiHeaders(cookies, access, network), signal: AbortSignal.timeout(5000), redirect: 'error' });
  return response.ok ? await response.json().catch(() => null) : null;
}
