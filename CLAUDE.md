# ¿Es estafa? (provisional), Hack the Andes 2026

Verificador de estafas para peruanos: el usuario pega un mensaje, link o número y recibe veredicto, motivos y qué hacer. Equipo `deepskill` (JP solo), track Seguridad. Evento del 17 oct 9:00 al 18 oct ~14:00.

## Repo público

- Este repo y su URL se publican en la galería del evento. Nunca commitear llaves, `.dev.vars`, datos de clientes de Deep Skill ni mensajes reales con datos personales de terceros.
- Las llaves van en `.dev.vars` (local) y como secrets del Worker (`npx wrangler secret put NOMBRE`).

## Stack

- SvelteKit 5 + Tailwind 4, desplegado como Worker de Cloudflare con static assets (misma receta que `../coneimin-web`): `nodejs_compat` obligatorio y `routes` antes de cualquier `[tabla]` en `wrangler.toml`.
- `src/lib/server/signals.ts`: señales verificables (links, números, texto). `src/lib/server/brands.ts`: dominios oficiales; solo entran dominios confirmados, porque un error marcaría phishing como legítimo.
- `src/lib/server/analyze.ts`: puntaje, veredicto y consejos. `src/routes/api/analyze/+server.ts`: endpoint `POST { text }`.

## Comandos

```bash
npm run dev      # local
npm run check    # tipos (build no los verifica)
npm run deploy   # build + wrangler deploy
```

## Entrega (CLI del evento)

`npx -y -p hacktheandes-cli@latest andes project submit --deployment-url ... --presentation-url ... --github-url ... --description "..."`. El jurado ve la copia tomada al abrir la evaluación: entregar temprano y actualizar después. Avances con `andes project update --message "..."` (públicos, sin secretos).

Rúbrica: tracción 30%, esfuerzo técnico 40%, pitch 30% (3 min + 2 de preguntas, en la PC de la organización). Probar deploy y presentación en ventana privada.
