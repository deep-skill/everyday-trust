<script lang="ts">
  import { onMount } from 'svelte';
  import { verdictLabels, type CaseNote } from '$lib/cases';
  let { caseId }: { caseId: string } = $props();
  let notes = $state<CaseNote[]>([]);

  onMount(async () => {
    try {
      const response = await fetch('/api/memory/recall', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ case_id: caseId }) });
      if (response.ok) notes = (await response.json()).notes ?? [];
    } catch { /* Notes are optional context and never block the result. */ }
  });
</script>

{#if notes.length}
  <section class="related-notes" aria-labelledby="related-notes-title">
    <span class="mini-label">DE TUS CASOS GUARDADOS</span>
    <h2 id="related-notes-title">Antes guardaste algo parecido</h2>
    <ul>{#each notes as item (item.id)}<li><span class="verdict">{verdictLabels[item.verdict]} · {new Date(item.analyzed_at).toLocaleDateString('es-PE')}</span><p class="summary">{item.summary}</p><p class="note">Tu nota: «{item.note}»</p></li>{/each}</ul>
    <p class="disclaimer">Son notas tuyas, no una comprobación. El resultado y los pasos de arriba no cambian por ellas.</p>
  </section>
{/if}

<style>
  .related-notes { margin-top: 1.5rem; padding: 1rem 1.25rem; border: 1px solid #e2e8f0; border-radius: 12px; background: #f8fafc; }
  h2 { font-size: 1rem; margin: .35rem 0 .5rem; }
  ul { list-style: none; padding: 0; margin: 0; display: grid; gap: .75rem; }
  li { border-top: 1px solid #e2e8f0; padding-top: .6rem; }
  .verdict { font-size: .75rem; font-weight: 600; color: #475569; }
  p { margin: .3rem 0; font-size: .9rem; line-height: 1.6; overflow-wrap: anywhere; }
  .note { color: #1e293b; }
  .disclaimer { font-size: .8rem; color: #64748b; margin-top: .75rem; }
</style>
