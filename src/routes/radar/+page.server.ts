import { createHmac } from 'node:crypto';
import { error } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { features } from '$lib/server/features';

interface Radar {
  new_domains: number;
  brands: { brand: string; domains: number }[];
  from: string;
  to: string;
}

function parseRadar(input: unknown): Radar | null {
  if (!input || typeof input !== 'object') return null;
  const value = input as Record<string, unknown>;
  if (!Number.isSafeInteger(value.new_domains) || Number(value.new_domains) < 0 || !Array.isArray(value.brands)
    || typeof value.from !== 'string' || !Number.isFinite(Date.parse(value.from))
    || typeof value.to !== 'string' || !Number.isFinite(Date.parse(value.to))) return null;
  const brands: Radar['brands'] = [];
  for (const entry of value.brands.slice(0, 20)) {
    if (!entry || typeof entry !== 'object' || typeof entry.brand !== 'string' || !entry.brand || entry.brand.length > 100
      || !Number.isSafeInteger(entry.domains) || entry.domains < 0) return null;
    brands.push({ brand: entry.brand, domains: entry.domains });
  }
  // Rebuild the public payload so unexpected private fields can never reach the browser.
  return { new_domains: Number(value.new_domains), brands, from: value.from, to: value.to };
}

export const load = async () => {
  if (!features().community_reports) error(404, 'Página no disponible.');
  if (!env.API_BASE_URL || !env.API_SERVICE_TOKEN) return { radar: null };
  try {
    const response = await fetch(new URL('/api/v1/radar', env.API_BASE_URL), {
      headers: {
        'x-service-token': env.API_SERVICE_TOKEN,
        'x-session-id': createHmac('sha256', env.API_SERVICE_TOKEN).update('public-radar-read').digest('hex')
      },
      signal: AbortSignal.timeout(4_000), redirect: 'error'
    });
    if (!response.ok) return { radar: null };
    return { radar: parseRadar(await response.json()) };
  } catch { return { radar: null }; }
};
