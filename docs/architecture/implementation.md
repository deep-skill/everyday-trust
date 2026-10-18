# Implementación del primer corte

Estado: implementación local y despliegue AWS privado, 17-oct-2026. La API es Phoenix 1.8.15 sobre Elixir 1.18.4/OTP 27; la web usa SvelteKit y adapter-node. PostgreSQL local sirve para desarrollo y pruebas; producción conserva RDS como decisión. No se acredita un despliegue AWS por disponer de Dockerfiles.

## Recorrido implementado

`Navegador → SvelteKit/BFF → Phoenix → PostgreSQL`

El BFF expone `/api/v1/*`, valida el origen de las escrituras y limita cuerpo antes de reenviar. Phoenix requiere además una credencial de servicio interna y valida por separado el access token Cognito cuando existe. Los identificadores de visitante son aleatorios y los de red se seudonimizan con HMAC; el cliente no elige al propietario. El endpoint anterior `/api/analyze` responde 410. El motor TypeScript queda sólo como referencia de regresión y no forma parte del camino de producción.

Cada consulta devuelve primero señales tras hasta cinco comprobaciones de red concurrentes y acotadas. Si hay IA aprobada, devuelve estado pendiente y la web consulta la finalización, con revisión monotónica y plazo de ocho segundos. La web espera hasta 12 segundos para cada petición; un reintento de creación puede consumir otra consulta. El guardado es idempotente por cuenta y caso temporal. No se afirma idempotencia de creación.

Las respuestas de IA sólo seleccionan categorías, ids de señales existentes e intenciones de seguimiento. Las explicaciones persistentes y las acciones se producen en servidor con texto revisado. No se conservan párrafos libres del modelo ni se aceptan teléfonos o enlaces de ayuda generados. Una elevación sólo por interpretación llega como máximo a sospechoso; ninguna salida rebaja el piso verificable.

## Cuenta, datos y límites iniciales

En desarrollo, la consulta anónima no necesita Cognito configurado. La imagen de producción exige la configuración completa antes de arrancar. Registro, verificación y recuperación se delegan a la interfaz gestionada de Cognito. El acceso usa Authorization Code, PKCE S256, state de un solo uso y nonce. Web y API validan firma RS256, issuer, clase de token y cliente; la web comprueba también audiencia y nonce del ID token. Los tokens se cifran con AES-256-GCM en `bff.web_sessions`; el navegador recibe una cookie opaca Secure/HttpOnly/SameSite=Lax. La renovación se serializa con un bloqueo de fila y admite rotación de refresh token.

Los intentos de acceso vencen a los diez minutos y la sesión de cuenta tiene siete días de duración máxima. La clave de cifrado es externa a PostgreSQL; su rotación en este corte invalida las sesiones, sin un anillo de claves. Los roles de ejecución de API y BFF se separan de las credenciales de migración en producción. Las pruebas locales usan credenciales exclusivamente de desarrollo.

Valores iniciales de implementación, configurables mediante una revisión posterior de política: cinco consultas anónimas y 25 con cuenta por día UTC; cinco seguimientos por caso, con topes diarios de 10 y 50 respectivamente; 200 análisis por red y 1.000 globales por día; 200 llamadas de IA globales por día. Son límites de operaciones, no un sistema de facturación. El proveedor conserva sus propios límites y presupuesto. El input del modelo se rechaza si mensaje estructurado e instrucciones superan 3.000 bytes UTF-8; máximo de salida de 600 tokens.

Los casos temporales vencen tras una hora, prorrogable por seguimiento hasta cuatro horas desde su creación. El vencimiento se comprueba al leer; una limpieza cada minuto elimina filas vencidas. No se persiste el mensaje original, números, emails ni rutas/query de enlaces. El contexto almacenado sólo contiene la evaluación permitida. Los resúmenes se guardan por elección y tienen lectura/borrado por propietario, con paginación de 20 elementos.

Eliminar la cuenta exige autenticación de los últimos cinco minutos: borra datos de aplicación, bloquea la identidad mediante un hash de control y solicita `DeleteUser` a Cognito. Si el proveedor falla, devuelve `identity_deletion_pending` y permite reintentar la eliminación sin reabrir el acceso a datos. No se comunica éxito del proveedor antes de recibirlo. Las marcas completadas se limpian tras 24 horas; las pendientes requieren reconciliación. RDS tiene backups automáticos de siete días y protección de borrado. La restauración y reconciliación de borrados siguen pendientes de ejercicio.

## Feed y disponibilidad

La ingesta es un comando operativo, fuera del tráfico de consultas. Requiere archivo de hasta 50 MB, SHA-256, fecha de descarga y fecha de publicación. Valida hosts, cantidad mínima, descenso anómalo y publica atómicamente bajo exclusión PostgreSQL. No visita los dominios denunciados. La coincidencia es por host exacto. Un conflicto con el catálogo oficial se marca para revisión y bloquea un resultado sin señales.

Una descarga vence tras 48 horas; una publicación de más de siete días se trata como histórica y su reporte tiene peso medio, con cobertura parcial. Publicaciones de más de 30 días no se admiten al importar. Una ausencia de coincidencia en una fuente histórica o no disponible no habilita el resultado verde.

El snapshot inspeccionado corresponde al commit público `12a20bf8dd2b7e78d9d38fc12b3e5c970f79d1a7`, publicado el 2-oct-2026. Se volvió a descargar el 17-oct por la noche y se comprobó su hash Git y SHA-256 `70c6c2e24e6b3484e7ace27b079723e55937bc1f4cbd98bea38a472ec8e37326`. La descarga reciente no actualiza la antigüedad de publicación. No se anuncia como una lista vigente del día.

