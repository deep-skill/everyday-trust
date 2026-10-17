import { parse } from 'tldts';
import { BRANDS, SUSPICIOUS_TLDS, URL_SHORTENERS, type Brand } from './brands';
import type { PhoneFinding, Signal, UrlFinding } from '$lib/types';

const URL_PATTERN = /\b(?:https?:\/\/)?(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?(?:\/[^\s<>"')]*)?/gi;
const PHONE_PATTERN = /(?:\+|00)?\d[\d\s-]{7,16}\d/g;
const NETWORK_TIMEOUT_MS = 4000;
const MAX_REDIRECT_HOPS = 5;

const LEET: Record<string, string> = { '0': 'o', '1': 'l', '3': 'e', '4': 'a', '5': 's', '7': 't' };

export function extractUrls(text: string): string[] {
	const found = new Set<string>();
	for (const match of text.matchAll(URL_PATTERN)) {
		const raw = match[0].replace(/[.,;:!?]+$/, '');
		const hostname = toUrl(raw)?.hostname;
		if (!hostname) continue;
		const parsed = parse(hostname);
		if (parsed.isIcann && parsed.domain) found.add(raw);
	}
	return [...found];
}

function toUrl(raw: string): URL | null {
	try {
		return new URL(/^https?:\/\//i.test(raw) ? raw : `http://${raw}`);
	} catch {
		return null;
	}
}

function levenshtein(a: string, b: string): number {
	const row = Array.from({ length: b.length + 1 }, (_, i) => i);
	for (let i = 1; i <= a.length; i++) {
		let previous = row[0];
		row[0] = i;
		for (let j = 1; j <= b.length; j++) {
			const current = row[j];
			row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1));
			previous = current;
		}
	}
	return row[b.length];
}

function officialBrandOf(domain: string): Brand | null {
	return BRANDS.find((brand) => brand.domains.includes(domain)) ?? null;
}

function imitatedBrandOf(hostname: string, domainLabel: string): Brand | null {
	const deleet = (value: string) => value.replace(/[013457]/g, (c) => LEET[c]);
	const host = deleet(hostname.toLowerCase());
	const compact = host.replace(/[^a-z]/g, '');
	const tokens = host.split(/[^a-z]+/).filter(Boolean);
	const label = deleet(domainLabel.toLowerCase());

	for (const brand of BRANDS) {
		const keywordHit = brand.keywords.some((keyword) =>
			keyword.length >= 5
				? compact.includes(keyword)
				: tokens.some((token) => token.startsWith(keyword) || token.endsWith(keyword))
		);
		if (keywordHit) return brand;

		const typoHit = brand.domains.some((official) => {
			const officialLabel = parse(official).domainWithoutSuffix ?? '';
			if (officialLabel.length < 5 || officialLabel === label) return false;
			return levenshtein(officialLabel, label) <= (officialLabel.length >= 8 ? 2 : 1);
		});
		if (typoHit) return brand;
	}
	return null;
}

async function resolveRedirects(url: string): Promise<string> {
	let current = url;
	for (let hop = 0; hop < MAX_REDIRECT_HOPS; hop++) {
		try {
			const response = await fetch(current, {
				method: 'HEAD',
				redirect: 'manual',
				signal: AbortSignal.timeout(NETWORK_TIMEOUT_MS)
			});
			const location = response.headers.get('location');
			if (response.status < 300 || response.status >= 400 || !location) return current;
			current = new URL(location, current).toString();
		} catch {
			return current;
		}
	}
	return current;
}

async function domainAgeDays(domain: string): Promise<number | null> {
	try {
		const response = await fetch(`https://rdap.org/domain/${domain}`, {
			headers: { accept: 'application/rdap+json' },
			signal: AbortSignal.timeout(NETWORK_TIMEOUT_MS)
		});
		if (!response.ok) return null;
		const data = (await response.json()) as { events?: { eventAction: string; eventDate: string }[] };
		const registration = data.events?.find((event) => event.eventAction === 'registration');
		if (!registration) return null;
		return Math.floor((Date.now() - Date.parse(registration.eventDate)) / 86_400_000);
	} catch {
		return null;
	}
}

export async function analyzeUrl(input: string): Promise<UrlFinding> {
	const signals: Signal[] = [];
	const initial = toUrl(input);
	let finalUrl = initial?.toString() ?? input;

	// Only shorteners are followed: phishing links often carry a per-victim
	// token, and visiting them would confirm the victim clicked.
	if (initial && URL_SHORTENERS.has(initial.hostname.replace(/^www\./, ''))) {
		signals.push({
			id: 'shortener',
			severity: 'low',
			message: `El link usa un acortador (${initial.hostname}) que esconde el destino real.`
		});
		finalUrl = await resolveRedirects(finalUrl);
	}

	const url = toUrl(finalUrl);
	const hostname = url?.hostname ?? '';
	const parsed = parse(hostname);
	const registrableDomain = parsed.domain;
	const official = registrableDomain ? officialBrandOf(registrableDomain) : null;
	const isGovernment = hostname.endsWith('.gob.pe');
	const imitated =
		official || isGovernment ? null : imitatedBrandOf(hostname, parsed.domainWithoutSuffix ?? '');

	if (imitated) {
		signals.push({
			id: 'brand_lookalike',
			severity: 'high',
			message: `El link menciona a ${imitated.name}, pero no es su sitio oficial (${imitated.domains[0]}).`
		});
	}
	if (hostname.split('.').some((label) => label.startsWith('xn--'))) {
		signals.push({
			id: 'punycode',
			severity: 'high',
			message: 'El dominio usa letras de otros alfabetos para parecerse a un sitio conocido.'
		});
	}
	if (parsed.publicSuffix && SUSPICIOUS_TLDS.has(parsed.publicSuffix)) {
		signals.push({
			id: 'suspicious_tld',
			severity: 'low',
			message: `La terminación .${parsed.publicSuffix} es barata y muy usada en estafas.`
		});
	}
	if (url?.protocol === 'http:' && /^http:\/\//i.test(finalUrl === initial?.toString() ? input : finalUrl)) {
		signals.push({ id: 'no_https', severity: 'low', message: 'El sitio no usa conexión segura (https).' });
	}

	const ageDays = registrableDomain && !official && !isGovernment ? await domainAgeDays(registrableDomain) : null;
	if (ageDays !== null && ageDays < 30) {
		signals.push({
			id: 'new_domain',
			severity: 'high',
			message: `El dominio se creó hace ${ageDays} días. Los bancos y empresas no usan sitios recién creados.`
		});
	} else if (ageDays !== null && ageDays < 180) {
		signals.push({
			id: 'recent_domain',
			severity: 'medium',
			message: `El dominio tiene solo ${Math.round(ageDays / 30)} meses de antigüedad.`
		});
	}

	return {
		input,
		finalUrl,
		hostname,
		registrableDomain,
		officialBrand: official?.name ?? (isGovernment ? 'Estado peruano (gob.pe)' : null),
		imitatedBrand: imitated?.name ?? null,
		domainAgeDays: ageDays,
		signals
	};
}

export function extractPhones(text: string): PhoneFinding[] {
	const findings = new Map<string, PhoneFinding>();
	for (const match of text.matchAll(PHONE_PATTERN)) {
		const raw = match[0].trim();
		const digits = raw.replace(/\D/g, '').replace(/^00/, '');
		if (digits.length < 9) continue;

		const international = /^(\+|00)/.test(raw);
		const peruvian =
			(digits.length === 9 && digits.startsWith('9')) || (digits.startsWith('51') && digits.length >= 10);
		const country: PhoneFinding['country'] = peruvian ? 'PE' : international ? 'foreign' : 'unknown';
		const normalized = international || digits.startsWith('51') ? `+${digits}` : digits;
		const signals: Signal[] = [];
		if (country === 'foreign') {
			signals.push({
				id: 'foreign_number',
				severity: 'medium',
				message: `El número ${normalized} es extranjero. Las ofertas de trabajo, premios y préstamos por WhatsApp suelen venir de números de otros países.`
			});
		}
		findings.set(normalized, { input: raw, normalized, country, signals });
	}
	return [...findings.values()];
}

const TEXT_RULES: { id: string; severity: Signal['severity']; pattern: RegExp; message: string }[] = [
	{
		id: 'asks_credentials',
		severity: 'high',
		pattern: /\b(clave|contrase[ñn]a|token|c[oó]digo (de )?(verificaci[oó]n|seguridad|sms)|cvv|pin)\b/i,
		message: 'Te pide claves o códigos. Ningún banco ni empresa los pide por mensaje.'
	},
	{
		id: 'extortion',
		severity: 'high',
		pattern: /(si no (pagas|depositas|colaboras)|te estamos vigilando|sabemos d[oó]nde (vives|trabajas)|cupo|colaboraci[oó]n mensual)/i,
		message: 'El mensaje tiene lenguaje de extorsión.'
	},
	{
		id: 'family_impersonation',
		severity: 'medium',
		pattern: /(cambi[eé] de n[uú]mero|este es mi nuevo n[uú]mero|soy tu (hij[oa]|mam[aá]|pap[aá]|t[ií][oa]))/i,
		message: 'Alguien dice ser un familiar con número nuevo. Llama al número que ya tenías antes de enviar dinero.'
	},
	{
		id: 'asks_money',
		severity: 'medium',
		pattern: /\b(yap[eé]a(me|s)?|yapees|plin[eé]a(me|s)?|deposita(me)?|transfi[eé]re(me)?|env[ií]a(me)? (la plata|el dinero|s\/))/i,
		message: 'Te pide que envíes dinero.'
	},
	{
		id: 'urgency',
		severity: 'medium',
		pattern: /(urgente|inmediatamente|hoy mismo|en las pr[oó]ximas? \d+ horas|ser[aá] (bloquead|suspendid)|ha sido (bloquead|suspendid)|vence hoy)/i,
		message: 'Te apura para que actúes sin pensar.'
	},
	{
		id: 'prize_or_refund',
		severity: 'medium',
		pattern: /(ganaste|ganador|has sido seleccionad|premio|sorteo|reembolso|devoluci[oó]n de impuestos|bono del estado)/i,
		message: 'Promete un premio, bono o devolución que no pediste.'
	},
	{
		id: 'easy_job',
		severity: 'medium',
		pattern: /(trabajo desde casa|dar likes?|ganar? (dinero|hasta)|comisi[oó]n diaria|tareas simples|medio tiempo)/i,
		message: 'Ofrece trabajo fácil y bien pagado, un gancho típico para pedirte dinero después.'
	},
	{
		id: 'package_held',
		severity: 'medium',
		pattern: /(paquete|env[ií]o|encomienda).{0,40}(retenido|pendiente|no (pudo|ha podido) ser entregado|direcci[oó]n incompleta)/i,
		message: 'Avisa de un paquete retenido: el gancho más común para robar datos de tarjeta.'
	}
];

export function analyzeText(text: string): Signal[] {
	return TEXT_RULES.filter((rule) => rule.pattern.test(text)).map(({ id, severity, message }) => ({
		id,
		severity,
		message
	}));
}
