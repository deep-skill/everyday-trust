<script lang="ts">
  import type { PageProps } from './$types';
  let { data }: PageProps = $props();
</script>

<svelte:head><title>Radar de la comunidad · ¿Es estafa?</title></svelte:head>

<div class="guide-page">
  <header class="guide-header"><a class="brand" href="/"><img src="/mark.svg" width="36" height="36" alt="" /><span>¿Es estafa?</span></a><a class="secondary-button" href="/">Volver al verificador</a></header>
  <main class="radar-page">
    <div class="guide-intro"><div class="eyebrow">APORTES DE LA COMUNIDAD</div><h1>Más señales para cuidarnos.</h1><p>Un aporte aislado no convierte a un sitio en una amenaza. Contrastamos sesiones distintas con señales independientes antes de incluirlo en estos agregados.</p></div>
    {#if data.radar}
      <section class="radar-total" aria-labelledby="weekly-total"><span class="eyebrow">ÚLTIMOS SIETE DÍAS</span><strong>{data.radar.new_domains.toLocaleString('es-PE')}</strong><h2 id="weekly-total">{data.radar.new_domains === 1 ? 'dominio sospechoso nuevo' : 'dominios sospechosos nuevos'}</h2><p>Con tres aportes de sesiones distintas y al menos una señal independiente.</p></section>
      <section class="radar-brands" aria-labelledby="brands-title"><h2 id="brands-title">Marcas más imitadas</h2>
        {#if data.radar.brands.length}
          <ul>{#each data.radar.brands as brand}<li><span>{brand.brand}</span><strong>{brand.domains.toLocaleString('es-PE')} {brand.domains === 1 ? 'dominio' : 'dominios'}</strong></li>{/each}</ul>
        {:else}<p>Aún no hay suficientes aportes contrastados para mostrar marcas.</p>{/if}
      </section>
      <p class="radar-period">Actualizado el {new Date(data.radar.to).toLocaleString('es-PE', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'America/Lima' })}, hora de Perú.</p>
    {:else}<p class="radar-unavailable" role="status">El radar no está disponible en este momento. Puedes seguir revisando mensajes en el verificador.</p>{/if}
    <p class="radar-limit">Son señales de sospecha, no una denuncia ni una confirmación de fraude. No publicamos las direcciones de los sitios sin una revisión manual.</p>
  </main>
  <footer class="main-footer"><a href="/como-funciona">Cómo funciona</a><a href="/privacidad">Uso de datos y límites</a><span>Everyday Trust · Deep Skill</span></footer>
</div>

<style>
  .radar-page { max-width: 58rem; }
  .radar-total { padding: 1.8rem; border: 1px solid #e2e8f0; border-radius: 1rem; background: white; margin: 1.5rem 0; }
  .radar-total > strong { display: block; font-size: 3.5rem; line-height: 1.2; letter-spacing: -.04em; color: #1d4ed8; margin: .6rem 0 .2rem; }
  h2 { font-size: 1.2rem; color: #0f172a; margin: .3rem 0 .7rem; }
  p { color: #64748b; line-height: 1.7; }
  .radar-total p { font-size: .95rem; margin-bottom: 0; }
  .radar-brands { padding-top: 1rem; }
  ul { padding: 0; list-style: none; }
  li { display: flex; align-items: center; justify-content: space-between; gap: 1rem; border-bottom: 1px solid #e2e8f0; padding: 1rem 0; color: #334155; }
  li strong { font-size: .9rem; color: #475569; white-space: nowrap; }
  .radar-period, .radar-limit { font-size: .85rem; }
  .radar-limit { border-top: 1px solid #e2e8f0; padding-top: 1rem; margin-top: 2rem; }
  .radar-unavailable { padding: 1.5rem; border: 1px solid #e2e8f0; border-radius: 1rem; }
</style>
