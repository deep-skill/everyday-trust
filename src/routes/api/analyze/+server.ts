import { error, json } from '@sveltejs/kit';
import { analyze } from '$lib/server/analyze';
import type { RequestHandler } from './$types';

const MAX_TEXT_LENGTH = 5000;

export const POST: RequestHandler = async ({ request }) => {
	const body = (await request.json().catch(() => null)) as { text?: unknown } | null;
	const text = typeof body?.text === 'string' ? body.text.trim() : '';
	if (!text) error(400, 'Pega el mensaje, link o número que quieres revisar.');
	if (text.length > MAX_TEXT_LENGTH) error(413, `El texto supera los ${MAX_TEXT_LENGTH} caracteres.`);

	return json(await analyze(text));
};
