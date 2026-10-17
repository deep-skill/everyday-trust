<script lang="ts">
	import type { AnalysisResult, Severity, Verdict } from '$lib/types';

	const EXAMPLES = [
		{
			label: 'Falso BCP',
			text: 'BCP: Su cuenta ha sido bloqueada por seguridad. Ingrese hoy mismo a https://bcp-zonasegura-pe.xyz/login para validar su clave.'
		},
		{
			label: 'Paquete retenido',
			text: 'SERPOST: Su paquete está retenido por dirección incompleta. Actualice sus datos y pague S/ 4.90 aquí: bit.ly/serpost-pe'
		},
		{
			label: 'Familiar con número nuevo',
			text: 'Hola mamá, cambié de número, este es mi nuevo número. Necesito que me yapees S/ 500 urgente, te explico luego.'
		}
	];

	const VERDICT_STYLE: Record<Verdict, { label: string; classes: string; dot: string }> = {
		scam: { label: 'Es estafa', classes: 'border-red-300 bg-red-50 text-red-900', dot: 'bg-red-600' },
		suspicious: { label: 'Sospechoso', classes: 'border-amber-300 bg-amber-50 text-amber-900', dot: 'bg-amber-500' },
		likely_safe: { label: 'Parece legítimo', classes: 'border-green-300 bg-green-50 text-green-900', dot: 'bg-green-600' },
		unknown: { label: 'Sin señales claras', classes: 'border-slate-300 bg-white text-slate-900', dot: 'bg-slate-400' }
	};

	const SEVERITY_DOT: Record<Severity, string> = {
		high: 'bg-red-600',
		medium: 'bg-amber-500',
		low: 'bg-slate-400',
		info: 'bg-slate-300'
	};

	let text = $state('');
	let loading = $state(false);
	let errorMessage = $state('');
	let result = $state<AnalysisResult | null>(null);

	const reasons = $derived(
		result
			? [
					...result.signals,
					...result.urls.flatMap((url) => url.signals),
					...result.phones.flatMap((phone) => phone.signals)
				]
			: []
	);

	async function submit(event?: SubmitEvent) {
		event?.preventDefault();
		if (!text.trim() || loading) return;
		loading = true;
		errorMessage = '';
		result = null;
		try {
			const response = await fetch('/api/analyze', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ text })
			});
			if (!response.ok) {
				const body = (await response.json().catch(() => null)) as { message?: string } | null;
				throw new Error(body?.message ?? 'No pudimos revisar el mensaje. Intenta de nuevo.');
			}
			result = (await response.json()) as AnalysisResult;
		} catch (err) {
			errorMessage = err instanceof Error ? err.message : 'No pudimos revisar el mensaje.';
		} finally {
			loading = false;
		}
	}
</script>

<main class="mx-auto flex min-h-dvh max-w-xl flex-col gap-6 px-4 py-8">
	<header class="flex flex-col gap-2">
		<h1 class="text-3xl font-bold tracking-tight">¿Es estafa?</h1>
		<p class="text-slate-600">
			Pega el mensaje, link o número que te llegó por WhatsApp o SMS. Te decimos si es una estafa,
			por qué y qué hacer.
		</p>
	</header>

	<form class="flex flex-col gap-3" onsubmit={submit}>
		<label for="message" class="sr-only">Mensaje a revisar</label>
		<textarea
			id="message"
			bind:value={text}
			rows="6"
			maxlength="5000"
			placeholder="Ejemplo: BCP: su cuenta fue bloqueada, ingrese a..."
			class="w-full resize-y rounded-xl border border-slate-300 bg-white p-4 text-base shadow-sm focus:border-slate-900 focus:outline-none"
		></textarea>
		<button
			type="submit"
			disabled={loading || !text.trim()}
			class="rounded-xl bg-slate-900 px-4 py-3 text-base font-semibold text-white disabled:opacity-40"
		>
			{loading ? 'Revisando…' : 'Revisar'}
		</button>
		<div class="flex flex-wrap gap-2 text-sm">
			<span class="text-slate-500">Prueba con:</span>
			{#each EXAMPLES as example (example.label)}
				<button
					type="button"
					class="rounded-full border border-slate-300 bg-white px-3 py-1 hover:border-slate-900"
					onclick={() => {
						text = example.text;
						submit();
					}}
				>
					{example.label}
				</button>
			{/each}
		</div>
	</form>

	{#if errorMessage}
		<p class="rounded-xl border border-red-300 bg-red-50 p-4 text-red-900">{errorMessage}</p>
	{/if}

	{#if result}
		{@const style = VERDICT_STYLE[result.verdict]}
		<section class="flex flex-col gap-4 rounded-2xl border p-5 {style.classes}" aria-live="polite">
			<div class="flex items-center gap-3">
				<span class="size-4 rounded-full {style.dot}"></span>
				<h2 class="text-2xl font-bold">{style.label}</h2>
			</div>
			<p>{result.summary}</p>

			{#if reasons.length}
				<div class="flex flex-col gap-2">
					<h3 class="font-semibold">Por qué</h3>
					<ul class="flex flex-col gap-2">
						{#each reasons as reason, index (reason.id + index)}
							<li class="flex gap-2">
								<span class="mt-2 size-2 shrink-0 rounded-full {SEVERITY_DOT[reason.severity]}"></span>
								<span>{reason.message}</span>
							</li>
						{/each}
					</ul>
				</div>
			{/if}

			{#if result.urls.length}
				<div class="flex flex-col gap-1 text-sm">
					<h3 class="font-semibold">Links revisados</h3>
					{#each result.urls as url (url.input)}
						<p class="break-all">
							<span class="font-mono">{url.hostname}</span>
							{#if url.officialBrand}· sitio oficial de {url.officialBrand}{/if}
							{#if url.domainAgeDays !== null}· creado hace {url.domainAgeDays} días{/if}
							{#if url.finalUrl !== url.input && url.finalUrl !== `http://${url.input}`}
								<br /><span class="text-slate-600">Lleva a: {url.finalUrl}</span>
							{/if}
						</p>
					{/each}
				</div>
			{/if}

			<div class="flex flex-col gap-2">
				<h3 class="font-semibold">Qué hacer</h3>
				<ul class="list-disc pl-5">
					{#each result.advice as tip (tip)}
						<li>{tip}</li>
					{/each}
				</ul>
			</div>
		</section>
	{/if}

	<footer class="mt-auto text-center text-xs text-slate-500">
		Hecho por Deep Skill en Hack the Andes 2026.
	</footer>
</main>
