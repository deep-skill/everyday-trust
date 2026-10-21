<script lang="ts">
  import type { CaseNote } from '$lib/cases';
  let { savedCaseId, note, onchange }: { savedCaseId: string; note: CaseNote | null; onchange: (note: CaseNote | null) => void } = $props();
  let editing = $state(false), draft = $state(''), busy = $state(false), error = $state('');

  function edit() { draft = note?.note ?? ''; editing = true; error = ''; }
  async function save(event: SubmitEvent) {
    event.preventDefault();
    if (busy || !draft.trim()) return;
    busy = true; error = '';
    try {
      const response = await fetch('/api/memory/notes', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ saved_case_id: savedCaseId, note: draft }) });
      const value = await response.json().catch(() => null);
      // Only a note returned by the server counts as saved.
      if (!response.ok || !value?.note?.id) throw new Error(value?.error?.message ?? 'Tu nota no se guardó; inténtalo de nuevo.');
      onchange(value.note); editing = false;
    } catch (failure) { error = (failure as Error).message; }
    finally { busy = false; }
  }
  async function forget() {
    if (!note || busy) return;
    busy = true; error = '';
    try {
      const response = await fetch(`/api/memory/notes/${encodeURIComponent(note.id)}`, { method: 'DELETE' });
      const value = await response.json().catch(() => null);
      if (!response.ok || value?.deleted !== true) throw new Error(value?.error?.message ?? 'No pudimos olvidar la nota; inténtalo de nuevo.');
      onchange(null);
    } catch (failure) { error = (failure as Error).message; }
    finally { busy = false; }
  }
</script>

<div class="case-note">
  {#if editing}
    <form onsubmit={save}>
      <label for={`note-${savedCaseId}`}>Tu nota sobre este caso</label>
      <textarea id={`note-${savedCaseId}`} bind:value={draft} maxlength="280" rows="2" placeholder="Ej.: Me escribieron como si fueran mi banco; llamé al número de mi tarjeta y no era real." disabled={busy}></textarea>
      <p>{draft.length} / 280 · Ocultamos números, correos y enlaces antes de guardar. Sólo tú la verás.</p>
      <div class="actions"><button type="button" class="quiet-button" disabled={busy} onclick={() => editing = false}>Cancelar</button><button class="secondary-button" disabled={busy || !draft.trim()}>{busy ? 'Guardando…' : note ? 'Guardar corrección' : 'Guardar nota'}</button></div>
    </form>
  {:else if note}
    <span class="mini-label">TU NOTA</span>
    <p class="note-text">{note.note}</p>
    <div class="actions"><button class="quiet-button" disabled={busy} onclick={edit}>Corregir</button><button class="delete-button" disabled={busy} onclick={forget}>{busy ? 'Olvidando…' : 'Olvidar nota'}</button></div>
  {:else}
    <button class="text-button" onclick={edit}>＋ Añadir una nota para recordar qué hiciste</button>
  {/if}
  {#if error}<p class="note-error" role="alert">{error}</p>{/if}
</div>

<style>
  .case-note { margin-top: .75rem; padding-top: .75rem; border-top: 1px dashed #e2e8f0; }
  form { display: grid; gap: .5rem; }
  label { font-weight: 600; font-size: .95rem; }
  textarea { width: 100%; border: 1px solid #cbd5e1; border-radius: 10px; padding: .7rem; font: inherit; font-size: 1rem; resize: vertical; }
  p { font-size: .85rem; line-height: 1.6; color: #475569; margin: .25rem 0; overflow-wrap: anywhere; }
  .note-text { font-size: .95rem; color: #1e293b; }
  .actions { display: flex; justify-content: flex-end; gap: .5rem; flex-wrap: wrap; }
  .note-error { color: #b91c1c; }
</style>
