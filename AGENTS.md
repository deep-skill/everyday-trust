# ¿Es estafa? (provisional), Hack the Andes 2026

Verificador de estafas para peruanos: el usuario pega un mensaje, link o número y recibe veredicto, motivos y qué hacer. Equipo `deepskill` (JP solo), track Seguridad. Evento del 17 oct 9:00 al 18 oct ~14:00.

## Inicio de sesión

Leer `.analisis/README.md` (local, ignorado por git): reglas del evento, fuentes de datos verificadas, competidores, plan con pendientes y preferencias de JP. Datos crudos en `data/raw/` (también ignorado).

## Repo público

- Este repo y su URL se publican en la galería del evento. Nunca commitear llaves, `.dev.vars`, datos de clientes de Deep Skill ni mensajes reales con datos personales de terceros.
- Las llaves van en `.dev.vars` (local) y como secrets del Worker (`npx wrangler secret put NOMBRE`).

## Stack

### Definición vigente antes de implementar

JP pidió definir y validar negocio, VSM, UX y arquitectura antes de continuar con código. Leer `docs/README.md`. Infraestructura objetivo: AWS, con backend API separado. Lenguaje, autenticación y modelo físico se acuerdan con JP; no inferir su aprobación por instalar una dependencia. El borrador local de Better Auth/D1 quedó detenido y no representa una decisión de arquitectura. Las instrucciones Cloudflare siguientes describen el prototipo existente.

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

Hora límite de entrega: domingo 18, 09:00. Sin URL pública, demo en vivo y repo en GitHub, el equipo no se puntúa. Rúbrica (17-oct): técnico 75% (complejidad 30%, funciona en vivo 25%, calidad del código 20%), producto 25% (problema e impacto 15%, claridad 10%) y bonus de tracción hasta +0,5 con evidencia desde el producto. Empate: complejidad técnica. Pitch de 3 min + 2 de preguntas en la PC de la organización: probar deploy y presentación en ventana privada.
