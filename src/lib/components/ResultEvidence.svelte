<script lang="ts">
  import type { CaseResult } from '$lib/cases';
  import { explainSignals } from '$lib/evidence';
  let { result }: { result: CaseResult } = $props();
  const reasons = $derived(explainSignals(result));
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
