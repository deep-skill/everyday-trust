# Arquitectura lógica del servicio

Estado al 18-oct-2026: aplicación desplegada en AWS. SvelteKit y BFF Node, API Elixir/Phoenix, RDS PostgreSQL privado, Cognito y EC2 con Docker Compose/Nginx/Cloudflare Tunnel. GitHub Actions, GHCR, OIDC y SSM entregan imágenes inmutables. El estado comprobado y los límites están en [implementación](implementation.md).

## Responsabilidades

La web presenta la consulta, evidencias, ayuda, cuenta e historial. El BFF protege la sesión y reenvía sólo rutas permitidas. La API valida identidad y titularidad, calcula señales, conserva el piso de riesgo y aplica cuotas compartidas en PostgreSQL. Las fuentes se actualizan mediante un comando operativo fuera de las solicitudes de usuarios.

Cognito gestiona identidad. El modelo interpreta el mensaje y los resultados de comprobación; no recibe herramientas ni decide permisos, cuotas o acciones bancarias. La API valida su salida y selecciona explicaciones y consejos revisados.

## Flujo de análisis

1. El BFF valida origen y cuerpo; Phoenix exige credencial interna y valida la identidad de cuenta cuando existe. La API aplica las cuotas con actualización atómica.
2. Extrae señales del mensaje, compara dominios oficiales y alertas conocidas, y realiza comprobaciones externas acotadas. El original no entra a logs ni a PostgreSQL.
3. Entrega señales y cobertura inicial. Si hay interpretación pendiente, la web consulta el mismo caso hasta obtener el resultado final. Una advertencia sustentada no espera a la IA.
4. Durante el piloto, Contributor recibe el mensaje original completo y todo el resultado del análisis, incluidos enlaces y números presentes en el texto. Las preguntas se envían completas con el resultado disponible. No se minimiza esa entrada al modelo; la restricción se aplica al contexto persistido y al historial.
5. La salida estructurada se valida. No puede rebajar el riesgo de reglas; una elevación sólo por interpretación llega como máximo a sospechoso. Un fallo conserva señales y declara cobertura incompleta.

La comprobación de un sitio usa HEAD de la raíz, omite ruta y parámetros y fija DNS/IP públicos, con redirecciones revalidadas. Los acortadores permitidos conservan su resolución acotada. No se analiza HTML ni se ejecuta JavaScript. Ver [sitios y Contributor](implementation.md#comprobación-de-sitios-y-contributor-corte-local).

## Datos, continuidad y métricas

Casos y cuotas comparten RDS con vencimiento comprobado al leer y limpieza de filas vencidas. El guardado es voluntario e idempotente por cuenta/caso. El historial conserva un resumen saneado y evidencia permitida, sin mensaje original, números ni rutas de enlaces. Retomar un caso guardado recupera ese resumen, no el original.

Las sesiones opacas del BFF usan esquema y rol propios; los tokens Cognito se cifran en servidor. Toda lectura y escritura de casos vuelve a comprobar titularidad. La renovación se serializa y la eliminación de cuenta exige autenticación reciente.

Las métricas agregan visitas aproximadas, consultas y valoraciones, separando demostraciones. Los comentarios de reseñas son privados, no van al modelo y tienen retención limitada. Estas cifras no prueban personas únicas ni fraudes evitados.

## Vistas C4

[workspace.dsl](workspace.dsl) es la fuente lógica de contexto, contenedores, componentes y despliegue. Las responsabilidades temporales y durables comparten un mismo PostgreSQL físico. Los contenedores C4 son unidades lógicas, no necesariamente contenedores Docker independientes.

Vistas exportadas: [contexto](../diagrams/rendered/structurizr-Context.svg), [contenedores](../diagrams/rendered/structurizr-Containers.svg), [componentes](../diagrams/rendered/structurizr-ApiComponents.svg) y [AWS](../diagrams/rendered/structurizr-AwsDeployment.svg). Estas exportaciones corresponden al corte anterior a métricas y reseñas; no se regeneraron para el cierre y pueden conservar descripciones anteriores del piloto. La fuente DSL y esta documentación describen el estado actual.

## Entrega y operación

El recorrido público es `Cloudflare → Tunnel → Nginx → SvelteKit/BFF → Phoenix → RDS`. EC2 no tiene puertos entrantes; RDS es privado y verifica TLS. [AWS y entrega continua](aws-deployment.md) detalla el despliegue; la operación, secretos por referencia, inventarios y restauración se documentan en `devops-agents`.

Un EC2 y RDS Single-AZ no ofrecen alta disponibilidad. Las cuotas y sesiones ya comparten estado, pero varias réplicas requieren dimensionar pools y concurrencia total, comprobar recuperación y respetar los límites del proveedor. No se promete cero downtime.

## Validación

La [evaluación reproducible](evaluation.md) ejecuta 24 fixtures sintéticos con reglas offline desde ExUnit/CI y produce un [informe versionado](evaluation-report.json). No evalúa calidad del modelo, prevalencia real, latencia externa ni costo. Las pruebas Phoenix cubren reglas, fallos, cuotas, identidad, titularidad, borrado e ingesta; las web cubren el cifrado de sesiones.

El acceso Cognito, guardado y lectura de historial se comprobaron en navegador privado. El logout corregido pasó por HTTP; su repetición visual final, alta/recuperación con correo real y restauración de backups siguen pendientes. [Contrato de IA](ai-interpretation.md) y [controles de seguridad](security-review.md) delimitan lo que se afirma.
