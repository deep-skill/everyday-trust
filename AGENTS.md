# Everyday Trust, Hack the Andes 2026

Verificador de estafas para peruanos: el usuario pega un mensaje, link o número y recibe veredicto, motivos y qué hacer. Equipo `deepskill` (JP solo), track Seguridad. Evento del 17 oct 9:00 al 18 oct ~14:00.

## Inicio de sesión

Leer `.analisis/README.md` (local, ignorado por git): reglas del evento, fuentes de datos verificadas, competidores, plan con pendientes y preferencias de JP. Datos crudos en `data/raw/` (también ignorado).

## Repo público

- Este repo y su URL se publican en la galería del evento. Nunca commitear llaves, `.dev.vars`, datos de clientes de Deep Skill ni mensajes reales con datos personales de terceros.
- Las llaves locales van en `.env` ignorado. Para AWS, seguir el diseño de secretos de `devops-agents`; nunca hornearlas en imágenes, user data, argumentos de build ni archivos versionados.

## Stack

### Decisiones vigentes (17-oct-2026)

JP confirmó SvelteKit/TypeScript/Tailwind, API Elixir/Phoenix, PostgreSQL, Cognito y BFF con cookie opaca HttpOnly y tokens del proveedor en servidor. IA por API directa: JP confirmó `muse-spark-1.3-contributor` con contexto completo para el piloto de hackathon y autorizó expresamente activarlo en la URL pública sin login. Recibe el mensaje original y todo el resultado de comprobaciones; las preguntas se envían completas con el resultado disponible. Se retiró la restricción a códigos de señales por instrucción expresa de JP. No persistir el mensaje original ni registrar payloads. Revisar modalidad/modelo antes de la difusión general. El corte está publicado y desplegado, con IA activa en AWS y comprobada mediante ejemplos ficticios. La configuración compatible usa `AI_INPUT_MODE=full_context`. JP eligió RDS PostgreSQL gestionado; no alojar la BD de producción en EC2. Leer `docs/README.md`, `docs/architecture/ai-interpretation.md` y `docs/architecture/aws-deployment.md`.

La documentación operativa de AWS, Docker, Cloudflare, dominio, secretos, costos, backups y recursos se centraliza en `../devops-agents/docs/hack-the-andes-seguridad.md`; leer también las instrucciones de ese repositorio antes de tocar infraestructura. Respetar su preferencia de familia T3a. Registrar allí cada cambio y actualizar inventarios al crear recursos. El repo público conserva diseño reproducible, sin credenciales ni identificadores operativos privados.

El borrador Better Auth/D1 está aislado en `wip/paused-cloudflare-auth`; no integrarlo. La implementación actual es SvelteKit con adapter-node, BFF PostgreSQL y API Phoenix en `api/`. Leer `docs/architecture/implementation.md` para el estado comprobado y los límites. AWS está aprovisionado y la web es pública en `https://verifica.deepskill.space` mediante Cloudflare Tunnel, sin puertos entrantes en EC2. CI/GHCR/OIDC/SSM, 12 comprobaciones de Cognito/RDS reales y consulta anónima pública pasaron; acceso, guardado e historial se comprobaron en Chrome privado. El logout corregido pasó por HTTP; repetirlo visualmente cuando el control de ventanas esté disponible. Operación canónica en `../devops-agents/everyday-trust/`.

- Catálogo oficial activo en código: `api/priv/catalog/brands.json`; sólo añadir dominios confirmados y con fuente revisada. El motor anterior TypeScript queda como referencia de regresión.
- `api/lib/everyday_trust/signals.ex`: extracción y comprobaciones. `analysis.ex`: política y evaluación. `destination.ex`: comprobación HEAD de la raíz del sitio, DNS/IP públicos fijados y redirecciones revalidadas. `interpreter.ex`: adaptador Contributor de contexto completo para el piloto, con salida estructurada y fallback.
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

## Cierre del piloto,18-oct

Métricas discretas en el footer y reseñas ligadas a un caso completado. Visitas aproximadas por sesión; no anunciar personas únicas. Consultas y valoraciones separan demos. Comentarios privados hasta500 caracteres, sin IA, retención30d y borrado con cuenta. Backend: metrics.ex y reviews.ex. Fuentes de pitch HTML en docs/presentation, copiadas a static/presentacion por prebuild. No editar la copia generada. Seguridad y cuotas en docs/architecture/security-review.md.109 Phoenix/45 Node con evaluación sintética24 casos; corte final155516f pasó109/45 en CI y quedó desplegado. Docker local sigue apagado; preferir CI para Phoenix. Los posts personales están en docs/launch/social-copy.md; faltan enlaces exactos de JP antes de mencionar/publicar.
