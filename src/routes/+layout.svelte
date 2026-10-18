<script lang="ts">
	import '../app.css';

	let { children } = $props();
</script>

<svelte:head>
	<title>¿Es estafa? · Everyday Trust</title>
	<link rel="icon" href="/favicon.svg" type="image/svg+xml" />
	<meta
		name="description"
		content="Revisa las señales de un mensaje sospechoso y encuentra tu siguiente paso, con contexto peruano."
	/>
</svelte:head>

{@render children()}
