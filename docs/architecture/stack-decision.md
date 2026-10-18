# Stack confirmado y decisiones de despliegue

Estado: stack confirmado por JP el 17-oct-2026. La aprobación no acredita implementación, recursos creados ni compra de dominio.

## Decisión vigente

| Capa | Decisión | Estado |
|---|---|---|
| Web | SvelteKit, TypeScript y Tailwind, conservando la base existente | Confirmado |
| API | Elixir y Phoenix, aplicación modular con contrato HTTP separado | Confirmado |
| Identidad | Amazon Cognito User Pool | Confirmado |
| Datos | PostgreSQL en Amazon RDS | Confirmado; reemplaza la opción temporal de BD en EC2 |
| Sesión web | BFF, cookie opaca HttpOnly y tokens del proveedor en servidor | Confirmado |
| IA | API directa; candidatos `muse-spark-1.3-contributor` y `deepseek-flash` | Modalidad y candidatos indicados por JP; falta selección y condiciones de datos |
| Ejecución inicial | EC2 con Docker Compose: Nginx, web/BFF, Phoenix y cloudflared | Propuesta documentada; no desplegada |
| Entrega | GitHub Actions, imágenes en GHCR y despliegue mediante AWS SSM con OIDC | Propuesta tras la consulta de JP; no implementada |
| Modelado | Structurizr DSL/C4 y PlantUML | Herramientas solicitadas por JP |

Go y Rust dejan de ser alternativas pendientes para este primer corte. Better Auth/D1 permanece aislado en `wip/paused-cloudflare-auth`; Cognito asume identidad. Elixir no está instalado en el host actual; Docker permite fijar Elixir/OTP/Phoenix sin una instalación global, pero aún se deben seleccionar y probar versiones compatibles.

## Identidad y sesión

Cognito identifica a la persona. Phoenix valida access tokens del emisor y cliente previstos: firma con claves vigentes, expiración, `token_use`, `client_id` y permisos. La API comprueba titularidad en cada operación; el cliente nunca elige `owner_id`.

La web usa Authorization Code con PKCE, `state`, `nonce` y redirecciones exactas. El BFF conserva los tokens cifrados en un esquema PostgreSQL propio y emite una cookie opaca `Secure`, `HttpOnly` y `SameSite` apropiado al flujo. Comprueba origen/CSRF, vencimiento y revocación; coordina renovación y salida. Los tokens no van a `localStorage`. La API vuelve a validar identidad y permisos aunque reciba la llamada del BFF.

La consulta anónima conserva su sesión de caso y sus cuotas; Cognito no se convierte en requisito para la primera consulta. Futuros clientes instalables usarán clientes de identidad y almacenamiento seguro propios. La cookie web no es su mecanismo universal de autenticación.

Referencias: [PKCE en Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/using-pkce-in-authorization-code.html), [validación de tokens Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-verifying-a-jwt.html), [OAuth](https://cheatsheetseries.owasp.org/cheatsheets/OAuth2_Cheat_Sheet.html) y [sesiones en OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html).

## Almacenamiento y continuidad

Un RDS PostgreSQL físico aloja historial, catálogos, estado temporal y cuotas. Las sesiones del BFF tienen esquema y rol exclusivos. Las cuotas se actualizan atómicamente; el vencimiento se comprueba al leer y la limpieza no extiende acceso. La clave que cifra tokens se mantiene fuera de la BD.

No se requiere Redis para añadir una réplica. La propuesta de análisis por etapas debe concretar ejecución, plazos y recuperación tras reinicios; ningún caso queda indefinidamente en curso. Los pools de conexiones y los límites externos se calculan para el total de procesos y réplicas.

## Infraestructura y documentación operativa

La [propuesta AWS](aws-deployment.md) define red, Nginx, Docker, RDS privado, identidad, CI/CD, costos y recuperación. EC2/Compose sustituye la propuesta inicial ECS Fargate para el primer corte; RDS se mantiene por decisión posterior de JP. Separar aplicaciones y datos facilita una evolución a varias instancias o ECS sin exigirlo para la demo.

La fuente operativa es `../devops-agents/docs/hack-the-andes-seguridad.md`, según la instrucción de JP. Allí se registran recursos reales, región/cuenta, permisos, cambios, secretos por referencia, despliegues, incidentes y pruebas de recuperación. Los inventarios AWS y Cloudflare se actualizan al crear o cambiar recursos. El repo público conserva arquitectura y diagramas reproducibles, sin datos privados de otras cargas de Deep Skill.

Faltan tamaño y presupuesto definitivos, dominio, permisos de automatización, versiones, retenciones y pruebas de funcionamiento. Un EC2 y un RDS Single-AZ no constituyen alta disponibilidad. Concurrencia de Elixir no sustituye redundancia ni recuperación.
