# Everyday Trust, Hack the Andes 2026

Verificador de estafas para peruanos: el usuario pega un mensaje, link o número y recibe veredicto, motivos y qué hacer. Equipo `deepskill` (JP solo), track Seguridad. Evento del 17 oct 9:00 al 18 oct ~14:00.

## Inicio de sesión

Leer `.analisis/README.md` (local, ignorado por git): reglas del evento, fuentes de datos verificadas, competidores, plan con pendientes y preferencias de JP. Datos crudos en `data/raw/` (también ignorado).

## Repo público

- Este repo y su URL se publican en la galería del evento. Nunca commitear llaves, `.dev.vars`, datos de clientes de Deep Skill ni mensajes reales con datos personales de terceros.
- Las llaves locales van en `.env` ignorado. Para AWS, seguir el diseño de secretos de `devops-agents`; nunca hornearlas en imágenes, user data, argumentos de build ni archivos versionados.

## Stack

### Decisiones vigentes (17-oct-2026)

JP confirmó SvelteKit/TypeScript/Tailwind, API Elixir/Phoenix, PostgreSQL, Cognito y BFF con cookie opaca HttpOnly y tokens del proveedor en servidor. IA por API directa: candidatos `muse-spark-1.3-contributor` y `deepseek-flash`; falta elegir y validar condiciones de datos. JP revisó la opción inicial y eligió RDS PostgreSQL gestionado; no alojar la BD de producción en EC2. Leer `docs/README.md` y `docs/architecture/aws-deployment.md`.

La documentación operativa de AWS, Docker, Cloudflare, dominio, secretos, costos, backups y recursos se centraliza en `../devops-agents/docs/hack-the-andes-seguridad.md`; leer también las instrucciones de ese repositorio antes de tocar infraestructura. Respetar su preferencia de familia T3a. Registrar allí cada cambio y actualizar inventarios al crear recursos. El repo público conserva diseño reproducible, sin credenciales ni identificadores operativos privados.

El borrador Better Auth/D1 está aislado en `wip/paused-cloudflare-auth`; no integrarlo. La implementación actual es SvelteKit con adapter-node, BFF PostgreSQL y API Phoenix en `api/`. Leer `docs/architecture/implementation.md` para el estado comprobado y los límites. AWS está aprovisionado y la aplicación funciona en privado. CI/GHCR/OIDC/SSM y 12 comprobaciones de Cognito/RDS reales pasaron; el OIDC completo del navegador y la entrada pública esperan el permiso de Cloudflare. Operación canónica en `../devops-agents/everyday-trust/`.

- Catálogo oficial activo en código: `api/priv/catalog/brands.json`; sólo añadir dominios confirmados y con fuente revisada. El motor anterior TypeScript queda como referencia de regresión.
- `api/lib/everyday_trust/signals.ex`: extracción y comprobaciones. `analysis.ex`: política y evaluación. `interpreter.ex`: adaptadores acotados, deshabilitados hasta acordar condiciones y credenciales.
- `cases.ex`, `accounts.ex`, `identity.ex`: casos, titulares, cuotas, borrado y JWT. El navegador nunca elige un owner id.
- `src/lib/server/auth.ts`: OIDC/PKCE, cookies opacas y tokens cifrados. `src/routes/api/v1/[...path]/+server.ts`: BFF, nunca aceptar tokens del navegador como identidad propia de una cuenta.
- La prueba E2E usa únicamente identidad simulada y una base local separada. Sus helpers están excluidos de los contextos Docker. Nunca habilitarlos en producción.

## Marca y UI

JP confirmó **Everyday Trust** y el repo `deep-skill/everyday-trust`. La web conserva **¿Es estafa?** y **Revisa antes de responder**. La carpeta local mantiene su ruta. JP aprobó provisionalmente la identidad visual y después pidió implementar: la primera UI funcional está integrada usando esa propuesta como referencia. Esto no acredita una aprobación final de cada pantalla ni compra de dominio. Leer `docs/design/brand.md`; sus ejemplos HTML siguen separados de la app real.

## Comandos

```bash
npm run dev      # local
npm run check    # tipos (build no los verifica)
npm test         # build + regresiones del motor de referencia
npm start        # servidor Node compilado; requiere env de ejecución
```

## Entrega (CLI del evento)

`npx -y -p hacktheandes-cli@latest andes project submit --deployment-url ... --presentation-url ... --github-url ... --description "..."`. El jurado ve la copia tomada al abrir la evaluación: entregar temprano y actualizar después. Avances con `andes project update --message "..."` (públicos, sin secretos).

Hora límite de entrega: domingo 18, 09:00. Sin URL pública, demo en vivo y repo en GitHub, el equipo no se puntúa. Rúbrica (17-oct): técnico 75% (complejidad 30%, funciona en vivo 25%, calidad del código 20%), producto 25% (problema e impacto 15%, claridad 10%) y bonus de tracción hasta +0,5 con evidencia desde el producto. Empate: complejidad técnica. Pitch de 3 min + 2 de preguntas en la PC de la organización: probar deploy y presentación en ventana privada.
