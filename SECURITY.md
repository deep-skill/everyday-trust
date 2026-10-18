# Seguridad

## Reportar una vulnerabilidad

El reporte privado de vulnerabilidades de GitHub no está habilitado actualmente. Para coordinar un canal privado, [abre una solicitud de contacto](https://github.com/deep-skill/everyday-trust/issues/new) dirigida al mantenedor, sin publicar la vulnerabilidad, pasos de explotación, mensajes reales ni credenciales. Comparte la evidencia únicamente cuando se haya acordado ese canal.

Un reporte útil identifica la versión o URL afectada, el comportamiento esperado y observado, y pasos reproducibles con datos ficticios. No incluyas datos personales de terceros. El proyecto está en piloto de hackathon y no ofrece un plazo garantizado de respuesta ni un programa de recompensas.

## Controles implementados

- Cloudflare Tunnel y EC2 sin puertos entrantes; RDS privado y conexiones TLS verificadas.
- Límites de tráfico y cuerpo en Nginx/BFF, y cuotas atómicas por sujeto, red y globales en PostgreSQL.
- Cognito con OIDC/PKCE, cookies opacas HttpOnly/Secure, tokens cifrados en servidor y autorización por propietario.
- Destinos restringidos a IP públicas, DNS/IP fijados y redirecciones revalidadas. No se ejecuta contenido del sitio.
- IA sin herramientas, salida estructurada validada, piso de reglas y tope global de llamadas. El mensaje recibido se trata como datos no confiables.
- Mensaje original fuera del historial y los logs; comentarios de reseñas privados, sin envío al modelo y con retención limitada.

El detalle, las cuotas y su alcance están en la [revisión de seguridad](docs/architecture/security-review.md).

## Secretos

No publiques llaves, contraseñas, tokens, archivos `.env`/`.dev.vars`, datos de clientes ni mensajes con información de terceros. Usa archivos locales ignorados y el almacén operativo de secretos; producción obtiene parámetros cifrados por referencia. Las credenciales no deben entrar en imágenes, argumentos de build ni logs. Si se expone un secreto, revócalo o rótalo y coordina su retirada; borrarlo del último commit no lo elimina del historial.

## Límites conocidos

Los controles reducen riesgo, pero no garantizan protección frente a DDoS, prompt injection o agotamiento de cuotas. No hay Turnstile ni presupuesto monetario duro del proveedor verificados. El piloto envía mensaje y contexto completos a Contributor; no se promete anonimización antes del modelo.

Las cabeceras de protección de las rutas dinámicas no cubren por igual todos los recursos estáticos; equipararlas queda pendiente. El feed disponible es histórico. Un EC2 y RDS Single-AZ no ofrecen alta disponibilidad; la restauración de backups y el alta/recuperación con correo real siguen pendientes de prueba. La herramienta orienta y no certifica que un mensaje sea seguro.
