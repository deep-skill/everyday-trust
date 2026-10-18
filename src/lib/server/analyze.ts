import { analyzeText, analyzeUrl, extractPhones, extractUrls } from './signals.ts';
import type { AnalysisResult, Severity, Signal, Verdict } from '$lib/types';

const MAX_NETWORK_URLS = 5;
const WEIGHTS: Record<Severity, number> = { high: 45, medium: 15, low: 5, info: 0 };

const ADVICE: Record<Verdict, string[]> = {
	scam: [
		'No hagas clic en el link ni respondas el mensaje.',
		'No envíes dinero, claves ni códigos que te lleguen por SMS.',
		'Si ya ingresaste tus datos, llama de inmediato a tu banco al número que está detrás de tu tarjeta.',
		'Bloquea y reporta el número en WhatsApp.'
	],
	suspicious: [
		'No actúes con apuro: verifica por un canal oficial que tú busques, no el del mensaje.',
		'No compartas claves ni códigos con nadie.',
		'Si dice ser un familiar, llámalo al número que ya tenías.'
	],
	likely_safe: ['Los links apuntan a sitios oficiales. Aun así, nunca compartas claves ni códigos por mensaje.'],
	unknown: [
		'No encontramos señales claras. Desconfía si te piden dinero, datos o que actúes rápido.',
		'Ante la duda, consulta directamente con la empresa por su canal oficial.'
	]
};

const SUMMARY: Record<Verdict, string> = {
	scam: 'Tiene señales claras de estafa.',
	suspicious: 'Tiene señales sospechosas. Verifica antes de hacer cualquier cosa.',
	likely_safe: 'No encontramos señales de estafa.',
	unknown: 'No encontramos señales suficientes para decidir.'
};

export async function analyze(text: string): Promise<AnalysisResult> {
	const extractedUrls = extractUrls(text);
	const urls = await Promise.all(
		extractedUrls.map((url, index) => analyzeUrl(url, index < MAX_NETWORK_URLS))
	);
	const phones = extractPhones(text);
	const textSignals = analyzeText(text);
	if (extractedUrls.length > MAX_NETWORK_URLS) {
		textSignals.push({
			id: 'incomplete_link_checks',
			severity: 'medium',
			message: 'No pudimos completar la verificación de todos los links. Confirma cada destino por un canal oficial.'
		});
	}

	const allSignals: Signal[] = [
		...textSignals,
		...urls.flatMap((url) => url.signals),
		...phones.flatMap((phone) => phone.signals)
	];
	const score = Math.min(
		100,
		allSignals.reduce((total, signal) => total + WEIGHTS[signal.severity], 0)
	);

	const onlyOfficialLinks = urls.length > 0 && urls.every((url) => url.officialBrand);
	const verdict: Verdict = score >= 60
		? 'scam'
		: score >= 15
			? 'suspicious'
			: onlyOfficialLinks && score === 0 ? 'likely_safe' : 'unknown';

	return {
		verdict,
		score,
		summary: SUMMARY[verdict],
		urls,
		phones,
		signals: textSignals,
		advice: ADVICE[verdict]
	};
}
