import assert from 'node:assert/strict';
import { test } from 'node:test';
import { POST } from '../.svelte-kit/output/server/entries/endpoints/api/analyze/_server.ts.js';

function mockNetwork(t, redirects = {}) {
	const calls = [];
	t.mock.method(globalThis, 'fetch', async (input, init) => {
		const url = String(input);
		calls.push({ url, method: init?.method ?? 'GET', redirect: init?.redirect });
		if (Object.hasOwn(redirects, url)) {
			const target = redirects[url];
			if (target instanceof Error) throw target;
			return new Response(null, target ? { status: 302, headers: { location: target } } : { status: 200 });
		}
		return new Response(null, { status: 404 });
	});
	return calls;
}

async function analyze(text) {
	const response = await POST({
		request: new Request('https://checker.example/api/analyze', {
			method: 'POST',
			headers: { 'content-type': 'application/json' },
			body: JSON.stringify({ text })
		})
	});
	assert.equal(response.status, 200);
	return response.json();
}

function signals(result) {
	return [...result.signals, ...result.urls.flatMap((url) => url.signals), ...result.phones.flatMap((phone) => phone.signals)];
}

for (const input of ['https://www.viabcp.com', 'www.viabcp.com', 'https://www.sunat.gob.pe']) {
	test(`recognizes an official URL: ${input}`, async (t) => {
		const calls = mockNetwork(t);
		const result = await analyze(input);
		assert.equal(result.verdict, 'likely_safe');
		assert.equal(result.urls.length, 1);
		assert.equal(result.score, 0);
		assert.deepEqual(calls, []);
	});
}

for (const input of [
	'https://www.viabcp.com@192.0.2.1/login',
	'www.viabcp.com@192.0.2.1/login',
	'https://www.viabcp.com@attacker.example/login',
	'https://attacker.example@www.viabcp.com/login'
]) {
	test(`does not trust userinfo as a hostname: ${input}`, async (t) => {
		mockNetwork(t);
		const result = await analyze(input);
		assert.notEqual(result.verdict, 'likely_safe');
		assert.equal(result.urls.length, 1);
		assert.equal(result.urls[0].hostname, new URL(input.startsWith('https:') ? input : `https://${input}`).hostname);
		assert.ok(signals(result).some((signal) => signal.id === 'url_userinfo'));
	});
}

for (const input of ['https://yаpe.com.pe', 'yаpe.com.pe', 'https://xn--ype-6cd.com.pe']) {
	test(`normalizes international hostnames before checking them: ${input}`, async (t) => {
		mockNetwork(t);
		const result = await analyze(input);
		assert.equal(result.urls.length, 1);
		assert.ok(result.urls[0].hostname.startsWith('xn--'));
		assert.ok(signals(result).some((signal) => signal.id === 'punycode'));
		assert.notEqual(result.verdict, 'likely_safe');
	});
}

test('preserves a query without a path and its embedded domain', async (t) => {
	mockNetwork(t);
	const input = 'https://www.viabcp.com?next=https://attacker.example';
	const result = await analyze(input);
	assert.equal(result.urls.length, 1);
	assert.equal(result.urls[0].input, input);
	assert.equal(result.urls[0].hostname, 'www.viabcp.com');
});

test('keeps IPv4 and IPv6 destinations', async (t) => {
	const calls = mockNetwork(t);
	const result = await analyze('https://192.0.2.1/login https://[2001:db8::1]/login');
	assert.equal(result.urls.length, 2);
	assert.ok(result.urls.every((url) => url.signals.some((signal) => signal.id === 'ip_address')));
	assert.notEqual(result.verdict, 'likely_safe');
	assert.deepEqual(calls, []);
});

test('keeps bare IP destinations alongside official links', async (t) => {
	const calls = mockNetwork(t);
	const result = await analyze('https://www.viabcp.com 192.0.2.1/login [2001:db8::1]/login');
	assert.equal(result.urls.length, 3);
	assert.notEqual(result.verdict, 'likely_safe');
	assert.deepEqual(calls, []);
});

