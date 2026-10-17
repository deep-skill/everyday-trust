# Negocio y alcance del verificador de mensajes

Estado: borrador para revisión de JP, 17 de octubre de 2026. Nombre de trabajo: ¿Es estafa?

El producto ayuda a personas en Perú a evaluar mensajes sospechosos y decidir su siguiente acción. El primer segmento son clientes de bancos y billeteras que reciben SMS o WhatsApp que aparentan venir de su entidad. La consulta funciona sin registro; una cuenta gratuita añade historial privado, continuidad de casos y una cuota mayor.

## Problema y momento de uso

La persona recibe una solicitud de validar datos, abrir un enlace o transferir dinero. Necesita una respuesta comprensible antes de actuar, o ayuda si ya interactuó. El remitente y la apariencia del mensaje no bastan para comprobar su origen.

Trabajo del usuario: «Cuando un mensaje parece venir de mi banco y me pide hacer algo, quiero entender las señales de riesgo y confirmar por un canal que yo pueda reconocer».

La hipótesis es que reunir señales verificables, contexto peruano y pasos concretos reduce el esfuerzo frente a buscar por separado o consultar un chat general. La demanda, el uso repetido y la disposición a pagar se validarán con personas; los referentes extranjeros no prueban esos resultados en Perú.

Como contexto, la suma del CSV 2025 del MPFN arroja 29.342 registros de fraude informático y 10.559 de suplantación de identidad. Son delitos denunciados, sin limitarse a bancos o mensajes y sin equivaler a víctimas únicas. La [nota de evidencia](evidence.md) registra fuente, método, checksum y limitaciones; estos conteos no prueban demanda ni impacto del producto.

