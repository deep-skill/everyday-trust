# WhatsApp con Zavu: evaluación del canal

Revisión: 17-oct-2026. Estado: recomendación para JP, sin adoptar el canal, conectar cuentas ni enviar mensajes. La web y las capacidades de cuenta/historial siguen en el alcance acordado.

## Encaje con el producto

La hipótesis es reducir fricción: reenviar un mensaje sospechoso al contacto de ¿Es estafa? y recibir veredicto, motivo y siguiente paso dentro de WhatsApp. El backend mantiene las mismas señales, fuentes y política de riesgo que la web. El canal puede facilitar pruebas de uso y retorno; todavía no tenemos evidencia propia de esa mejora.

El bot sólo recibe lo que la persona le envía. No obtiene acceso general a sus chats ni vigila su dispositivo. Ofrecer WhatsApp tampoco demuestra un diferencial frente a Scamio: la utilidad debe estar en la evidencia y la orientación del caso peruano, según la comparación ya documentada.

## Qué permite Zavu

La documentación distingue alojar agentes en Zavu de llamar su API desde un backend propio. Se propone sólo mensajería; Phoenix conserva la lógica y las llamadas directas al modelo elegido. No requiere cambiar Elixir por TypeScript ni mover el motor de análisis. [Introducción de Zavu](https://docs.zavu.dev/introduction).

Flujo propuesto: `WhatsApp → Zavu → webhook de Phoenix → motor compartido → Zavu → WhatsApp`.

La autenticación documenta que las llaves de prueba entregan mensajes reales desde un número compartido y sólo a teléfonos del equipo. No son un simulador ni prueban que cualquier asistente al evento pueda usar el bot. Falta comprobar recepción, enrutamiento al proyecto y respuesta de extremo a extremo en esa modalidad. [Modo de prueba](https://docs.zavu.dev/authentication).

Para una línea propia, Zavu documenta conexión mediante Meta Business Signup y verificación del número. No se reutiliza la línea de ventas de Deep Skill por esta evaluación. La coexistencia aparece de forma inconsistente entre marketing y guía de conexión; no basar la entrega en ella sin comprobarla. [Conectar WhatsApp](https://docs.zavu.dev/guides/whatsapp/connect-whatsapp).

## Costos y datos

El pricing principal consultado publica Free con 2.000 mensajes compartidos entre canales y Pro a US$20/mes. Meta factura WhatsApp por separado a la cuenta Business; números y consumo de modelos requieren su propio cálculo. Una landing secundaria aún anuncia otros precios, por lo que se toma el pricing principal como referencia, sujeto al dashboard. [Precios Zavu](https://www.zavu.dev/es/pricing).

Meta publica cobro por mensaje entregado y respuestas de servicio gratuitas dentro de la ventana de 24 horas abierta por el usuario. No equivale a que toda operación del bot sea gratis; revisar categoría, mercado y condiciones vigentes al habilitarlo. [Precios de WhatsApp](https://business.whatsapp.com/products/platform-pricing).

El contexto local del evento registra tres meses Pro como beneficio, pendiente de comprobar activación y cobertura. No se publica ni canjea un código en esta revisión.

Zavu declara retención de contenido durante 90 días por defecto, configurable por proyecto. Procesará el original antes de que Phoenix pueda minimizarlo. Nuestra política de una hora de contexto temporal no borra automáticamente la copia del proveedor: acordar retención, eliminación y tratamiento antes de recibir mensajes reales. [Datos y eliminación](https://www.zavu.dev/es/data-deletion).

La versión de los términos WhatsApp recuperada por el buscador, fechada 6-mar-2026, restringe ofrecer IA como función principal y el uso de datos Business para entrenar modelos generales. La apertura directa redirigió a login: confirmar la versión aplicable y el encaje del verificador con Zavu/Meta antes de lanzarlo. Ser especializado no acredita autorización automática. No usar Muse Contributor con contenido real de este canal bajo una modalidad que permita entrenamiento general. [Términos de la plataforma](https://www.whatsapp.com/legal/business-solution-terms).

## Integración si se aprueba

El proveedor documenta eventos entrantes y reintentos. El adaptador debe validar remitente/proyecto, deduplicar el evento y aceptar trabajo durable antes de responder 2xx; no esperar al LLM dentro del webhook ni perder el trabajo tras acusar recepción. [Webhooks](https://docs.zavu.dev/guides/receiving-messages/webhooks).

Usar la firma v2 sobre timestamp y cuerpo original, comparación constante y tolerancia temporal; comprobar la versión configurada, sin copiar ejemplos antiguos de v1. [Seguridad del webhook](https://docs.zavu.dev/guides/receiving-messages/security).

La arquitectura actual encamina rutas públicas al BFF. Añadir el canal exige diseñar una ruta específica servidor a servidor hacia Phoenix, autenticada por firma, sin requerir cookie Cognito ni exponer el resto de la API. Su configuración operativa, permisos, secretos y recurso real se registrarían en `devops-agents`; no se modificó Nginx ni el C4 como si ya existiera.

Mantener contexto mínimo con vencimiento, cuotas y presupuesto compartidos. El identificador del contacto no crea una cuenta Cognito ni vincula automáticamente un historial web. Separar el dato necesario para contestar de lo permitido en historial/logs. Desactivar fallback automático a SMS/email y cualquier respuesta que convierta el enlace sospechoso en una vista previa o llamada a abrirlo.

## Recomendación

Proponer una prueba acotada después de una consulta web completa: texto/enlace sintético, entrada y respuesta reales en teléfono autorizado, resultado coherente y entrega sin duplicados. Treinta a cuarenta y cinco minutos es un límite de inversión propuesto, no una estimación garantizada de onboarding.

Para abrirlo al público se necesitan línea utilizable, privacidad acordada, encaje de políticas confirmado y prueba de extremo a extremo. Si falta algo, conservarlo como canal en evaluación. El webhook compartido tiene valor técnico cuando funciona; no se supone una puntuación adicional por usar un patrocinador. No recortar cuenta e historial para añadir este canal sin acordarlo con JP.
