<script lang="ts">
  import SafetyGuide from '$lib/components/SafetyGuide.svelte';
</script>

<div class="guide-page">
  <header class="guide-header"><a class="brand" href="/"><img src="/mark.svg" width="36" height="36" alt="" /><span>¿Es estafa?</span></a><a class="secondary-button" href="/">Volver al verificador</a></header>
  <main>
    <div class="guide-intro"><h1>Un poco de claridad antes de actuar.</h1><p>Te ayudamos a reconocer señales de engaño y a encontrar un siguiente paso para verificar.</p><a class="primary-button" href="/">Revisar un mensaje →</a></div>
    <SafetyGuide />
  </main>
  <footer class="main-footer"><a href="/privacidad">Uso de datos y límites</a><span>Everyday Trust · Deep Skill</span></footer>
</div>
