<script lang="ts">
  export type Totals = { visits: number; consultations: number; reviews: number; rating: number | null };
  let { totals }: { totals: Totals | null } = $props();
</script>

{#if totals}
  <div class="traction" aria-label="Actividad de la plataforma" title="Visitas aproximadas por sesión de navegador. Las consultas y valoraciones excluyen los ejemplos de demostración. No representan personas únicas.">
    <span><strong>{totals.visits.toLocaleString('es-PE')}</strong> visitas</span>
    <span><strong>{totals.consultations.toLocaleString('es-PE')}</strong> consultas revisadas</span>
    {#if totals.reviews > 0}<span>★ <strong>{totals.rating?.toLocaleString('es-PE')}</strong>/5 · {totals.reviews.toLocaleString('es-PE')} {totals.reviews === 1 ? 'valoración' : 'valoraciones'}</span>{/if}
  </div>
{/if}

<style>
  .traction { display: flex; flex-wrap: wrap; gap: .4rem 1.3rem; color: #64748b; font-size: .875rem; line-height: 1.8; margin-top: 2.5rem; padding-top: 1rem; border-top: 1px solid #e2e8f0; }
  strong { color: #475569; font-weight: 600; }
</style>
