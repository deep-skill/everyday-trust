# Notas personales en casos guardados — capturas de verificación

Capturas reales de la app local (SvelteKit + Phoenix + PostgreSQL), 1280×800, con dos sustituciones de prueba:

- **Atomic Memory simulado:** `tests/fixtures/atomic-memory-fixture.mjs`, un servidor HTTP local en `127.0.0.1` con la forma documentada de las rutas. **No es el servicio real de Atomic Memory.**
- **Identidad simulada:** `tests/e2e/oidc.mjs` (Cognito falso del E2E existente). Usuarios ficticios, mensajes sintéticos y dominios `.example`.

| Archivo | Contenido |
| --- | --- |
| `screenshot.png` | Consulta nueva parecida: el veredicto no cambia y debajo aparece «Antes guardaste algo parecido» con la nota del usuario |
| `demo.webm` / `demo.gif` | Flujo de unos 22 s: revisar → guardar → añadir nota (el número se oculta) → consulta parecida con recuerdo → corregir → olvidar |
