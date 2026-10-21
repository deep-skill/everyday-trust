<script lang="ts">
  import type { PageProps } from './$types';
  let { data }: PageProps = $props();
</script>

<svelte:head><title>Uso de datos y límites · ¿Es estafa?</title></svelte:head>
<main class="mx-auto max-w-2xl px-6 py-12 leading-8">
  <a class="brand mb-10" href="/"><img src="/mark.svg" width="36" height="36" alt="" /><span>¿Es estafa?</span></a>
  <h1 class="mb-6 text-3xl font-semibold">Tu consulta y tus datos</h1>
  <p class="mb-5">Puedes revisar un mensaje sin crear una cuenta. Omite claves, códigos, DNI, nombres y comprobantes antes de enviarlo.</p>
  <h2 class="mt-8 mb-3 text-xl font-semibold">Qué conservamos</h2>
  <p>El servidor procesa el texto para extraer señales y no lo guarda como mensaje original. El caso temporal contiene el resultado y vence tras una hora sin seguimiento, con un máximo de cuatro horas. Las cookies necesarias permiten reconocer tu sesión; no contienen los tokens de acceso ni el texto recibido.</p>
  <p class="mt-4">Con una cuenta, sólo guardamos los resúmenes que eliges conservar. No incluyen números, correos ni rutas o parámetros de enlaces. Puedes borrar cada consulta desde tu historial y solicitar la eliminación de tu cuenta desde «Cuenta», con identificación reciente.</p>
  <p class="mt-4">Contamos visitas aproximadas por sesión de navegador y consultas completadas, separadas de los ejemplos de demostración. No usamos huellas digitales ni presentamos esas visitas como personas únicas. Las valoraciones son voluntarias. Sus comentarios sólo los recibe el equipo, no se publican ni se envían al modelo y se eliminan de la base activa a los 30 días. Puedes retirar el comentario mientras tu consulta temporal esté disponible; los comentarios vinculados a una cuenta se borran también al eliminarla. Los conteos históricos y promedios agregados permanecen sin texto ni identidad.</p>
  <h2 class="mt-8 mb-3 text-xl font-semibold">Fuentes y proveedores</h2>
  <p>La verificación usa reglas, dominios oficiales y alertas conocidas de sitios engañosos. Consultamos el registro del dominio y hacemos una petición a la raíz del sitio para comprobar si responde, sin enviar la ruta ni los parámetros del mensaje. Si su raíz redirige a otro sitio, comprobamos también ese destino. Sólo ciertos acortadores permitidos reciben el enlace completo para conocer su destino. Esta comprobación directa no ejecuta la página ni descarga archivos. Las comprobaciones pueden ser visibles para el sitio y sus proveedores.</p>
  {#if data.features.safe_browsing || data.features.urlscan}
    <p class="mt-4">Las comprobaciones adicionales con {data.features.safe_browsing && data.features.urlscan ? 'Google Safe Browsing y urlscan' : data.features.safe_browsing ? 'Google Safe Browsing' : 'urlscan'} reciben la dirección del enlace, incluida su ruta, después de quitar los parámetros, el fragmento y las credenciales que pudiera contener. No reciben el mensaje original ni la captura. Una ausencia de coincidencias no demuestra seguridad.</p>
  {/if}
  {#if data.features.urlscan}
    <p class="mt-4">urlscan abre la dirección en su entorno aislado y puede observar contenido de la página, redirecciones y capturas. Solicitamos visibilidad «unlisted»: el informe no se incluye en las búsquedas públicas, pero no es privado y puede ser visible para usuarios de urlscan Pro. Sus datos se conservan según las condiciones de urlscan. <a href="https://urlscan.io/docs/api/" target="_blank" rel="noopener noreferrer">Información de urlscan</a>.</p>
  {/if}
  <p class="mt-4">Usamos AWS para la aplicación, la base y la identidad, y Cloudflare procesa el tráfico de entrada. Durante el piloto de hackathon, disponible en esta web pública, Muse Spark Contributor recibe el mensaje completo y los resultados de las comprobaciones, incluidos señales, dominios y cobertura. Las preguntas de seguimiento también se envían completas junto al resultado disponible. Meta puede usar esas entradas y respuestas para entrenar sus modelos. El mensaje original no se incorpora a nuestro historial. Antes de una difusión general revisaremos esta modalidad. <a href="https://dev.meta.ai/legal/terms-of-service" target="_blank" rel="noreferrer">Condiciones de Meta</a>.</p>
  {#if data.features.image_input}
    <p class="mt-4">Si subes una captura, el navegador reduce sus dimensiones a un máximo de 1280 píxeles y la vuelve a codificar para retirar los metadatos. Aceptamos JPEG, PNG o WebP de hasta 2 MB. Meta recibe la imagen mediante Muse Spark Contributor para extraer el texto visible; también puede usarla para entrenamiento. La captura y su texto extraído no se guardan en nuestra base, historial ni registros. La consulta conserva únicamente el resultado de las comprobaciones. Cada captura consume dos consultas y una llamada de la cuota global de IA.</p>
  {/if}
  {#if data.features.report_actions}
    <p class="mt-4">Los canales de reporte se abren únicamente cuando eliges usarlos. El enlace de Google prellena sólo la raíz del dominio; el texto que puedes copiar contiene el dominio, la fecha y la posible marca imitada. No enviamos reportes automáticamente. El formulario del Estado o el banco puede pedirte información directamente, según sus propias condiciones.</p>
  {/if}
  {#if data.features.community_reports}
    <h2 class="mt-8 mb-3 text-xl font-semibold">Aportes a la comunidad</h2>
    <p>Compartir un dominio es voluntario y requiere marcar la casilla y pulsar el botón de confirmación. Guardamos sólo el dominio registrable, la posible marca imitada, el resultado, la fecha y un identificador seudónimo de sesión para contar aportes distintos. No añadimos el mensaje, la captura, números, rutas ni la IP. Estos aportes se eliminan de la base activa a los 30 días; los agregados sin identidad pueden permanecer.</p>
    <p class="mt-4">Se necesitan tres sesiones distintas y una señal independiente para generar una alerta candidata. Un aporte aislado no confirma fraude. El radar público muestra cantidades y marcas; no publica los dominios sin revisión manual. El operador puede exportar candidatos para revisarlos y, por su cuenta, reportarlos a entidades oficiales.</p>
  {/if}
  {#if data.features.case_notes}
    <h2 class="mt-8 mb-3 text-xl font-semibold">Notas personales</h2>
    <p>Con una cuenta puedes añadir una nota breve a un resultado guardado. La nota se guarda en Atomic Memory junto al resumen fijo del resultado y los códigos de las señales, bajo un identificador seudónimo de tu cuenta. Antes de enviarla ocultamos números, correos y enlaces. No enviamos el mensaje original, la captura ni los enlaces revisados.</p>
    <p class="mt-4">Al revisar un mensaje nuevo, te mostramos hasta dos notas tuyas de casos parecidos. Son sólo un recordatorio: no cambian el resultado, las señales ni los pasos recomendados. Puedes corregir u olvidar cada nota desde tu historial. Al borrar un resultado guardado o tu cuenta, primero borramos sus notas; si alguna no se puede borrar, no eliminamos nada más y te pedimos reintentar.</p>
  {/if}
  <h2 class="mt-8 mb-3 text-xl font-semibold">Límites de la orientación</h2>
  <p>No autenticamos al remitente ni identificamos al titular de un número. Un dominio oficial, una ausencia de reportes o un resultado sin señales no garantizan seguridad. Un reporte histórico conserva su fecha y no confirma el estado actual de un sitio. Verifica por un canal independiente antes de enviar dinero o datos.</p>
  <p class="mt-4">Los registros operativos se limitan a datos de funcionamiento, como estado, duración e identificadores de petición, sin el mensaje ni tokens. Los contadores y cuotas no demuestran usuarios únicos ni fraude confirmado. La base activa elimina las consultas al borrarlas. Los respaldos automáticos de RDS se conservan siete días; el borrado no modifica retroactivamente esas copias, que vencen según su retención. Una restauración exige reconciliar los borrados antes de reabrir el servicio.</p>
  <a class="primary-button mt-10 no-underline" href="/">Volver al verificador →</a>
</main>
