# Revisión de seguridad y abuso, 18-oct-2026

Revisión de código y del análisis de Claude. La protección depende de capas con límites concretos; no se afirma inmunidad frente a DDoS o inyección de instrucciones. Estado y evidencia de despliegue se registran en implementación y en el runbook de devops-agents.

| Capa | Control implementado | Alcance y límite |
|---|---|---|
| Cloudflare | Hostname proxied y Tunnel con conexión saliente | El proveedor documenta DDoS automático. No equivale a un límite monetario del modelo ni a disponibilidad garantizada |
| Origen AWS | EC2 sin reglas de entrada, sin SSH público; RDS privado | La IP de salida de EC2 puede ser pública, pero no ofrece puertos de aplicación. No basar la defensa en que la IP sea secreta |
| Nginx |3r/s por IP y ráfaga15;30r/s globales y ráfaga60;10 conexiones concurrentes por IP; cuerpo32KiB, plazos acotados | Incluye portada y páginas dinámicas; assets compilados quedan fuera. Puede devolver429 ante tráfico legítimo intenso, incluido NAT compartido |
| BFF | Allowlist de rutas, origen estricto en escrituras, cuerpo32KiB, timeout12s | Reconstruye identidad/IP de la cadena de confianza. Nunca acepta un owner elegido por el navegador |
| Identidad | Cognito, Code/PKCE S256, state y nonce, JWT firmado y claims, cookies opacas HttpOnly/Secure y tokens cifrados en servidor | Separación por propietario; borrado requiere identificación reciente. El login en español usa lang=es |
| Cuotas PostgreSQL |5 consultas anónimas o25 por cuenta/día UTC;200 por red y1.000 globales;5 seguimientos/caso y10 o50 por sujeto/día | Atómicas y compartidas entre procesos/réplicas. Borrar cookies puede renovar sujeto anónimo, pero no evita red/global. NAT de sede comparte el límite200 |
| Modelo |200 llamadas globales/día, compartidas entre análisis y preguntas;65.536 bytes de entrada con instrucciones;600 tokens de salida; conexión1s y respuesta6s; sin reintentos | Es un límite de llamadas, no un presupuesto monetario configurado en Meta. La cuota diaria puede ser agotada por abuso y dejar al resto sin IA; las reglas continúan |
| Concurrencia | Hasta20 tareas supervisadas de análisis; caso inicial y finalización con plazo8s | No es una promesa de20 llamadas globales incluyendo toda pregunta síncrona. Nginx y cuotas también acotan los seguimientos |
| Datos | Original fuera de PostgreSQL/logs; resultados saneados; roles de BD separados y TLS verificado | El piloto autorizado sí envía texto completo a Contributor. Las reseñas son datos voluntarios separados y sus comentarios no van al modelo |
| URLs hostiles | DNS/IP públicos fijados, HEAD acotado, redirecciones revalidadas, bloqueo de redes privadas/metadata/IPv6 y downgrade | No ejecuta HTML/JavaScript ni demuestra ausencia de malware. La raíz puede diferir de la ruta del mensaje |

## Inyección de instrucciones y preguntas fuera de alcance

El mensaje, enlaces y evidencia son datos no confiables. Las instrucciones del sistema los separan, pero el prompt por sí solo no es una frontera de seguridad. Contributor no recibe herramientas, acceso a secretos, SQL ni capacidad de ejecutar acciones. La aplicación sólo consume veredicto, tipo e ids permitidos, verifica su forma y no muestra prosa del modelo. Ignora campos adicionales. Los contactos, consejos y explicaciones visibles se eligen en código.

Una salida no puede rebajar el veredicto de reglas. Una elevación sólo interpretativa llega como máximo a sospechoso; referencias inventadas o JSON inválido producen cobertura incompleta. Una inyección aún puede confundir la clasificación o causar abstención: esos controles limitan consecuencias, no prueban detección perfecta.

Las preguntas de seguimiento que no tienen relación reconocible con el caso se resuelven localmente y no consumen llamada de IA. El filtro de palabras no es una defensa infalible: se puede mezclar un término del negocio con una petición genérica. Incluso entonces el contrato de salida admite sólo intenciones cerradas y la respuesta visible sigue siendo texto revisado, por lo que no se ofrece un chat general. Las categorías de clic, datos o pago siempre se orientan localmente.

## Tracción y reseñas

Una visita se cuenta por sesión de navegador/día, con la cookie necesaria de hasta4h; no identifica personas únicas. Hasta1.000 eventos de visita por red y5.000 globales al día. Un bot puede alterar el conteo; las cifras no son una auditoría de humanos ni de impacto.

Las consultas y valoraciones excluyen casos marcados demo. Las reseñas requieren un caso completado y su sesión o titular; una valoración por caso, máximo3 por sujeto,60 por red y500 globales al día. Reintentos no duplican el agregado. Un comentario sólo lo recibe el equipo, no se publica automáticamente ni se envía a IA. Se retiene30d y desaparece al borrar la cuenta vinculada. Retirar el comentario no habilita otra valoración del mismo caso. Los agregados históricos sobreviven sin texto ni identidad.

## Límites operativos pendientes

No se ha instalado Turnstile ni verificado un presupuesto duro/prepago en Meta. Tampoco se afirma que exista una regla WAF personalizada para la ruta del proyecto, un ensayo de carga o un ejercicio de restauración. Evitar cambiar reglas compartidas de toda deepskill.space para resolver un problema de esta web. El runbook conserva el interruptor reversible de IA; deshabilitar y desplegar mantiene las reglas y comprobaciones locales.

Fuentes revisadas el18-oct: [Cloudflare DDoS y capas](https://developers.cloudflare.com/waf/feature-interoperability/), [conjunto WAF gratuito](https://developers.cloudflare.com/waf/get-started/), [OWASP: prevención de prompt injection](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html), [Cognito managed login y localización](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-managed-login.html). El estado de configuración propio se fundamenta en código y comprobaciones, no en la disponibilidad comercial de una función.


## Corrección encontrada durante el OIDC de navegador

El acceso, guardado y lectura de historial funcionaron, pero el formulario nativo de Salir fue rechazado: no-referrer puede producir Origin:null en un POST de formulario. Se cambia la política a same-origin, que conserva el origen en los formularios propios y omite referrer hacia otros sitios. No se desactiva la comprobación CSRF ni se acepta Origin:null. La repetición de navegador posterior al despliegue debe verificar la salida. Referencia: [Mozilla, Referrer-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Referrer-Policy).
