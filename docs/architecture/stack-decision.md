# Decisiones de stack pendientes de validación

Estado: propuesta para JP. La implementación permanece detenida hasta validar la definición.

## Base acordada

El producto tendrá una web pública y un backend API separado, con AWS como infraestructura. La cuenta es opcional para consultar y añade historial y mayor uso. El prototipo SvelteKit y el motor de señales existentes son material a conservar o migrar con sus casos de regresión.

## Propuesta de stack

| Capa | Propuesta | Motivo | Estado |
|---|---|---|---|
| Web | SvelteKit, TypeScript y Tailwind | Mantener la base existente y separar la lógica de negocio en la API | Por confirmar |
| API | Elixir y Phoenix | Concurrencia, supervisión y posibilidad de evolución a eventos y dispositivos | Consulta pendiente |
| Identidad | Amazon Cognito User Pool | Gestionar registro, confirmación y recuperación sin contraseñas en la aplicación | Candidato de JP |
| Datos | PostgreSQL gestionado en AWS | Titularidad, evidencia versionada, transacciones e historial | Por confirmar |
| Despliegue API | Release en contenedor sobre ECS Fargate | Ejecutar la BEAM de forma continua y añadir réplicas con límites compartidos | Propuesta de despliegue |
| Descripción de arquitectura | Structurizr DSL y C4; PlantUML para secuencias y datos | Una fuente de arquitectura y diagramas reproducibles | Herramientas solicitadas por JP |
| Modelo de IA | Adaptador de proveedor configurable | Separar las señales y la política de riesgo de la inferencia | Proveedor y modelo pendientes |

Go es la alternativa para la API si se prioriza una base más pequeña de operar o familiaridad del equipo. También ofrece concurrencia; ninguna de las dos opciones elimina límites de bases de datos, servicios externos o costo de IA. Rust se reserva como alternativa si aparece una necesidad concreta que justifique el trabajo adicional.

Elixir no está instalado en el entorno actual; Go y Docker sí están disponibles. Si se elige Phoenix, la implementación necesita fijar versiones compatibles de Elixir, OTP y Phoenix, además de configurar el despliegue. La instalación no forma parte de esta etapa documental.

## Autenticación y límites de responsabilidad

Cognito identifica a la persona. La API decide si esa identidad puede leer, guardar o borrar un caso. Para una API se aceptan access tokens válidos para el User Pool y cliente previstos; comprobar firma no sustituye comprobar emisor, expiración, uso del token y permisos.

La web y los futuros clientes instalables necesitan clientes de autenticación y redirecciones apropiados para su plataforma. El flujo propuesto es Authorization Code con PKCE y una pantalla gestionada. La elección de almacenamiento de tokens en web y de sesiones protegidas se resolverá antes de implementar el acceso.

Propuesta preferida para revisar: backend for frontend (BFF), con sesión web opaca en una cookie `Secure`, `HttpOnly` y `SameSite` acorde al flujo. Los tokens del proveedor quedan en almacenamiento protegido del servidor; la cookie contiene un identificador de sesión, no un conjunto de tokens. El servidor web adjunta el access token a la API, que vuelve a validar identidad y permisos. No se propone guardarlos en `localStorage`.

El BFF requiere ejecución de servidor para la web, protección de origen/CSRF, vencimiento y revocación de sesión, y un diseño de renovación y salida. Debe acordarse antes de elegir frontend estático o SSR. Los futuros clientes nativos usarían su propio flujo y almacenamiento seguro; no heredan una cookie web como mecanismo universal. Cognito y este patrón siguen pendientes de aprobación. Referencias de controles: [OAuth en OWASP](https://cheatsheetseries.owasp.org/cheatsheets/OAuth2_Cheat_Sheet.html), [sesiones en OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) y [validación de tokens de Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-verifying-a-jwt.html).

No se requiere Better Auth si Cognito asume identidad. Better Auth es una biblioteca TypeScript integrada en un servidor, no un servicio gestionado. El borrador anterior no se considera parte del stack objetivo.

## Decisiones que completan el despliegue

Antes de crear recursos se deben revisar región AWS, dominio, ambientes, presupuesto, estrategia de frontend estático o SSR, red privada de datos, salida a fuentes externas, conservación de casos temporales, secretos y recuperación de backups. La arquitectura de despliegue debe mostrar el punto de entrada HTTPS, los límites de confianza y el camino de cada dato sensible.

La propuesta de resultado por etapas requiere acordar cómo continúa el trabajo después de la respuesta inicial y cómo se recuperan fallos o reinicios. Sondeo o streaming se decidirá con ese diseño; no se añade un servicio de colas ni otra tecnología por defecto.

Si se aprueba PostgreSQL, proponerlo también para casos temporales y cuotas en la primera versión: vencimiento comprobado al leer, limpieza programada y actualizaciones atómicas. La limpieza tardía no prolonga acceso. Puede compartir estado entre varias réplicas; Redis o ElastiCache se justificarían por carga y latencia medidas, no por el solo hecho de tener más de una instancia. En C4, estado temporal y datos durables son responsabilidades lógicas que podrían compartir el mismo motor, con políticas y permisos distintos.

La primera versión usará una sola región. Alta concurrencia y alta disponibilidad son propiedades diferentes: varias réplicas requieren estado compartido, despliegues saludables y almacenamiento con una configuración acorde al objetivo de recuperación. No se configura un clúster distribuido sólo por usar Elixir.

## Fuentes técnicas

- [Procesos y aislamiento en Elixir](https://elixir.hexdocs.pm/processes.html).
- [Concurrencia en Go](https://go.dev/doc/effective_go#concurrency).
- [Verificación de tokens Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-verifying-a-jwt.html).
- [PKCE en Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/using-pkce-in-authorization-code.html).
- [Arquitectura de ECS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html).
