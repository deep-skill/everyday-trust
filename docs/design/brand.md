# Identidad de la web y nombre del proyecto público

Estado: JP confirmó **Everyday Trust** como nombre del proyecto público y `deep-skill/everyday-trust` para el repo el 17-oct-2026. **¿Es estafa?** y **«Revisa antes de responder»** son el nombre y la bajada de la web. JP aprobó provisionalmente la identidad visual 0.1: logo, favicon, paleta y tipografía. Después, JP pidió implementar. La primera UI funcional usa esta propuesta como referencia; la identidad sigue aprobada provisionalmente. No acredita registro de marca ni disponibilidad de dominio.

## Promesa y voz

Ayudar a una persona a hacer una pausa, entender las señales de un mensaje y elegir su siguiente paso. La identidad transmite calma, criterio y cercanía, sin apariencia de banco ni promesas de protección absoluta.

- Nombre visible: **¿Es estafa?**, con ambos signos de interrogación y sin cambiar la pregunta por una afirmación.
- Bajada: **Revisa antes de responder.**
- Descriptor: **Verificador de mensajes con contexto peruano.** Describe la dirección del producto; sólo anunciar comprobaciones realmente implementadas.
- Ejemplo de voz: «Hay señales que merecen una pausa. Vamos paso a paso».
- Evitar «100 % seguro», «te protegemos de todo», culpar a quien respondió o usar un puntaje como probabilidad de fraude.

**Everyday Trust**, traducido como «confianza cotidiana», nombra el proyecto y su posible evolución hacia prevención digital. **¿Es estafa?** identifica la experiencia concreta de revisar mensajes. La identidad visual actual corresponde a esa web. La carpeta local conserva `hack-the-andes-seguridad` para mantener las rutas de las sesiones abiertas. El dominio propio sigue pendiente de elección y compra.

## Exploración del nombre general

Se evaluaron nombres de dos o tres palabras inglesas con significado traducible. JP eligió Everyday Trust; las otras opciones quedan como registro de la exploración, sin afirmar disponibilidad de marca ni dominio.

| Candidato | Significado | Slug propuesto | Encaje |
|---|---|---|---|
| Everyday Trust | Confianza cotidiana | `everyday-trust` | Elegido por JP; amplio y cercano a la vida diaria |
| Trust in Context | Confianza en contexto | `trust-in-context` | Describe decisiones con señales, evidencia y límites |
| Digital Trust Kit | Kit de confianza digital | `digital-trust-kit` | Nombre técnico amplio para el repositorio y componentes futuros |
| Pause and Check | Pausa y verifica | `pause-and-check` | Cercano al tono y la bajada de la web |

