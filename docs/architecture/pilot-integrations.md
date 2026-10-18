# Integraciones del piloto

Las fuentes externas amplían la revisión por reglas. Su ausencia, un error o un resultado sin coincidencias no prueban que un enlace sea seguro. El resultado inicial se entrega antes de esperar a Safe Browsing, urlscan o la interpretación del texto. Las tareas comparten el supervisor existente, limitado a 20 análisis simultáneos.

## Activación y configuración

| Variable | Valor predeterminado | Función |
| --- | --- | --- |
| `SAFE_BROWSING_ENABLED` | `false` | Comprobación de reputación con Google |
| `URLSCAN_ENABLED` | `false` | Navegación aislada de enlaces |
| `REPORT_ACTIONS_ENABLED` | `false` | Canales de reporte iniciados por el usuario |
| `IMAGE_INPUT_ENABLED` | `false` | Lectura de una captura con Meta |
| `COMMUNITY_REPORTS_ENABLED` | `false` | Consentimiento y agregados de la comunidad |

Las llaves `GOOGLE_SAFE_BROWSING_API_KEY` y `URLSCAN_API_KEY` se inyectan en ejecución. No se incluyen en Git, imágenes ni parámetros de build. La operación, el almacenamiento cifrado en SSM, los digests y el rollback se documentan en el repositorio privado `devops-agents`. El estado comprobado de la versión publicada corresponde a [implementation.md](implementation.md), no a la existencia de un módulo en el código.

Antes de habilitar una integración se requieren CI en verde, despliegue con digest previo conservado y verificación en ventana privada. La presentación y la descripción de la entrega sólo pueden anunciar como disponible aquello que se haya encendido y comprobado. Si una mejora no supera esos controles, permanece apagada.

Los callbacks de pruebas de estos módulos dependen de `test_helpers`, configurado exclusivamente en `api/config/test.exs` y consultado mediante `Application.compile_env/3`. No se habilitan por variables de entorno de producción.

## A1. Google Safe Browsing

`EverydayTrust.SafeBrowsing` usa `GET /v5/urls:search`. Envía hasta cinco URLs HTTP/HTTPS; elimina credenciales, query y fragmento. El plazo global de 1,5 s incluye caché y servicio. La petición HTTP deja un margen para conservar coincidencias previamente disponibles si otra URL vence.

Una coincidencia añade una señal alta, el dominio registrable, la fecha de comprobación y atribución de Google. Puede elevar el veredicto. Sin coincidencia no añade una señal favorable. Llave ausente, error, respuesta inválida o timeout dejan cobertura no disponible o parcial.

La caché en memoria admite hasta 10.000 hashes SHA-256 de URL, sin conservar URL ni ruta. Sus resultados minimizados contienen dominio registrable, estado y evidencia. El TTL respeta el vencimiento del servicio, con máximo de una hora para resultados negativos y treinta minutos para advertencias positivas. No representa una base histórica ni alimenta una lista propia de Google.