test('distinguishes sentence punctuation from balanced URL parentheses', async (t) => {
	mockNetwork(t);
	const result = await analyze('Revisa (https://www.viabcp.com). También https://www.viabcp.com/info_(2026).');
	assert.deepEqual(result.urls.map((url) => url.input), ['https://www.viabcp.com', 'https://www.viabcp.com/info_(2026)']);
});

test('an invalid explicit URL cannot disappear behind an official URL', async (t) => {
	mockNetwork(t);
	const result = await analyze('https://www.viabcp.com https://%invalid');
	assert.equal(result.urls.length, 2);
	assert.ok(signals(result).some((signal) => signal.id === 'invalid_url'));
	assert.notEqual(result.verdict, 'likely_safe');
});

test('checks a malicious sixth URL and discloses incomplete network checks', async (t) => {
	const calls = mockNetwork(t);
	const official = Array.from({ length: 5 }, (_, i) => `https://www.viabcp.com/${i}`);
	const result = await analyze([...official, 'https://bcp-seguro.example.com'].join(' '));
	assert.equal(result.urls.length, 6);
	assert.equal(result.urls[5].imitatedBrand, 'BCP');
	assert.ok(signals(result).some((signal) => signal.id === 'incomplete_link_checks'));
	assert.notEqual(result.verdict, 'likely_safe');
	assert.deepEqual(calls, []);
});

test('bounds network checks while retaining every URL', async (t) => {
	const calls = mockNetwork(t);
	const urls = Array.from({ length: 8 }, (_, i) => `https://check-${i}.example.com`);
	const result = await analyze(urls.join(' '));
	assert.equal(result.urls.length, 8);
	assert.equal(calls.length, 5);
	assert.ok(calls.every((call) => call.url.startsWith('https://rdap.org/domain/')));
	assert.notEqual(result.verdict, 'likely_safe');
});

for (const text of [
	'Yapéame S/ 500: https://www.viabcp.com',
	'Soy tu hijo: https://www.viabcp.com',
	'+44 7700 900123 https://www.viabcp.com'
]) {
	test(`a medium signal prevents a green verdict: ${text}`, async (t) => {
		mockNetwork(t);
		const result = await analyze(text);
		assert.equal(result.verdict, 'suspicious');
		assert.ok(result.score >= 15);
	});
}

test('an insecure official URL does not receive a green verdict', async (t) => {
	mockNetwork(t);
	const result = await analyze('http://www.viabcp.com');
	assert.notEqual(result.verdict, 'likely_safe');
	assert.ok(signals(result).some((signal) => signal.id === 'no_https'));
});

for (const destination of [
	'https://victim.example.com/path?recipient=SYNTHETIC',
	'http://127.0.0.1:8080/internal',
	'https://www.viabcp.com'
]) {
	test(`does not visit the destination of a shortener: ${destination}`, async (t) => {
		const calls = mockNetwork(t, { 'https://bit.ly/review': destination });
		const result = await analyze('https://bit.ly/review');
		assert.equal(result.urls[0].finalUrl, new URL(destination).href);
		assert.deepEqual(calls.filter((call) => call.method === 'HEAD').map((call) => call.url), ['https://bit.ly/review']);
		assert.ok(calls.every((call) => call.url === 'https://bit.ly/review' || call.url.startsWith('https://rdap.org/domain/')));
	});
}

test('follows only allowlisted shorteners, including relative redirects', async (t) => {
	const calls = mockNetwork(t, {
		'https://bit.ly/first': '/second',
		'https://bit.ly/second': 'https://tinyurl.com/third',
		'https://tinyurl.com/third': 'https://www.viabcp.com'
	});
	const result = await analyze('https://bit.ly/first');
	assert.equal(result.urls[0].hostname, 'www.viabcp.com');
	assert.deepEqual(calls.map((call) => call.url), ['https://bit.ly/first', 'https://bit.ly/second', 'https://tinyurl.com/third']);
	assert.ok(calls.every((call) => call.redirect === 'manual'));
});