Como complemento, ENAPRES estima un 3,6% de victimización informática en población urbana de 15 años o más, con datos preliminares del boletín febrero a julio de 2026. La referencia de victimización es de doce meses; alcance y comparación están en [evidencia](evidence.md#personas-estimación-enapres-del-inei).

## Promesa y límites

Promesa: «Revisa un mensaje sospechoso y recibe ayuda para decidir qué hacer».

El resultado expresa riesgo y lo sustenta con evidencia disponible. Un dominio oficial no autentica al remitente, y la ausencia de coincidencias en listas no demuestra seguridad. El servicio no confirma titularidad de cuentas, recupera dinero ni garantiza que un mensaje sea legítimo.

## Usuarios y beneficios

| Persona | Necesidad | Beneficio de la primera versión |
|---|---|---|
| Visitante | Resolver una duda inmediata | Revisar texto o enlaces sin cuenta y entender el resultado |
| Persona con cuenta | Volver a un caso y consultar con más frecuencia | Guardar resultados voluntariamente, retomar el resumen y borrar casos |
| Operador del producto | Mantener confiabilidad y costos | Versionar fuentes, observar fallos y controlar consumo sin registrar mensajes |

La cuenta no exige indicar banco, DNI, teléfono, datos de tarjeta ni credenciales bancarias. Las preferencias sobre entidades financieras serán opcionales si luego se validan alertas personalizadas.

## Alcance de la primera entrega

| ID | Capacidad | Criterio de aceptación de negocio |
|---|---|---|
| B01 | Consulta abierta | En ventana privada, una persona pega un mensaje y recibe resultado sin registrarse |
| B02 | Evidencias | Resultado breve y acción visible; cuatro veredictos, con evidencia ampliable y cobertura separada. Las señales disponibles se muestran antes de esperar la explicación del modelo |
| B03 | Seguimiento del caso | La persona puede pedir explicación e indicar si hizo clic, compartió datos o pagó; la ayuda adapta los pasos sin pedir los datos compartidos |
| B04 | Cuenta gratuita | Registro, acceso, salida y recuperación tienen un flujo documentado y mensajes claros |
| B05 | Historial voluntario | Guardar requiere una acción explícita; la persona ve y borra sus propios casos |
| B06 | Más uso con cuenta | La cuota se aplica en servidor y se explica antes de bloquear; los valores siguen pendientes de validación |
| B07 | Privacidad | Se minimizan datos antes de enviar al modelo o conservar contexto; el historial guarda sólo resumen saneado y evidencias, sin mensaje original, números ni rutas de enlaces |
| B08 | Uso demostrable | Eventos sin contenido distinguen análisis completados, errores y retorno; feedback opcional mide utilidad percibida, sin asumir que prueba acierto |

Texto y enlaces son el primer formato. Se propone conservar la extracción de números que ya existe dentro del texto, con sus límites: prefijo o país no identifican titular ni demuestran fraude. El formulario dedicado a números y la comparación de remitentes con un catálogo verificado requieren validar alcance; no se presentan como funciones ya completas.

Capturas requieren definir redacción de datos, límites de archivo y procesamiento de imágenes antes de incorporarlas. Extensión, aplicaciones instalables, protección familiar, radar público y venta de inteligencia a marcas quedan como evolución; no son condiciones para que funcione la consulta.

## Conversación e historial

La conversación está vinculada a un caso. Primero se entrega el resultado; después se ofrece «Por qué», «Ya abrí el enlace», «Ya compartí datos», «Ya pagué» y una pregunta libre relacionada. Es opcional indicar qué ocurrió; nunca se pide el valor de una clave, código o tarjeta. Una consulta ajena al caso invita a crear otro análisis.

El resultado distingue alto riesgo, sospechoso, sin señales detectadas e indeterminado. La cobertura y el estado de procesamiento son dimensiones separadas. Mientras quedan comprobaciones pendientes, no se presenta una conclusión de ausencia de señales como garantía; una advertencia ya sustentada sí puede mostrarse de inmediato.

La IA puede advertir hasta sospechoso al interpretar un texto sin enlaces ni señales de reglas. Esa advertencia se identifica como interpretación; alto riesgo exige sustento adicional. Los patrones del catálogo, como un supuesto familiar con número nuevo o una transferencia por error, orientan la ayuda sin convertirse en hechos probados ni ampliar automáticamente el primer segmento.

El original se usa durante la petición para extraer señales; el contexto y los turnos conservados temporalmente pasan por minimización. Guardar un caso conserva el resultado, el resumen saneado, las evidencias permitidas y la versión de análisis. Retomar recupera ese resumen; si hace falta el mensaje original, la persona lo vuelve a proporcionar. Guardar conversaciones completas sería una decisión futura separada.

Un fallo del proveedor de IA mantiene disponible el análisis por señales y comunica la cobertura limitada. La interpretación del modelo no puede convertir en seguro un resultado con evidencia verificable de alto riesgo.

La entrada advierte que se omitan datos personales. La detección automática de posibles DNI, tarjetas o códigos no garantiza eliminarlos todos; debe permitir corregir la entrada y reducir el contexto enviado. Antes de integrar IA se verifican conservación, entrenamiento y subprocesadores del proveedor. No se publica una promesa de «sin entrenamiento» sin respaldo contractual y configuración comprobada.

## Modelo de ingresos por validar

La consulta básica y la cuenta parten gratuitas, con límites sostenibles. La hipótesis principal de pago es protección continua para una persona o su familia, cuando existan capacidades preventivas útiles y medibles. No se ha fijado un precio.

La orientación y los pasos de respuesta permanecen disponibles después del resultado. Un veredicto de alto riesgo no dispara presión comercial ni una compra para recibir ayuda.

Una línea futura posible es inteligencia de campañas para marcas. Requiere datos agregados con procedencia, control de falsos positivos y demanda comercial; no implica vender mensajes ni historiales de personas.

El costo variable por caso incluye inferencia, consultas de reputación y almacenamiento. Antes de aumentar las cuotas se medirá costo por análisis completado, con caché y límites por operación. Crear cuentas adicionales no debe eliminar el presupuesto global de consumo.

## Validación con usuarios

1. Pedir un ejemplo reciente o usar uno sintético, sin recopilar información de terceros.
2. Observar cómo decide hoy y qué información le falta.
3. Probar mensajes legítimos y fraudulentos; comprobar si entiende el resultado y su siguiente paso.
4. Ofrecer guardar el resultado y observar si el beneficio justifica crear cuenta.
5. Medir retorno real y preguntar qué protección preventiva instalaría y por qué.

| Indicador | Definición | Interpretación |
|---|---|---|
| Análisis completados | Casos que alcanzan evaluación final sobre solicitudes iniciadas, registrando su cobertura | Funcionamiento del flujo; las actualizaciones no cuentan como nuevos análisis |
| Tiempo hasta primera ayuda y evaluación final | Medir ambos desde el envío; incluir cobertura y fallos | Espera y valor de la entrega por etapas |
| Comprensión | Persona explica el riesgo y su siguiente paso con sus palabras | Utilidad, evaluada en prueba |
| Guardado y registro | Casos guardados y cuentas creadas tras consultar | Interés en continuidad |
| Retorno | Navegador o cuenta con una segunda visita en otra sesión | Uso repetido, no número de personas únicas |
| Calidad | Falsos positivos y falsos negativos por tipo de caso | Confiabilidad en un conjunto etiquetado |
| Utilidad percibida | Respuesta opcional «Me ayudó / No me ayudó» tras el resultado | Orienta mejoras de experiencia; no sustituye la medición de calidad |

## Referentes y evidencia

[Scamio](https://www.bitdefender.com/en-us/consumer/scamio) ya ofrece revisión conversacional gratuita y solicita cuenta. [Guardio](https://guard.io/) muestra una evolución comercial hacia protección continua. El diferencial a comprobar es acceso inmediato, señales pertinentes para Perú y ayuda concreta ante el caso.

La [revisión de Scamio](scamio-review.md) documenta qué está sustentado, qué falta probar y qué ajustes propone. No afirmamos exclusividad en Perú ni superioridad de precisión, idioma o cobertura sin comparación.

La [evidencia nacional](evidence.md) se presenta con periodo, fuente y método; la definición de usuario no depende de afirmar un puesto mundial en phishing.

## Decisiones para validar

- Foco inicial en suplantación de bancos y billeteras, con consulta abierta y cuenta opcional.
- Guardado de resúmenes saneados, sin conversación completa por defecto.
- Beneficios de cuenta y cuotas iniciales.
- Nombre y dirección visual propuestos en el brief de marca.
