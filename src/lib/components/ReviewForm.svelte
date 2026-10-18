<script lang="ts">
  let { caseId, onrecord }: { caseId: string; onrecord: () => void } = $props();
  let rating = $state(0), comment = $state(''), busy = $state(false), recorded = $state(false), error = $state('');
  const labels = ['Muy mala', 'Mala', 'Regular', 'Buena', 'Muy buena'];
  async function send(event: SubmitEvent) {
    event.preventDefault();
    if (!rating || busy) return;
    busy = true; error = '';
    try {
      const response = await fetch(`/api/v1/cases/${caseId}/review`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ rating, comment }) });
      const body = await response.json();
      if (!response.ok) throw new Error(body?.error?.message ?? 'No pudimos guardar tu valoración.');
      recorded = true; onrecord();
    } catch (failure) { error = (failure as Error).message; }
    finally { busy = false; }
  }
  async function removeComment() {
    busy = true; error = '';
    try {
      const response = await fetch(`/api/v1/cases/${caseId}/review`, { method: 'DELETE' });
      if (!response.ok) throw new Error('No pudimos eliminar el comentario.');
      comment = '';
    } catch (failure) { error = (failure as Error).message; }
    finally { busy = false; }
  }
</script>

<section class="review" aria-labelledby="review-title">
  {#if recorded}
    <p role="status">Gracias por tu valoración. Nos ayuda a mejorar.</p>
    {#if comment}<button class="quiet-button" disabled={busy} onclick={removeComment}>Eliminar mi comentario</button>{/if}
  {:else}
    <form onsubmit={send}>
      <fieldset disabled={busy}>
        <legend id="review-title">¿Cómo fue tu experiencia?</legend>
        <div class="stars">
          {#each labels as label, index}<label class:chosen={rating >= index + 1}><input type="radio" name="rating" value={index + 1} bind:group={rating} aria-label={`${index + 1} de 5: ${label}`} /><span aria-hidden="true">★</span></label>{/each}
          {#if rating}<span class="rating-label">{labels[rating - 1]}</span>{/if}
        </div>
        {#if rating}
          <details><summary>Agregar un comentario (opcional)</summary><label for="review-comment">¿Qué te ayudó o qué mejorarías?</label><textarea id="review-comment" bind:value={comment} maxlength="500" rows="3" placeholder="Cuéntanos sobre la herramienta, sin pegar mensajes ni datos personales."></textarea><p class="review-note">El comentario sólo lo recibe el equipo. No se publica ni se envía a la IA.</p></details>
          <button class="secondary-button" disabled={busy}>{busy ? 'Enviando…' : 'Enviar valoración'}</button>
        {/if}
      </fieldset>
    </form>
  {/if}
  {#if error}<p role="alert">{error}</p>{/if}
</section>

<style>
  .review { border-top: 1px solid #e2e8f0; margin-top: 1.5rem; padding-top: 1.25rem; color: #475569; }
  fieldset { border: 0; padding: 0; margin: 0; }
  legend { font-weight: 600; font-size: 1rem; margin-bottom: .4rem; }
  .stars { display: flex; align-items: center; gap: .2rem; margin-bottom: .7rem; }
  .stars label { position: relative; cursor: pointer; color: #94a3b8; font-size: 2rem; line-height: 1.5; padding: 0 .25rem; }
  .stars label.chosen { color: #92400e; }
  .stars input { position: absolute; opacity: 0; width: 100%; height: 100%; inset: 0; margin: 0; cursor: pointer; }
  .stars label:focus-within { outline: 2px solid #1d4ed8; outline-offset: 2px; border-radius: 4px; }
  .rating-label { font-size: .875rem; margin-left: .5rem; }
  details { margin-bottom: 1rem; }
  summary { cursor: pointer; font-size: .95rem; }
  details label { display: block; margin: .8rem 0 .4rem; }
  textarea { width: 100%; font: inherit; padding: .75rem; border: 1px solid #cbd5e1; border-radius: 10px; background: white; resize: vertical; }
  .review-note { font-size: .875rem; line-height: 1.6; margin: .5rem 0; }
</style>
