<script lang="ts">
  let { caseId, domain }: { caseId: string; domain: string } = $props();
  let consent = $state(false), busy = $state(false), recorded = $state(false), error = $state('');

  async function share(event: SubmitEvent) {
    event.preventDefault();
    if (!consent || busy || recorded) return;
    busy = true; error = '';
    try {
      const response = await fetch(`/api/v1/cases/${caseId}/community`, {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ consent: true })
      });
      const value = await response.json();
      if (!response.ok || value?.recorded !== true) throw new Error(value?.error?.message ?? 'No pudimos compartir el dominio. Puedes intentarlo de nuevo.');
      recorded = true;
    } catch (failure) { error = (failure as Error).message; }
    finally { busy = false; }
  }
</script>

<section class="community-consent" aria-label="Ayuda a la comunidad">
  {#if recorded}
    <p role="status">Gracias. Tu aporte se contrastará con otras señales antes de generar una alerta.</p>
  {:else}
    <form onsubmit={share}>
      <label><input type="checkbox" bind:checked={consent} disabled={busy} /><span>Compartir el dominio sospechoso para alertar a otros</span></label>
      <p>Dominio: <strong>{domain}</strong></p>
      <p>Compartimos sólo este dominio, la posible marca, el resultado y la fecha. Un identificador de sesión permite contar aportes distintos. No compartimos tu mensaje, números, rutas ni tu IP.</p>
      {#if consent}<button type="submit" class="secondary-button" disabled={busy}>{busy ? 'Compartiendo…' : 'Compartir este dominio'}</button>{/if}
    </form>
  {/if}
  {#if error}<p class="community-error" role="alert">{error}</p>{/if}
</section>

<style>
  .community-consent { margin-top: 1.5rem; padding-top: 1.25rem; border-top: 1px solid #e2e8f0; color: #475569; }
  label { display: flex; align-items: flex-start; gap: .65rem; cursor: pointer; font-weight: 600; font-size: .95rem; line-height: 1.5; }
  input { width: 1.1rem; height: 1.1rem; margin-top: .15rem; flex-shrink: 0; accent-color: #1d4ed8; }
  p { font-size: .85rem; line-height: 1.6; margin: .6rem 0; overflow-wrap: anywhere; }
  strong { color: #334155; font-weight: 600; }
  button { margin-top: .3rem; }
  .community-error { color: #b91c1c; }
</style>