## Integraciones y comprobación

Los adaptadores directos de DeepSeek Flash y Muse Spark Contributor están escritos, con validación de salida y fallback por señales. Su activación sigue pendiente de proveedor, credencial y condiciones de datos. No se realizaron llamadas con mensajes reales. La orientación sin IA usa intenciones y acciones cerradas y lo indica en el resultado.

Las regresiones originales del motor de referencia y las pruebas Phoenix se ejecutan sin red externa. La suite de navegador usa la web compilada, PostgreSQL y JWT RSA de un proveedor simulado que fuerza renovación y rotación. No equivale a una prueba de Cognito real ni envía emails/SMS. Sus helpers sólo se cargan expresamente y se excluyen de las imágenes de producción.

CI y publicación manual de imágenes GHCR tienen actions fijadas a commits. La ejecución remota, publicación de paquetes, AWS, Cloudflare y pruebas de restauración se registran por separado en `devops-agents`. Las operaciones de producción están centralizadas allí.

## Correcciones de la tercera revisión

La API retorna las señales tras sus comprobaciones acotadas. Cuando se habilita un proveedor aprobado, la interpretación se ejecuta en una tarea supervisada con máximo 20 tareas simultáneas. El texto minimizado existe sólo en memoria. La consulta queda `in_progress`, revisión 1, y el cliente consulta el resultado hasta `completed`, revisión 2. Tras ocho segundos, una lectura o la limpieza periódica finaliza un trabajo perdido con IA no disponible. No hay reintentos de llamadas facturables ni resultados verdes si la interpretación queda incompleta. Un reinicio puede perder la interpretación, conservando la evaluación por señales.

Las reservas de cuotas de sesión, red y servicio se hacen en una transacción corta y se revierten juntas. Los turnos se reservan atómicamente y la llamada externa ocurre fuera de la transacción. El proxy obtiene la IP desde el único salto Nginx confiable: `ADDRESS_HEADER=x-forwarded-for`, `XFF_DEPTH=1`. Nginx reemplaza ese encabezado desde Cloudflare, y EC2 carece de entradas públicas.

RDAP utiliza el bootstrap IANA versionado en `api/priv/catalog/rdap-bootstrap.json` y consulta directamente el registro HTTPS correspondiente. No visita la URL de la persona ni sigue redirecciones generales. La falta de soporte o respuesta se presenta como cobertura parcial.

`daily_metrics` conserva conteos agregados por día UTC y distingue consultas y demostraciones. Registra finalizaciones, consultas adicionales en una sesión o cuenta, opiniones y errores de solicitudes recibidas por el controlador de creación. No mide personas únicas ni todos los errores de la infraestructura. Las opiniones agregadas sobreviven a la limpieza del caso temporal. Los ejemplos de la interfaz se reconocen en servidor y quedan separados de la tracción. `GET /api/v1/stats` expone sólo estos agregados.

El contenedor web exige configuración de identidad, origen HTTPS, cifrado y CA de RDS antes de arrancar. Phoenix exige la misma identidad y bloquea Meta Contributor en producción hasta resolver sus condiciones de datos. Un fallo transitorio de renovación conserva la sesión y devuelve indisponibilidad, sin convertirla silenciosamente en anónima.

AWS está aprovisionado y el despliegue privado pasó por GitHub Actions con OIDC y SSM. Cognito usa Essentials, rotación de refresh tokens y managed login v2. El primer stack vacío falló por incompatibilidad entre Lite y rotación, se verificó que no tenía usuarios y se eliminó antes de recrearlo. La entrada por Tunnel requiere un token Cloudflare con permisos de escritura, pendiente. Este estado no acredita todavía un despliegue público ni el recorrido OIDC completo en navegador contra AWS. Doce comprobaciones privadas con dos identidades Cognito reales y RDS verificaron JWT, aislamiento, guardado, feedback, borrado de consultas y eliminación de ambos usuarios en Cognito, sin emails/SMS.

Verificación local de este corte: 67 pruebas Phoenix, 45 pruebas Node, 29 comprobaciones de navegador y chequeo Svelte sin errores ni advertencias.

## Verificación AWS privada

GitHub Actions desplegó imágenes amd64 fijadas por digest a través de OIDC y SSM. RDS privado verifica TLS/CA y separa roles de API, BFF y migración. RDS y Cognito tienen protección de borrado activa. Las credenciales temporales de bootstrap y GHCR se eliminaron al completar la operación.

El catálogo de 391.548 hosts quedó cargado en RDS con el SHA y fechas descritos arriba. Sigue siendo histórico y de cobertura parcial. El primer importador tardó varios minutos en el host nuevo sin créditos; se permitió un burst temporal acotado y se restauró `standard` al terminar. Un prefiltro IP evita enviar hostnames DNS al parser de direcciones y limita la longitud; el barrido local de 392.178 filas tomó 0,40 segundos. Ese tiempo no mide una ingesta completa en RDS.

La cadena privada Nginx → BFF → API → RDS responde 200/201, aplica CSP y permite crear un intento OIDC con PKCE. Managed login acepta `prompt=login` y `max_age=0`, sin acreditar todavía reautenticación interactiva. Las pruebas sintéticas no se suman a consultas reales en las métricas.

Pendientes de integración: permiso Cloudflare para crear Tunnel y DNS; recorrido OIDC completo en navegador público; elección, credencial y condiciones de datos del proveedor de IA. La IA sigue deshabilitada. Restauración de backups pendiente de ejercicio. No se anuncia una URL pública lista.
