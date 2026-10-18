<script lang="ts" module>
  export interface OfficialChannel {
    id: string;
    brand: string | null;
    label: string;
    channel_type: 'web';
    purpose: 'reporte';
    public_value: string;
    source: string;
    verified_at: string;
    status: 'active';
  }
  export interface ReportAction {
    domain: string;
    brand: string | null;
    date: string;
    text: string;
    channels: OfficialChannel[];
  }
</script>

<script lang="ts">
  let { actions = [] }: { actions?: ReportAction[] } = $props();
  let copyStatus = $state('');

  async function copy(text: string) {
    try { await navigator.clipboard.writeText(text); copyStatus = 'Texto copiado.'; }
    catch { copyStatus = 'No pudimos copiarlo. Puedes seleccionar el texto y copiarlo.'; }
  }
</script>

{#if actions.length}
  <details class="report-actions">
    <summary>Reportar este sitio</summary>
    <p>Elige dónde avisar y revisa los datos antes de enviarlos. Tú completas el reporte en el canal oficial.</p>
    {#each actions as action (action.domain)}
      <section aria-label={`Opciones para reportar ${action.domain}`}>
        <h3>{action.domain}</h3>
        <pre>{action.text}</pre>
        <button class="quiet-button" type="button" onclick={() => copy(action.text)}>Copiar texto del reporte</button>
        <ul>
          {#each action.channels as channel (channel.id)}
            <li><a href={channel.public_value} target="_blank" rel="noopener noreferrer">{channel.label} ↗</a></li>
          {/each}
        </ul>
      </section>
    {/each}
    <p class="report-note">Al abrir Google se comparte sólo el dominio, sin el mensaje ni datos del enlace. El formulario del Estado puede pedir tus datos directamente.</p>
    {#if copyStatus}<p role="status">{copyStatus}</p>{/if}
  </details>
{/if}

<style>
  .report-actions { margin-top: 1.25rem; padding-top: 1rem; border-top: 1px solid #e2e8f0; color: #475569; }
  summary { cursor: pointer; font-weight: 600; color: #1d4ed8; }
  p { font-size: .95rem; line-height: 1.6; margin: .8rem 0; }
  section + section { border-top: 1px solid #e2e8f0; margin-top: 1rem; padding-top: .6rem; }
  h3 { font-size: 1rem; margin: .9rem 0 .5rem; overflow-wrap: anywhere; }
  pre { font: inherit; font-size: .9rem; white-space: pre-wrap; overflow-wrap: anywhere; padding: .85rem; border-radius: .6rem; background: #f8fafc; }
  ul { list-style: none; margin: .5rem 0; padding: 0; display: grid; gap: .6rem; }
  a { color: #1d4ed8; font-weight: 500; font-size: .95rem; }
  .report-note { color: #64748b; font-size: .85rem; }
</style>
