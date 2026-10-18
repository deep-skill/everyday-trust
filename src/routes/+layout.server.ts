import { error } from '@sveltejs/kit';
import { features } from '$lib/server/features';
import { authConfigured, currentSession } from '$lib/server/auth';

export const load = async ({ cookies }) => {
  try { return { authenticated: Boolean(await currentSession(cookies)), authConfigured: authConfigured(), features: features() }; }
  catch { error(503, 'No pudimos comprobar tu sesión. Inténtalo de nuevo en un momento.'); }
};
