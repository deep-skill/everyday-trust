import { json } from '@sveltejs/kit';

export const POST = () => json({ error: { code: 'endpoint_retired', message: 'Usa /api/v1/cases.' } }, { status: 410 });
