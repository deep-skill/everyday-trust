<script lang="ts">
  import { onMount } from 'svelte';
  import type { CaseResult } from '$lib/cases';
  import { explainSignals } from '$lib/evidence';
  let { result }: { result: CaseResult } = $props();
  let now = $state(Date.now());
  const googleCheckedAt = $derived(result.signals.find(signal => signal.id === 'google_safe_browsing')?.checked_at ?? result.analyzed_at);
  const googleHistorical = $derived(!Number.isFinite(Date.parse(googleCheckedAt)) || now - Date.parse(googleCheckedAt) > 30 * 60 * 1000);
  const reasons = $derived(explainSignals(result).map(reason => reason.id === 'google_safe_browsing' && googleHistorical ? {
    ...reason,
    title: 'Alerta de Google en una revisión anterior',
    detail: 'Google marcó el enlace como posiblemente peligroso en esa revisión. Han pasado más de 30 minutos; esta alerta histórica no confirma el estado actual del sitio.'
  } : reason));
  onMount(() => { const timer = setInterval(() => now = Date.now(), 30_000); return () => clearInterval(timer); });
</script>

<details class="evidence">
  <summary>¿Por qué este resultado?</summary>
  <div class="evidence-body">
    {#if reasons.length}
      <ol class="reason-list">
        {#each reasons as reason, i (reason.id)}
          <li><span class="reason-number" aria-hidden="true">{i + 1}</span><div><h2>{reason.title}</h2><p>{reason.detail}</p></div></li>
        {/each}
      </ol>
    {:else if result.risk_origin === 'interpretation'}
      <p>La lectura del mensaje sugiere un posible engaño. Es una interpretación del texto; no confirma quién lo envió ni que el sitio tenga una vulnerabilidad.</p>
    {:else}
      <p>No encontramos señales suficientes para decidir. Confirma quién escribe por otro canal.</p>
    {/if}
    {#if result.domains.length}
      <div class="checked-sites">
        <h2>Direcciones que revisamos</h2>
        <ul>{#each result.domains as domain, i (i)}<li>
          <span>{domain.domain ?? 'Dirección no reconocida'}</span>
          <p>{domain.official_brand ? `Coincide con un sitio oficial de ${domain.official_brand}. Esto no confirma quién envió el mensaje.` : 'No confirmamos que pertenezca a la empresa o persona que escribe.'}</p>
          {#if domain.destination_status === 'completed'}<p>El sitio respondió a la comprobación. Esto no garantiza que sea seguro.</p>
          {:else if domain.destination_status && domain.destination_status !== 'not_checked'}<p>No pudimos confirmar que el sitio responda. Puede faltar información.</p>{/if}
          {#if domain.checked_hosts && domain.checked_hosts.length > 1}<p class="destination-chain">Recorrido entre direcciones: {domain.checked_hosts.join(' → ')}</p>{/if}
        </li>{/each}</ul>
      </div>
    {/if}
    {#if result.coverage.safe_browsing && result.coverage.safe_browsing !== 'disabled'}
      <div class="checked-sites"><h2>Comprobación de Google</h2>
        <p>{result.coverage.safe_browsing === 'completed' ? googleHistorical ? 'Revisión histórica de Google, realizada hace más de 30 minutos. No confirma el estado actual del sitio.' : 'Consulta completada. Que no haya coincidencias no demuestra que el sitio sea seguro.' : result.coverage.safe_browsing === 'pending' ? 'Comprobación en curso.' : result.coverage.safe_browsing === 'not_applicable' ? 'No había enlaces para esta comprobación.' : 'No pudimos completar esta comprobación.'}</p>
        {#if result.coverage.safe_browsing === 'completed' && Number.isFinite(Date.parse(googleCheckedAt))}<p>Fecha de esta revisión: {new Date(googleCheckedAt).toLocaleString('es-PE', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'America/Lima' })}, hora de Perú.</p>{/if}
        <a href="https://developers.google.com/safe-browsing/v4/advisory" target="_blank" rel="noopener noreferrer">Advisory provided by Google</a>
      </div>
    {/if}
    {#if result.url_scans?.length}
      <div class="checked-sites"><h2>Navegación aislada</h2><p>Es una instantánea del dominio. Una página o ruta distinta puede comportarse de otra forma.</p>
        <ul>{#each result.url_scans as scan}<li><span>{scan.hostname}</span>
          {#if scan.final_hostname}<p>Terminó en: {scan.final_hostname}</p>{/if}
          {#if scan.page_title}<p>Título observado: {scan.page_title}</p>{/if}
          {#if scan.brands?.length}<p>Marcas detectadas por urlscan: {scan.brands.join(', ')}</p>{/if}
          <p>{scan.status === 'matched' ? 'El escaneo encontró señales de riesgo.' : scan.status === 'no_match' ? 'El escaneo no marcó una amenaza; esto no garantiza seguridad.' : 'El escaneo no se completó.'}</p>
          {#if scan.checked_at}<p>Comprobado el {new Date(scan.checked_at).toLocaleString('es-PE')}.</p>{/if}
          {#if scan.report_url && /^https:\/\/urlscan\.io\/result\/[a-f0-9-]{36}\/$/.test(scan.report_url)}<a href={scan.report_url} target="_blank" rel="noopener noreferrer">Ver informe de urlscan ↗</a>{/if}
        </li>{/each}</ul>
      </div>
    {/if}
    <div class="review-limits">
      <h2>Lo que esta revisión no confirma</h2>
      <p>No identificamos al dueño de un número ni garantizamos que el mensaje sea seguro.</p>
      {#if result.domains.length && result.coverage.threat_feed !== 'completed'}<p>Las alertas de sitios peligrosos pueden estar incompletas o desactualizadas.</p>{/if}
      {#if result.coverage.registration === 'partial'}<p>No pudimos comprobar cuándo se crearon algunas direcciones.</p>{/if}
      {#if ['unavailable', 'invalid_response', 'budget_exhausted'].includes(result.coverage.ai)}<p>Parte de la revisión automática no estuvo disponible. Conservamos las señales que sí pudimos comprobar.</p>{/if}
      <p>Revisado el {new Date(result.analyzed_at).toLocaleString('es-PE', { dateStyle: 'medium', timeStyle: 'short' })}.</p>
    </div>
  </div>
</details>