for (const destination of ['http://bit.ly/second', 'https://bit.ly:8443/second', 'https://user:pass@bit.ly/second', 'javascript:alert(1)']) {
	test(`does not request an unsafe redirect hop: ${destination}`, async (t) => {
		const calls = mockNetwork(t, { 'https://bit.ly/review': destination });
		const result = await analyze('https://bit.ly/review');
		assert.deepEqual(calls.map((call) => call.url), ['https://bit.ly/review']);
		assert.ok(signals(result).some((signal) => signal.id === 'unresolved_shortener'));
		assert.notEqual(result.verdict, 'likely_safe');
	});
}

test('stops redirect loops and reports unresolved destinations', async (t) => {
	const calls = mockNetwork(t, { 'https://bit.ly/review': 'https://bit.ly/review' });
	const result = await analyze('https://bit.ly/review');
	assert.equal(calls.length, 1);
	assert.ok(signals(result).some((signal) => signal.id === 'unresolved_shortener'));
});

test('limits redirect chains to five requests', async (t) => {
	const redirects = Object.fromEntries(Array.from({ length: 6 }, (_, i) => [`https://bit.ly/${i}`, `https://bit.ly/${i + 1}`]));
	const calls = mockNetwork(t, redirects);
	const result = await analyze('https://bit.ly/0');
	assert.equal(calls.length, 5);
	assert.ok(signals(result).some((signal) => signal.id === 'unresolved_shortener'));
});

for (const outcome of [null, new Error('Network unavailable')]) {
	test(`reports an unresolved shortener after ${outcome ? 'a network failure' : 'a response without a redirect'}`, async (t) => {
		mockNetwork(t, { 'https://bit.ly/review': outcome });
		const result = await analyze('https://bit.ly/review');
		assert.equal(result.verdict, 'suspicious');
		assert.ok(signals(result).some((signal) => signal.id === 'unresolved_shortener'));
	});
}

for (const warning of [
	'Nunca compartas tu clave ni contraseña. Si alguien dice que ganaste un premio, no respondas.',
	'No debes compartir tu clave ni tu token.',
	'Ningún banco te pedirá tu contraseña.',
	'Nunca te pediremos tu clave.'
]) {
	test(`does not mistake explicit safety advice for a request: ${warning}`, async (t) => {
		mockNetwork(t);
		const result = await analyze(`${warning} https://www.viabcp.com`);
		assert.equal(result.verdict, 'likely_safe');
		assert.deepEqual(result.signals, []);
	});
}

for (const text of [
	'Nunca compartas tu clave. Envíame tu clave ahora.',
	'No compartas tu clave, comparte tu contraseña conmigo.',
	'Nunca compartas tu clave con nadie, necesitamos tu clave para ayudarte.',
	'Ningún banco te pedirá tu clave, necesito tu contraseña.',
	'Nunca compartas tu clave. Ganaste un premio, ingresa tu clave aquí.'
]) {
	test(`a warning does not mask a later credential request: ${text}`, async (t) => {
		mockNetwork(t);
		const result = await analyze(`${text} https://www.viabcp.com`);
		assert.ok(result.signals.some((signal) => signal.id === 'asks_credentials'));
		assert.notEqual(result.verdict, 'likely_safe');
	});
}

test('a safety warning does not suppress a phishing domain signal', async (t) => {
	mockNetwork(t);
	const result = await analyze('Nunca compartas tu clave. https://bcp-zonasegura-pe.xyz/login');
	assert.ok(signals(result).some((signal) => signal.id === 'brand_lookalike'));
	assert.notEqual(result.verdict, 'likely_safe');
});
