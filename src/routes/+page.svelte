<script lang="ts">
  import { onMount } from 'svelte';
  import type { PageProps } from './$types';
  import { verdictLabels, type CaseResult, type HistoryItem } from '$lib/cases';
  let { data }: PageProps = $props();
  let text = $state(''), submitted = $state(''), loading = $state(false), error = $state('');
  let result = $state<CaseResult | null>(null), activeCase = $state<string | null>(null);
  let history = $state<HistoryItem[]>([]), historyOpen = $state(false), cursor = $state<string | null>(null);
  let saved = $state(false), followup = $state(''), followupText = $state(''), followupBusy = $state(false);
  let turns = $state(5), interactions = $state<string[]>([]), feedback = $state(false);
  let confirmDelete = $state(false), deleting = $state(false);
  let generation = 0;
  let activity = $state<{ queries: Record<string, number>; demos: Record<string, number> } | null>(null);
  let dialog: HTMLDialogElement;
  let input = $state<HTMLTextAreaElement>();
  const examples = [
    { label: 'Un familiar con otro número', text: 'Hola mamá, cambié de número. Necesito que me hagas una transferencia urgente. Te cuento después.' },
    { label: 'Un supuesto aviso del banco', text: 'BANCO EJEMPLO: Tu cuenta será bloqueada hoy. Valida tu contraseña en https://acceso-banco.example/validar para evitar el bloqueo.' }
  ];
  const loginUrl = $derived(`/auth/login${activeCase ? `?return_case=${encodeURIComponent(activeCase)}` : ''}`);
  async function api(path: string, method = 'GET', body?: unknown) {
    const response = await fetch(`/api/v1/${path}`, { method, headers: { 'content-type': 'application/json' }, ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
    const value = await response.json().catch(() => null);
    if (!response.ok || !value) throw new Error(value?.error?.message ?? 'No pudimos completar la solicitud.');
    return value;
  }
  async function poll(id: string, version = generation) {
    for (let attempt = 0; attempt < 22; attempt++) {
      if (version !== generation || activeCase !== id || result?.analysis_status !== 'in_progress') return;
      await new Promise(resolve => setTimeout(resolve, 600));
      try {
        const next: CaseResult = await api(`cases/${id}`);
        if (version !== generation || activeCase !== id) return;
        if (next.revision >= (result?.revision ?? 0)) result = next;
      } catch { return; }
    }
  }
  function reset() {
    generation++;

    text = ''; submitted = ''; result = null; activeCase = null; saved = false; error = '';
    followup = ''; followupText = ''; turns = 5; interactions = []; feedback = false; historyOpen = false;
    window.history.replaceState({}, '', '/');
    input?.focus();
  }
  async function submit(event?: SubmitEvent) {
    event?.preventDefault();
    if (loading || !text.trim()) return;
    generation++;
    error = ''; loading = true; saved = false; followup = ''; interactions = []; turns = 5; feedback = false;
    try {
      const value = await api('cases', 'POST', { text });
      submitted = text; text = ''; result = value; activeCase = value.id; historyOpen = false;
      window.history.replaceState({}, '', `/?case=${value.id}`);
      void poll(value.id);
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
    } catch (e) { error = (e as Error).message; }
    finally { followupBusy = false; }
  }
  async function rate(value: string) {
    try { await api(`cases/${activeCase}/feedback`, 'POST', { value }); feedback = true; }
    catch (e) { error = (e as Error).message; }
  }
  async function deleteAccount() {
    deleting = true;
    try { await api('me', 'DELETE'); window.location.assign('/'); }
    catch (e) { error = (e as Error).message; dialog.close(); }
    finally { deleting = false; }
  }
  onMount(async () => {
    void api('stats').then(value => activity = value).catch(() => {});
    const params = new URLSearchParams(window.location.search);
    if (params.get('auth') === 'failed') error = 'No pudimos completar el acceso. Puedes volver a intentarlo y seguir consultando sin cuenta.';
    const id = params.get('case');
    if (id && /^[a-f0-9-]{36}$/.test(id)) {
      loading = true;
      try { result = await api(`cases/${id}`); activeCase = id; void poll(id); }
      catch (e) { error = (e as Error).message; }
      finally { loading = false; }
    }
  });
</script>

<div class="app-shell">
  <aside class="sidebar" aria-label="Navegación principal">
    <a class="brand" href="/"><img src="/mark.svg" width="36" height="36" alt="" /><span>¿Es estafa?</span></a>
    <button class="new-case" onclick={reset} disabled={loading}>＋ Nueva consulta</button>
    <button class="nav-item" onclick={() => openHistory()}>◷ Mis consultas</button>
    <div class="sidebar-note"><p>Una pausa puede<br />hacer la diferencia.</p></div>
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
          {#if !history.length}<div class="empty-history">Aún no guardaste consultas. Revisa un mensaje y elige «Guardar consulta».</div>{/if}
          <ul class="history-list">{#each history as item (item.id)}<li><button class="history-open" onclick={() => viewSaved(item)}><span class="mini-label">{verdictLabels[item.result.verdict]}</span><p>{item.result.summary}</p><time>{new Date(item.created_at).toLocaleDateString('es-PE')}</time></button><button class="delete-button" aria-label="Borrar consulta guardada" onclick={() => remove(item.id)}>Borrar</button></li>{/each}</ul>
          {#if cursor}<button class="secondary-button" disabled={loading} onclick={() => openHistory(true)}>Ver más consultas</button>{/if}
        </section>
      {:else if !result}
        <section aria-labelledby="entry-title">
          <div class="intro"><div class="eyebrow">MENSAJES CON CONTEXTO PERUANO</div><h1 id="entry-title">Revisa antes<br />de responder<span>.</span></h1><p>¿Ese mensaje te genera dudas? Revisa sus señales y encuentra tu siguiente paso.</p></div>
          <form class="composer" onsubmit={submit}>
            <label for="message">¿Qué mensaje recibiste?</label>
            <textarea bind:this={input} id="message" bind:value={text} maxlength="5000" rows="5" placeholder="Pega aquí el mensaje o enlace que te llegó…" aria-describedby="privacy-note character-count" disabled={loading}></textarea>
            <div class="composer-bottom"><span id="character-count">{text.length.toLocaleString('es-PE')} / 5.000</span><button class="primary-button" disabled={loading || !text.trim()} type="submit">{loading ? 'Revisando señales…' : 'Revisar mensaje →'}</button></div>
          </form>
          <p class="privacy-note" id="privacy-note">Omite claves, códigos, DNI y datos personales. El historial se guarda sólo si tú lo eliges.</p>
          <div class="example-section"><span class="example-label">¿Prefieres probar primero?</span><div class="example-buttons">{#each examples as example}<button class="example-button" disabled={loading} onclick={() => { text = example.text; submit(); }}>{example.label} →</button>{/each}</div><p class="small-note">Ejemplos ficticios, analizados con el mismo motor de la consulta.</p></div>
          <div class="how-strip" aria-label="Qué encontrarás"><div><span>01</span><p>Las señales</p></div><div><span>02</span><p>El porqué</p></div><div><span>03</span><p>Qué hacer</p></div></div>
        </section>
      {:else}
        <section class="case-view" aria-labelledby="case-title">
          <div class="case-heading"><div class="eyebrow">TU CONSULTA</div><button class="quiet-button" onclick={reset}>＋ Nueva consulta</button></div>
          {#if submitted}<div class="message-bubble"><span class="mini-label">MENSAJE RECIBIDO</span><p>{submitted}</p></div>{/if}
          <article class="result-card" class:high={result.verdict === 'high_risk'} class:low={result.verdict === 'no_signals_detected'} class:neutral={result.verdict === 'inconclusive'} aria-live="polite">
            <div class="result-status"><span>{verdictLabels[result.verdict]}</span><span class="completion-label">{result.analysis_status === 'in_progress' ? 'Completando interpretación…' : 'Revisión finalizada'}</span></div>
            <h1 id="case-title">{result.summary}</h1>
            <p class="small-note">{result.analysis_mode === 'signals_and_ai' ? 'Señales e interpretación de IA' : 'Análisis por señales'} · {new Date(result.analyzed_at).toLocaleString('es-PE')}</p>
            {#if result.risk_origin === 'interpretation'}<p class="interpretation-note">La sospecha procede de una interpretación de IA, sin corroboración externa del patrón.</p>{/if}
            <div class="next-step"><div><span class="mini-label">TU SIGUIENTE PASO</span><h2>{result.advice[0]}</h2><p>{result.advice[1]}</p></div></div>
            <details class="evidence"><summary>Ver señales y alcance de la revisión</summary><div class="evidence-body">
              <ul>{#each result.signals as signal, i (signal.id + i)}<li>{signal.message}</li>{/each}</ul>
              {#if !result.signals.length}<p>No detectamos coincidencias con las reglas disponibles.</p>{/if}
              {#each result.domains as domain}<p class="domain">{domain.domain ?? 'Dominio no identificable'}{domain.official_brand ? ` · Dominio de ${domain.official_brand}` : ''}</p>{#if domain.feed_checked_at}<p class="small-note">Snapshot del feed descargado el {new Date(domain.feed_checked_at).toLocaleString('es-PE')}. {domain.feed_published_at ? `Publicado el ${new Date(domain.feed_published_at).toLocaleDateString('es-PE')}.` : ''}</p>{/if}{/each}
              <p>Una coincidencia de dominio no autentica al remitente. No verificamos quién está detrás de un número.</p>
              <p>Lista de phishing: {result.coverage.threat_feed === 'completed' ? 'contrastada con Phishing.Database' : result.coverage.threat_feed === 'not_applicable' ? 'no aplica a este mensaje' : 'comprobación no disponible o pendiente de revisión'}. Antigüedad: {result.coverage.registration === 'partial' ? 'algunas comprobaciones no estuvieron disponibles' : 'según aplicabilidad'}. IA: {result.coverage.ai === 'completed' ? 'completada' : result.coverage.ai === 'disabled' ? 'no utilizada' : 'no disponible; se conserva el análisis por señales'}.</p>
              {#if result.coverage.threat_feed === 'completed' || result.coverage.threat_feed === 'partial'}<p class="small-note">Fuente: <a href="https://github.com/Phishing-Database/Phishing.Database" target="_blank" rel="noreferrer">Phishing.Database</a>. Un reporte expresa lo observado por esa fuente y puede requerir revisión.</p>{/if}
            </div></details>
          </article>
          {#if activeCase}
            <section class="interaction-section" aria-labelledby="interaction-title"><div class="section-heading"><h2 id="interaction-title">¿Llegaste a hacer algo?</h2><span>Opcional</span></div><p>Elige lo que ocurrió para recibir orientación. No incluyas claves ni comprobantes.</p>
              <div class="interaction-options">{#each [{id:'clicked',label:'Abrí el enlace'},{id:'shared_data',label:'Compartí datos'},{id:'paid',label:'Pagué'}] as item}<button class="choice" aria-pressed={interactions.includes(item.id)} onclick={() => toggle(item.id)}>{item.label}</button>{/each}</div>
              <form class="followup-form" onsubmit={sendFollowup}><label for="followup">Una aclaración sobre este caso</label><input id="followup" bind:value={followupText} maxlength="1000" placeholder="Por ejemplo: ¿cómo verifico quién escribe?" disabled={turns <= 0} /><button class="secondary-button" disabled={followupBusy || turns <= 0 || (!followupText.trim() && !interactions.length)}>{followupBusy ? 'Preparando orientación…' : 'Ver orientación'}</button><span class="small-note">{turns} turnos disponibles. Orientación acotada a esta consulta.</span></form>
              {#if followup}<div class="follow-up" role="status"><img src="/mark.svg" width="26" height="26" alt="" /><p>{followup}</p></div>{/if}
            </section>
            <div class="save-case"><div><p>Ten esta consulta a mano.<span>Guardamos un resumen sin el mensaje original.</span></p></div><button class="secondary-button" disabled={saved || result.analysis_status === 'in_progress'} onclick={save}>{saved ? 'Consulta guardada' : data.authenticated ? 'Guardar consulta' : 'Crear cuenta para guardar →'}</button></div>
            <div class="feedback">{#if feedback}<p role="status">Gracias. Tu opinión ayuda a mejorar la orientación.</p>{:else}<span>¿Te ayudó esta revisión?</span><button class="quiet-button" onclick={() => rate('helpful')}>Sí</button><button class="quiet-button" onclick={() => rate('unhelpful')}>No</button>{/if}</div>
          {:else}<p class="privacy-note">Resultado histórico. Las comprobaciones corresponden a la fecha indicada.</p>{/if}
        </section>
      {/if}
      {#if activity}<p class="small-note">Hoy (UTC): {activity.queries.completed ?? 0} consultas completadas · {activity.demos.completed ?? 0} pruebas con ejemplos. Opiniones: {activity.queries.helpful ?? 0} útiles / {activity.queries.unhelpful ?? 0} no útiles. Conteos agregados, no personas únicas.</p>{/if}
      <footer class="main-footer"><a href="/privacidad">Uso de datos y límites</a><span>Everyday Trust · Deep Skill</span></footer>
    </main>
  </div>
</div>
<dialog bind:this={dialog} aria-labelledby="account-title"><form method="dialog"><button class="dialog-close" aria-label="Cerrar">×</button></form><img src="/mark.svg" width="42" height="42" alt="" /><h2 id="account-title">Tus consultas, a tu ritmo.</h2><p>Puedes usar el verificador sin registrarte. Con una cuenta gratuita tienes:</p><ul><li>Hasta 25 consultas al día, frente a 5 sin cuenta.</li><li>Guardado voluntario de resúmenes.</li><li>Historial privado para revisar y borrar.</li></ul>
  {#if data.authenticated}
    <p class="dialog-note">Tu sesión está activa. Para eliminar la cuenta se requiere haber iniciado sesión en los últimos cinco minutos.</p><a class="quiet-button" href="/auth/login?reauth=1">Volver a identificarme</a>
    {#if confirmDelete}<p>Se eliminarán tu cuenta y todas tus consultas guardadas. Esta acción no se puede deshacer.</p><button class="delete-button" disabled={deleting} onclick={deleteAccount}>{deleting ? 'Eliminando…' : 'Confirmar eliminación de mi cuenta'}</button>{:else}<button class="delete-button" onclick={() => confirmDelete = true}>Eliminar mi cuenta</button>{/if}
  {:else if data.authConfigured}<a class="primary-button account-link" href={loginUrl}>Crear cuenta o iniciar sesión →</a>{:else}<p class="dialog-note">El registro aún no está habilitado en este entorno. Las consultas anónimas siguen disponibles.</p>{/if}
  <form method="dialog"><button class="quiet-button">Volver a la consulta</button></form>
</dialog>
