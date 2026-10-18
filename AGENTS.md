# Everyday Trust, Hack the Andes 2026

Verificador de estafas para peruanos: el usuario pega un mensaje, link o número y recibe veredicto, motivos y qué hacer. Equipo `deepskill` (JP solo), track Seguridad. Evento del 17 oct 9:00 al 18 oct ~14:00.

## Inicio de sesión

Leer `.analisis/README.md` (local, ignorado por git): reglas del evento, fuentes de datos verificadas, competidores, plan con pendientes y preferencias de JP. Datos crudos en `data/raw/` (también ignorado).

## Repo público

- Este repo y su URL se publican en la galería del evento. Nunca commitear llaves, `.dev.vars`, datos de clientes de Deep Skill ni mensajes reales con datos personales de terceros.
- En el prototipo, las llaves van en `.dev.vars` (local) y como secrets del Worker (`npx wrangler secret put NOMBRE`). Para AWS, seguir el diseño de secretos de `devops-agents`; nunca hornearlas en imágenes, user data, argumentos de build ni archivos versionados.

## Stack

### Decisiones vigentes (17-oct-2026)

JP confirmó SvelteKit/TypeScript/Tailwind, API Elixir/Phoenix, PostgreSQL, Cognito y BFF con cookie opaca HttpOnly y tokens del proveedor en servidor. IA por API directa: candidatos `muse-spark-1.3-contributor` y `deepseek-flash`; falta elegir y validar condiciones de datos. JP revisó la opción inicial y eligió RDS PostgreSQL gestionado; no alojar la BD de producción en EC2. Leer `docs/README.md` y `docs/architecture/aws-deployment.md`.

La documentación operativa de AWS, Docker, Cloudflare, dominio, secretos, costos, backups y recursos se centraliza en `../devops-agents/docs/hack-the-andes-seguridad.md`; leer también las instrucciones de ese repositorio antes de tocar infraestructura. Respetar su preferencia de familia T3a. Registrar allí cada cambio y actualizar inventarios al crear recursos. El repo público conserva diseño reproducible, sin credenciales ni identificadores operativos privados.

El borrador Better Auth/D1 está aislado en `wip/paused-cloudflare-auth`; no representa el stack aprobado. La propuesta física es EC2 con Docker Compose (Nginx, web/BFF, API y cloudflared), RDS privado, Cognito, GitHub Actions y GHCR; pendiente de implementar y comprobar. Las instrucciones Cloudflare siguientes describen el prototipo existente.

- Svelte 5 + SvelteKit 2 + Tailwind 4, desplegado como Worker de Cloudflare con static assets (misma receta que `../coneimin-web`): `nodejs_compat` obligatorio y `routes` antes de cualquier `[tabla]` en `wrangler.toml`.
- `src/lib/server/signals.ts`: señales verificables (links, números, texto). `src/lib/server/brands.ts`: dominios oficiales; solo entran dominios confirmados, porque un error marcaría phishing como legítimo.
- `src/lib/server/analyze.ts`: puntaje, veredicto y consejos. `src/routes/api/analyze/+server.ts`: endpoint `POST { text }`.

## Marca y UI

JP confirmó **Everyday Trust** como nombre del proyecto público y autorizó publicar `deep-skill/everyday-trust`. Nombre de la web: **¿Es estafa?**. Bajada: **Revisa antes de responder**. La carpeta local conserva su nombre para no romper otras sesiones. Leer `docs/design/brand.md`. La propuesta visual y SVG están en `docs/design/`; son una revisión separada, con ejemplos sintéticos, sin cambiar aún `src/` ni conectar auth/IA. JP aprobó provisionalmente la identidad visual 0.1 (logo, paleta y tipografía). Las pantallas siguen para revisión; no inferir su aprobación ni la compra de dominio.

## Comandos

```bash
npm run dev      # local
npm run check    # tipos (build no los verifica)
npm run deploy   # build + wrangler deploy
```

## Entrega (CLI del evento)

`npx -y -p hacktheandes-cli@latest andes project submit --deployment-url ... --presentation-url ... --github-url ... --description "..."`. El jurado ve la copia tomada al abrir la evaluación: entregar temprano y actualizar después. Avances con `andes project update --message "..."` (públicos, sin secretos).

Hora límite de entrega: domingo 18, 09:00. Sin URL pública, demo en vivo y repo en GitHub, el equipo no se puntúa. Rúbrica (17-oct): técnico 75% (complejidad 30%, funciona en vivo 25%, calidad del código 20%), producto 25% (problema e impacto 15%, claridad 10%) y bonus de tracción hasta +0,5 con evidencia desde el producto. Empate: complejidad técnica. Pitch de 3 min + 2 de preguntas en la PC de la organización: probar deploy y presentación en ventana privada.