La API es para uso no comercial; antes de monetizar debe evaluarse Web Risk u otra licencia. Las advertencias deben ser condicionales, admitir falsos positivos y negativos y mostrar **Advisory provided by Google**, con enlace al aviso. Esa atribución sólo corresponde a evidencia de Google. Los términos vigentes indican además que Google puede usar y compartir con terceros las URLs y datos enviados mediante SearchUrls. Quitar query y fragmento reduce exposición, pero una ruta o subdominio todavía puede contener información personal. Esta transferencia debe explicarse antes del uso. Fuentes: [API V5](https://developers.google.com/safe-browsing/reference/rest/v5/urls/search), [términos de Google](https://developers.google.com/safe-browsing/terms) y [requisitos de advertencias](https://developers.google.com/safe-browsing/v4/usage-limits).

## A2. urlscan.io

`EverydayTrust.Urlscan` envía la URL sin credenciales, query ni fragmento con visibilidad `unlisted`. Nunca sustituye esa opción por `public`. Exige visibilidad no pública tanto en la aceptación del escaneo como en el resultado. La cuenta debe tener cuota de `unlisted` comprobada antes de habilitarla.

`Unlisted` no significa privado: investigadores y empresas con acceso a urlscan Pro pueden consultar esos escaneos. El plan gratuito publicado incluye este tipo de escaneo, pero las cuotas reales de la cuenta y sus límites por minuto, hora y día siguen siendo la referencia operativa. Un enlace a un informe permite acceder a información almacenada por el proveedor. Fuentes: [visibilidad, API y límites](https://urlscan.io/docs/api/) y [planes](https://urlscan.io/pricing/).

La navegación corre en segundo plano, con plazo total de 30 s. Espera inicialmente 10 s y después consulta en intervalos de 5 s. La cuota propia es de 300 envíos diarios, además de la cuota del proveedor. La caché agrupa por hostname durante seis horas; los fallos se reutilizan durante un minuto. Hasta tres escaneos pueden reservarse simultáneamente. Un resultado de un hostname es una fotografía de esa navegación, no una comprobación de todas sus rutas.

La evidencia muestra destino, fecha, marca detectada y enlace al informe cuando están disponibles. Sólo un veredicto malicioso añade señal alta. Un resultado limpio, pendiente o incompleto no autentica el sitio. No se descarga el DOM ni se incrusta la captura; la CSP no necesita permitir imágenes externas de urlscan.

## Metadatos del destino y persistencia

Los títulos de páginas y marcas devueltos por un tercero son contenido no confiable y pueden incluir datos personales. `EverydayTrust.SourceDisplay` los mantiene para la vista temporal en memoria, por identificador de caso e informe, con validez de una hora y máximo de 1.000 casos; purga vencidos cada minuto. La caché de fotografías del proveedor también es volátil. Reiniciar el proceso puede hacer desaparecer esos textos; no afecta al veredicto persistido.

Antes de guardar resultado y contexto, `SourceDisplay.sanitize/1` elimina título, marcas y campos externos no permitidos. Reduce los hostnames al dominio registrable y sólo acepta informes con URL oficial e identificador UUID válido. La vista temporal puede restaurar título y marcas después de comprobar titular o sesión. El historial guardado conserva el resultado minimizado y no restaura esos campos. Un título o una marca externa nunca se utiliza como instrucción ni se presenta como identidad verificada.

## D1. Reportes iniciados por el usuario

`EverydayTrust.ReportActions` prepara canales únicamente para dominios sospechosos no oficiales. El usuario elige abrir el canal y enviar el reporte. No se envía nada automáticamente.

La plantilla contiene dominio registrable, fecha y posible marca imitada. No incluye mensaje, ruta, query, teléfono ni datos de la víctima. Los canales figuran en `api/priv/catalog/official_channels.json`, con fuente, fecha de verificación y propósito `reporte`. Los enlaces de orientación de un banco no equivalen a una denuncia enviada. Se mantiene la comprobación independiente del catálogo oficial de dominios antes de ofrecer reportar un sitio.

## B1. Lectura de capturas

El navegador reduce la imagen a un máximo de 1.280 px por lado y la vuelve a codificar antes de enviarla. La API acepta exclusivamente un data URL base64 de PNG, JPEG o WebP de hasta 2 MiB; no descarga imágenes de URLs remotas. Comprueba formato declarado, firma, dimensiones y estructura del contenedor. PNG también verifica CRC. Rechaza EXIF, metadatos textuales reconocidos y animaciones PNG/WebP. Esta validación estructural no sustituye un decodificador completo de imágenes.

`EverydayTrustWeb.BodyParser` admite hasta 3 MiB exclusivamente en `POST /api/v1/image-cases` cuando el flag está activo. El resto de rutas mantiene 32 KiB. BFF y Nginx deben aplicar límites equivalentes a esa misma ruta. La ampliación no se aplica a consultas de texto.

`EverydayTrust.ImageInput` envía la captura al modelo autorizado `muse-spark-1.3-contributor` de Meta mediante una parte `image_url` dentro del mensaje `user`, siguiendo el [formato oficial de visión](https://dev.meta.ai/docs/cookbook/vision-input). No se envía la imagen a Google ni a urlscan. El modelo transcribe texto y enlaces visibles en JSON; no abre enlaces. El texto extraído pasa al mismo motor de reglas. Un resultado sin texto legible no debe crear un caso ordinario.

Cada imagen consume dos unidades de consulta y una llamada de la cuota global de IA, que debe reservar el controlador antes del OCR. La interpretación posterior del texto se omite con `skip_ai: true`, evitando una segunda llamada al modelo. El OCR admite hasta 1.800 tokens de salida y 5.000 caracteres extraídos, con plazo global de 6,5 s y sin reintentos. Las consultas de texto mantienen 600 tokens y su límite previo de contexto. El límite de 3 MiB es exclusivo de visión. El coste de entrada de una imagen depende de su resolución, por lo que el límite global cuenta llamadas y no garantiza un importe monetario fijo.

El supervisor `ImageTasks` admite como máximo cuatro OCR simultáneos y las tareas no enlazan su fallo al proceso HTTP. La saturación devuelve un fallo controlado sin llamar al proveedor; la cuota reservada se conserva. La imagen, su base64 y el texto original extraído no se guardan en la base ni se registran en logs. El struct oculta el data URL al inspeccionarse. El aviso de privacidad debe explicar el procesamiento de capturas con Meta durante este piloto. Una captura borrosa, texto mal transcrito o un enlace truncado son causas de incertidumbre, no evidencia de seguridad.

## Comprobación

La API mantiene sólo lectura en `threat_versions` y `threat_indicators`. Para la comunidad recibe ejecución exclusivamente de `public.promote_community_candidate(text)` y `public.cleanup_community_candidates()`, además de los permisos necesarios sobre `community_reports`. Ambas funciones son `SECURITY DEFINER`, pertenecen al principal de migraciones, fijan `search_path = pg_catalog, pg_temp`, cualifican sus tablas y revocan ejecución de `PUBLIC`. No aceptan digest, versión ni estado elegidos por el llamante: sólo escriben la versión fija `community-v1`, inactiva, con indicadores `candidate`, después de contar al menos tres sesiones vigentes. La corroboración independiente se comprueba además en la aplicación. La limpieza sólo elimina candidatos de esa misma versión inactiva. No se concede a la API activar un feed. La [documentación oficial de PostgreSQL](https://www.postgresql.org/docs/17/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY) explica estas restricciones de funciones con permisos del propietario. Los grants operativos exactos se mantienen en `devops-agents`.

Las pruebas de Safe Browsing cubren coincidencia, neutralidad, timeout, llave/flag ausentes, eliminación de query y credenciales, caché, límites de antigüedad y separación de dominios/rutas. Su prueba de integración comprueba que el resultado inicial no espera a Google y que no se persiste texto ni ruta.

Las pruebas de imagen comprueban firmas y MIME, tamaños, dimensiones, metadatos, ausencia de texto, salida JSON, un único request OCR y ausencia de payloads en logs. Las pruebas del parser verifican que el aumento de cuerpo no alcance otras rutas ni la función apagada. `SourceDisplay` comprueba minimización, asociación caso/informe, TTL y capacidad. Las suites usan ejemplos sintéticos y callbacks compilados para pruebas; no necesitan llaves ni llamadas externas reales. La evidencia del despliegue y las pruebas reales de proveedor se registra separadamente al verificar cada flag.

## C. Comunidad y radar

El resultado sólo ofrece compartir un dominio registrable sospechoso cuando el caso está completo, pertenece a la sesión o cuenta y no es una demostración. La casilla comienza desmarcada; no hay escritura hasta confirmar. `community_reports` conserva dominio, posible marca, veredicto, fecha y HMAC de sesión durante treinta días. Un dominio cuenta una sola vez por sesión. No conserva mensajes, rutas, imágenes, números ni IP.

Las cuotas diarias son tres aportes por sesión, sesenta por red y quinientos globales, con reserva transaccional. Tres sesiones distintas y una señal independiente asociada al mismo dominio permiten crear un candidato en una versión comunitaria inactiva. Google debe tener menos de treinta minutos; las demás evidencias externas, menos de un día. La señal comunitaria tiene severidad media y no puede producir alto riesgo por sí sola.

`/radar` expone únicamente cantidades y marcas agregadas de la última semana, sin nombres de dominios. El servidor reconstruye el payload público y distingue un fallo del servicio de un conteo de cero. El acceso al caso y el consentimiento se vuelven a comprobar en la API.

## D2. Exportación del operador

`mix community.export --output /ruta/privada/candidatos.csv` genera un archivo exclusivo con permisos 0600, sin sobrescribir otro archivo. También puede invocarse `EverydayTrust.Community.Export.csv/0` desde el release con el rol autorizado. Incluye candidatos comunitarios con tres sesiones vigentes y actividad durante la última semana: dominio, marca, veredicto, fechas y conteo agregado. Omite seudónimos y mensajes y protege las celdas contra fórmulas de hojas de cálculo. No hay endpoint público ni envío automático a bancos o al Estado.