Destino público aprobado: [deep-skill/everyday-trust](https://github.com/deep-skill/everyday-trust). La publicación comprende `main`, con documentación y prototipo; la rama experimental Better Auth/D1 permanece local.

La búsqueda inicial encontró coincidencias claras para alternativas descartadas: [Trust Signals en Futurae](https://www.futurae.com/trust-signals/) ya identifica un producto antifraude y [Signal Harbor](https://signal-harbor.com/) identifica un proveedor tecnológico. La búsqueda de los candidatos no es una comprobación registral ni garantiza dominios disponibles.

## Identidad y propuesta de pantallas

- [Lámina de identidad](proposal/brand.html): logo, variantes, tamaños, paleta, tipografía y etiquetas de riesgo.
- [Pantalla de consulta](proposal/index.html): propuesta HTML/CSS con dos recorridos sintéticos, resultado, señales ampliables, orientación contextual y beneficio de cuenta.
- [Identidad en PNG](rendered/brand-board.png), [consulta de escritorio](rendered/consultation-desktop.png) y [consulta móvil](rendered/consultation-mobile.png).
- [Resultado de escritorio](rendered/case-desktop.png), [resultado móvil](rendered/case-mobile.png) y [ejemplo bancario móvil](rendered/case-bank-mobile.png).

Los HTML pueden abrirse directamente en un navegador; no requieren instalar paquetes ni conectar la API. Los enlaces Markdown del repo sirven para inspeccionar fuentes; los PNG permiten revisar el diseño sin ejecutar nada. La app de `src/` ya integra una primera versión funcional, con resultados del backend. Estos HTML conservan su propósito de revisión visual y ejemplos ficticios.

## Logo y archivos

Una burbuja de consulta contiene un signo de interrogación. Representa la pregunta y el espacio para aclararla; evita un escudo, un check de aprobación o un sello que sugiera respaldo bancario. Las dos barras de pausa son un motivo secundario discreto, no otro logo.

| Archivo | Uso |
|---|---|
| [logo.svg](assets/logo.svg) | Logotipo horizontal en color sobre fondo claro |
| [mark.svg](assets/mark.svg) | Símbolo azul, sin texto |
| [logo-monochrome.svg](assets/logo-monochrome.svg) | Una tinta oscura; los huecos del símbolo son transparentes |
| [mark-inverse.svg](assets/mark-inverse.svg) | Símbolo blanco para fondo azul u oscuro |
| [favicon.svg](assets/favicon.svg) | Variante SVG para la pestaña; mostrada a 16 px en la lámina |
| [tokens.css](assets/tokens.css) | Colores, tipografías, radios y estados de la propuesta |

Recomendación inicial: símbolo a partir de 24 px en UI y favicon a 16 px; logotipo horizontal a partir de 145 px de ancho. Dejar alrededor al menos un cuarto de la altura del símbolo. No deformar, girar, añadir sombras al símbolo ni colorearlo según el resultado. El riesgo pertenece a la tarjeta, no a la marca.

El símbolo usa trazos vectoriales propios. El texto de los logotipos SVG sigue editable con Arial/Helvetica/sans-serif y puede variar si esas fuentes no están disponibles. Antes de una entrega final de imprenta conviene convertir el texto a contornos y comprobar el tamaño de reproducción; no se presenta este paquete como un manual final de imprenta.

## Paleta y tipografía

Fondos claros, texto oscuro, acento azul y tarjetas de evidencia legibles. Rojo, ámbar y verde se reservan para estados, siempre con etiqueta e icono. «Sin señales detectadas» expresa cobertura, no seguridad garantizada.

| Token | Color | Uso |
|---|---|---|
| background | `#F8FAFC` | Fondo general |
| surface | `#FFFFFF` | Entrada, resultados y paneles |
| text | `#0F172A` | Contenido principal |
| text-muted | `#475569` | Ayudas y metadatos |
| primary | `#1D4ED8` | Acción principal y enlaces |
| risk-high | `#B91C1C` | Alto riesgo |
| risk-medium | `#92400E` | Sospechoso |
| risk-low | `#166534` | Sin señales detectadas |
| border | `#CBD5E1` | Separación visual, no texto |

La UI usa sans del sistema, sin cargar fuentes externas. Base de 16 px, controles de texto a 16 px en móvil, títulos breves y monoespaciada para información técnica. Los metadatos secundarios usan tamaños menores y no contienen la acción principal.

Los seis colores de texto y estado del brief superan 6:1 sobre blanco y `#F8FAFC`. Esto no acredita accesibilidad completa. El foco visible, las etiquetas, el teclado, el contenido largo y las combinaciones finales deben comprobarse también en la implementación.

## Componentes y estados representados

La propuesta incluye entrada vacía y con ejemplo, botón deshabilitado, advertencia de datos personales, resultado con acción prioritaria, evidencia expandible, categorías de interacción opcionales, ayuda posterior y beneficio de registro. La lámina muestra los cuatro veredictos; la consulta interactiva ilustra dos de ellos.

La interpretación aislada del ejemplo familiar se limita a «Sospechoso» y muestra su atribución. El ejemplo de banco usa una marca ficticia y un dominio `.example`. Ninguno realiza análisis real, consulta fuentes o llama a un modelo. Editar texto libre no devuelve un veredicto inventado: explica el límite y permite elegir un ejemplo. No se guardan mensajes ni se crean cuentas.

La propuesta permite varias categorías de interacción; «No interactué» se excluye de las acciones ya realizadas. Los botones de cuenta muestran los beneficios y el límite de la vista previa. El modal puede cerrarse con Escape. El contenido se coloca como texto, sin interpretar HTML recibido.

## Validación y siguiente integración

Revisión en Chrome Dev, 17-oct-2026: 37 comprobaciones de la propuesta, con anchos de 320, 390, 768, 1024 y 1440 px. Sin desbordamiento horizontal, errores de JavaScript ni peticiones HTTP salientes. Se comprobaron ejemplos, entrada vacía/libre, atribución de interpretación, evidencia expandible, interacción múltiple, reinicio y modal con cierre por Escape. Se inspeccionaron visualmente las capturas de identidad, consulta y resultado. Esto no es una auditoría completa de accesibilidad ni una prueba del backend.

La identidad visual queda aprobada por ahora, según la revisión de JP del 17-oct-2026. Esa aprobación no cierra las pantallas ni los recorridos de UX. Sigue pendiente revisar la propuesta de consulta y después integrar tokens/componentes en SvelteKit con datos reales, estados de espera/fallo/cuota y autenticación Cognito.

El nombre y la bajada ya no bloquean el primer corte. El diseño de cuenta/historial conserva el alcance acordado; este prototipo visual no sustituye su implementación ni las pruebas B01 a B08.
