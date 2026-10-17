<script lang="ts">
	import '../app.css';

	let { children } = $props();
</script>

<svelte:head>
	<title>¿Es estafa?</title>
	<meta
		name="description"
		content="Pega el mensaje, link o número que te llegó y descubre si es una estafa."
	/>
</svelte:head>

{@render children()}
