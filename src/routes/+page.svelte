<script lang="ts">
  import { onMount } from 'svelte';
  import type { PageProps } from './$types';
  import { verdictLabels, type CaseResult, type HistoryItem } from '$lib/cases';
  import ResultEvidence from '$lib/components/ResultEvidence.svelte';
  import Traction, { type Totals } from '$lib/components/Traction.svelte';
  import ReviewForm from '$lib/components/ReviewForm.svelte';
  import { findExample } from '$lib/examples';
  let { data }: PageProps = $props();
  let text = $state(''), submitted = $state(''), loading = $state(false), error = $state('');
  let result = $state<CaseResult | null>(null), activeCase = $state<string | null>(null);
  let history = $state<HistoryItem[]>([]), historyOpen = $state(false), cursor = $state<string | null>(null);
  let saved = $state(false), followup = $state(''), followupText = $state(''), followupBusy = $state(false);
  let turns = $state(5), interactions = $state<string[]>([]);
  let totals = $state<Totals | null>(null);
  let confirmDelete = $state(false), deleting = $state(false);
  let generation = 0;
  let dialog: HTMLDialogElement;
  let input = $state<HTMLTextAreaElement>();
  const loginUrl = $derived(`/auth/login${activeCase ? `?return_case=${encodeURIComponent(activeCase)}` : ''}`);
  async function api(path: string, method = 'GET', body?: unknown) {
    const response = await fetch(`/api/v1/${path}`, { method, headers: { 'content-type': 'application/json' }, ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
    const value = await response.json().catch(() => null);
    if (!response.ok || !value) throw Object.assign(new Error(value?.error?.message ?? 'No pudimos completar la solicitud.'), { code: value?.error?.code });
    return value;
  }
  async function refreshTotals() {
    try { totals = (await api('stats')).totals; } catch { /* Metrics never interrupt a consultation. */ }
  }
  async function poll(id: string, version = generation) {
    for (let attempt = 0; attempt < 22; attempt++) {
      if (version !== generation || activeCase !== id || result?.analysis_status !== 'in_progress') return;
      await new Promise(resolve => setTimeout(resolve, 600));
      try {
        const next: CaseResult = await api(`cases/${id}`);
        if (version !== generation || activeCase !== id) return;
        if (next.revision >= (result?.revision ?? 0)) result = next;
        if (next.analysis_status === 'completed') void refreshTotals();
      } catch { return; }
    }
  }
  function reset() {
    generation++;

    text = ''; submitted = ''; result = null; activeCase = null; saved = false; error = '';
    followup = ''; followupText = ''; turns = 5; interactions = []; historyOpen = false;
    window.history.replaceState({}, '', '/');
    input?.focus();
  }
  async function submit(event?: SubmitEvent) {
    event?.preventDefault();
    if (loading || !text.trim()) return;
    generation++;
    error = ''; loading = true; saved = false; followup = ''; followupText = ''; interactions = []; turns = 5;
    try {
      const value = await api('cases', 'POST', { text });
      submitted = text; text = ''; result = value; activeCase = value.id; historyOpen = false;
      window.history.replaceState({}, '', `/?case=${value.id}`);
      void poll(value.id);
      if (value.analysis_status === 'completed') void refreshTotals();
    } catch (e) { error = (e as Error).message; }
    finally { loading = false; }
  }
  async function save() {
    if (!data.authenticated) { dialog.showModal(); return; }
    if (!activeCase || saved || result?.analysis_status === 'in_progress') return;
    try { await api(`cases/${activeCase}/save`, 'POST', {}); saved = true; }
    catch (e) { error = (e as Error).message; }
  }
  async function openHistory(more = false) {
    if (!data.authenticated) { dialog.showModal(); return; }
    error = ''; loading = true;
    try {
      const value = await api(`history${more && cursor ? `?cursor=${encodeURIComponent(cursor)}` : ''}`);
      history = more ? [...history, ...value.items] : value.items; cursor = value.next_cursor;
      historyOpen = true;
    } catch (e) { error = (e as Error).message; }
    finally { loading = false; }
  }
  async function remove(id: string) {
    try { await api(`history/${id}`, 'DELETE'); history = history.filter(item => item.id !== id); }
    catch (e) { error = (e as Error).message; }
  }
  function viewSaved(item: HistoryItem) {
    generation++;
    result = item.result; submitted = ''; activeCase = null; saved = true; historyOpen = false;
    followup = ''; error = ''; window.history.replaceState({}, '', '/');
  }
  function toggle(value: string) { interactions = interactions.includes(value) ? interactions.filter(v => v !== value) : [...interactions, value]; }
  async function sendFollowup(event?: SubmitEvent) {
    event?.preventDefault();
    if (!activeCase || followupBusy || turns <= 0 || (!followupText.trim() && !interactions.length)) return;
    followupBusy = true; error = '';
    try {
      const value = await api(`cases/${activeCase}/messages`, 'POST', { text: followupText, interactions });
      followup = value.reply; turns = value.remaining_turns; followupText = '';
    } catch (e) {
      if ((e as Error & { code?: string }).code === 'turn_limit') turns = 0;
      else error = (e as Error).message;
    }
    finally { followupBusy = false; }
  }
  async function deleteAccount() {
    deleting = true;
    try { await api('me', 'DELETE'); window.location.assign('/'); }
    catch (e) { error = (e as Error).message; dialog.close(); }
    finally { deleting = false; }
  }
  onMount(async () => {
    try { totals = (await api('visits', 'POST', {})).totals; } catch { void refreshTotals(); }
    const params = new URLSearchParams(window.location.search);
    if (params.get('auth') === 'failed') error = 'No pudimos completar el acceso. Puedes volver a intentarlo y seguir consultando sin cuenta.';
    const id = params.get('case');
    if (id && /^[a-f0-9-]{36}$/.test(id)) {
      loading = true;
      try { result = await api(`cases/${id}`); activeCase = id; void poll(id); }
      catch (e) { error = (e as Error).message; }
      finally { loading = false; }
    } else {
      const example = findExample(params.get('example'));
      if (example) { text = example; input?.focus(); }
    }
  });
</script>

<div class="app-shell">
  <aside class="sidebar" aria-label="Navegación principal">
    <a class="brand" href="/"><img src="/mark.svg" width="36" height="36" alt="" /><span>¿Es estafa?</span></a>
    <button class="new-case" onclick={reset} disabled={loading}>＋ Nueva consulta</button>
    <button class="nav-item" onclick={() => openHistory()}>◷ Mis consultas</button>
    <a class="sidebar-guide" href="/como-funciona">Cómo funciona</a>
    <div class="account-card"><span class="mini-label">A TU RITMO</span><h2>Vuelve a tus consultas.</h2><p>Guarda sólo los casos que elijas y accede a más consultas con una cuenta.</p>
      {#if data.authenticated}<button class="text-button" onclick={() => openHistory()}>Ver mi historial →</button>{:else}<button class="text-button" onclick={() => dialog.showModal()}>Crear cuenta gratis →</button>{/if}
    </div>
    <div class="sidebar-footer">Everyday Trust · <strong>Deep Skill</strong></div>
  </aside>
  <div class="workspace">
    <header class="topbar">
      <a class="mobile-brand brand" href="/"><img src="/mark.svg" width="31" height="31" alt="" /><span>¿Es estafa?</span></a>
      <span class="topbar-caption">Un poco de claridad antes de actuar.</span>
      <div class="topbar-actions">
        {#if data.authenticated}<button class="quiet-button" onclick={() => openHistory()}>Mis consultas</button><button class="quiet-button" onclick={() => dialog.showModal()}>Cuenta</button><form method="POST" action="/auth/logout"><button class="login-button">Salir</button></form>
        {:else}<button class="login-button" onclick={() => dialog.showModal()}>Crear cuenta →</button>{/if}
      </div>
    </header>
    <main class="consultation" id="main-content" aria-busy={loading}>
      {#if error}<p class="error-message" role="alert">{error}</p>{/if}
      {#if historyOpen}
        <section aria-labelledby="history-title"><div class="case-heading"><h1 id="history-title">Mis consultas</h1><button class="quiet-button" onclick={reset}>＋ Nueva consulta</button></div>
          <p class="result-summary">Sólo aparecen los resultados que elegiste guardar. Puedes borrarlos cuando quieras.</p>
          {#if !history.length}<div class="empty-history">Aún no guardaste resultados. Revisa un mensaje y elige «Guardar resultado».</div>{/if}
          <ul class="history-list">{#each history as item (item.id)}<li><button class="history-open" onclick={() => viewSaved(item)}><span class="mini-label">{verdictLabels[item.result.verdict]}</span><p>{item.result.summary}</p><time>{new Date(item.created_at).toLocaleDateString('es-PE')}</time></button><button class="delete-button" aria-label="Borrar consulta guardada" onclick={() => remove(item.id)}>Borrar</button></li>{/each}</ul>
          {#if cursor}<button class="secondary-button" disabled={loading} onclick={() => openHistory(true)}>Ver más consultas</button>{/if}
        </section>
      {:else if !result}
        <section aria-labelledby="entry-title">
          <div class="intro home-intro">
            <div class="eyebrow">¿ES ESTAFA? · CONTEXTO PERUANO</div>
            <h1 id="entry-title">¿Un mensaje te pide<br />dinero o datos?</h1>
            <p>Algunas estafas imitan a tu banco, una empresa o un familiar. Revisa las señales del mensaje y encuentra qué hacer antes de responder.</p>
            <div class="intro-actions"><a class="primary-button" href="#revisar-mensaje" onclick={() => input?.focus()}>Revisar un mensaje →</a><a href="/como-funciona">Cómo funciona</a></div>
            <p class="intro-benefit">Gratis · Puedes empezar sin cuenta</p>
          </div>
          <form class="composer" id="revisar-mensaje" onsubmit={submit}>
            <label for="message">¿Qué mensaje recibiste?</label>
            <textarea bind:this={input} id="message" bind:value={text} maxlength="5000" rows="5" placeholder="Pega aquí el mensaje o enlace que te llegó…" aria-describedby="privacy-note character-count" disabled={loading}></textarea>
            <div class="composer-bottom"><span id="character-count">{text.length.toLocaleString('es-PE')} / 5.000</span><button class="primary-button" disabled={loading || !text.trim()} type="submit">{loading ? 'Revisando señales…' : 'Revisar mensaje →'}</button></div>
          </form>
          <p class="privacy-note" id="privacy-note">Omite claves, códigos, DNI y datos personales. El historial se guarda sólo si tú lo eliges.</p>
        </section>
      {:else}
        <section class="case-view" aria-labelledby="case-title">
          <div class="case-heading"><div class="eyebrow">TU CONSULTA</div><button class="quiet-button" onclick={reset}>＋ Nueva consulta</button></div>
          {#if submitted}<div class="message-bubble"><span class="mini-label">MENSAJE RECIBIDO</span><p>{submitted}</p></div>{/if}
          <article class="result-card" class:high={result.verdict === 'high_risk'} class:low={result.verdict === 'no_signals_detected'} class:neutral={result.verdict === 'inconclusive'} aria-live="polite">
            <div class="result-status"><span>{verdictLabels[result.verdict]}</span><span class="completion-label">{result.analysis_status === 'in_progress' ? 'Completando interpretación…' : 'Revisión finalizada'}</span></div>
            <h1 id="case-title">{result.summary}</h1>
            {#if result.risk_origin === 'interpretation'}<p class="interpretation-note">La sospecha procede de una interpretación de IA, sin corroboración externa del patrón.</p>{/if}
            <div class="next-step"><div><span class="mini-label">TU SIGUIENTE PASO</span><h2>{result.advice[0]}</h2><p>{result.advice[1]}</p></div></div>
            <ResultEvidence {result} />
          </article>
          {#if activeCase}
            <details class="help-panel">
              <summary>¿Necesitas más ayuda con este mensaje?</summary>
              <section class="interaction-section" aria-labelledby="interaction-title">
                <h2 id="interaction-title">¿Abriste el enlace, compartiste datos o pagaste?</h2>
                <div class="interaction-options">{#each [{id:'clicked',label:'Abrí el enlace'},{id:'shared_data',label:'Compartí datos'},{id:'paid',label:'Pagué'}] as item}<button class="choice" disabled={turns <= 0 || followupBusy} aria-pressed={interactions.includes(item.id)} onclick={() => toggle(item.id)}>{item.label}</button>{/each}</div>
                <form class="followup-form" onsubmit={sendFollowup}>
                  <label for="followup">También puedes preguntar sobre este mensaje</label>
                  <input id="followup" bind:value={followupText} maxlength="1000" placeholder="¿Cómo verifico quién escribe?" disabled={turns <= 0 || followupBusy} />
                  <button class="secondary-button" disabled={followupBusy || turns <= 0 || (!followupText.trim() && !interactions.length)}>{followupBusy ? 'Preparando ayuda…' : 'Ver qué hacer'}</button>
                  {#if turns <= 0}<p class="small-note" role="status">Llegaste al límite de preguntas para este mensaje. Puedes revisar otro mensaje con «Nueva consulta».</p>{/if}
                </form>
                {#if followup}<div class="follow-up" role="status"><img src="/mark.svg" width="26" height="26" alt="" /><p>{followup}</p></div>{/if}
              </section>
            </details>
            <div class="save-case"><div><p>Vuelve a ver este resultado en tu historial.<span>Sólo se guarda el resumen, sin el mensaje original.</span></p></div><button class="secondary-button" disabled={saved || result.analysis_status === 'in_progress'} onclick={save}>{saved ? 'Resultado guardado' : 'Guardar resultado'}</button></div>
            {#if result.analysis_status === 'completed'}{#key activeCase}<ReviewForm caseId={activeCase} onrecord={() => void refreshTotals()} />{/key}{/if}
          {:else}<p class="privacy-note">Resultado histórico. Las comprobaciones corresponden a la fecha indicada.</p>{/if}
        </section>
      {/if}
      <Traction {totals} />
      <footer class="main-footer"><a href="/como-funciona">Cómo funciona</a><a href="/privacidad">Uso de datos y límites</a><span>Everyday Trust · Deep Skill</span></footer>
    </main>
  </div>
</div>
<dialog bind:this={dialog} aria-labelledby="account-title"><form method="dialog"><button class="dialog-close" aria-label="Cerrar">×</button></form><img src="/mark.svg" width="42" height="42" alt="" /><h2 id="account-title">{data.authenticated ? 'Tu cuenta' : activeCase ? 'Guarda el resultado para después.' : 'Más consultas y tu historial.'}</h2>
  {#if !data.authenticated}<p>{activeCase ? 'Crea una cuenta gratuita para guardar un resumen y volver a verlo cuando lo necesites.' : 'Puedes usar el verificador sin registrarte. Con una cuenta gratuita tienes:'}</p><ul><li>Hasta 25 consultas al día, frente a 5 sin cuenta.</li><li>Sólo se guardan los resúmenes que tú elijas.</li><li>Historial privado para ver y borrar resultados.</li></ul>{/if}
  {#if data.authenticated}
    <p class="dialog-note">Tu sesión está activa. Para eliminar la cuenta se requiere haber iniciado sesión en los últimos cinco minutos.</p><a class="quiet-button" href="/auth/login?reauth=1">Volver a identificarme</a>
    {#if confirmDelete}<p>Se eliminarán tu cuenta y todas tus consultas guardadas. Esta acción no se puede deshacer.</p><button class="delete-button" disabled={deleting} onclick={deleteAccount}>{deleting ? 'Eliminando…' : 'Confirmar eliminación de mi cuenta'}</button>{:else}<button class="delete-button" onclick={() => confirmDelete = true}>Eliminar mi cuenta</button>{/if}
  {:else if data.authConfigured}<a class="primary-button account-link" href={loginUrl}>Crear cuenta o iniciar sesión →</a>{:else}<p class="dialog-note">El registro aún no está habilitado en este entorno. Las consultas anónimas siguen disponibles.</p>{/if}
  <form method="dialog"><button class="quiet-button">Volver a la consulta</button></form>
</dialog>
