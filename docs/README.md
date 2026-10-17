# Definición de producto y arquitectura

Los documentos describen el producto objetivo y su diseño previo a la implementación. La validación funcional y visual de los documentos no sustituye la aprobación de JP para cerrar decisiones o empezar a programar.

## Orden de lectura

1. [Negocio y alcance](business/product.md): usuario, promesa, beneficios de cuenta, límites, ingresos por validar y criterios B01 a B08.
2. [Mapa del flujo de valor](business/value-stream.md): situación actual supuesta, flujo objetivo y medición de trabajo y espera.
3. [Experiencia de usuario](design/experience.md): navegación, recorridos, estados, accesibilidad y pruebas de uso.
4. [Nombre e identidad visual](design/brand.md): candidatos, tono, paleta, logo y componentes propuestos.
5. [Modelo lógico de datos](architecture/data-model.md): titularidad, evidencias, datos temporales, conservación y borrado.
6. [Arquitectura lógica](architecture/overview.md): responsabilidades, análisis, continuidad y condiciones para varias réplicas.
7. [Modelo C4 en Structurizr](architecture/workspace.dsl): contexto, contenedores y componentes, con tecnologías pendientes explícitas.
8. [Decisiones de stack](architecture/stack-decision.md): propuesta, alternativa Go y decisiones pendientes para AWS.
9. [Contrato funcional de la API](architecture/api-contract.md): recursos, acceso, estados y errores, sin presentarlos como implementados.
10. [Revisión antes de programar](review.md): trazabilidad B01 a B08, comprobaciones y decisiones pendientes.

Documentos que completan las brechas de la [revisión de Claude](review-claude.md): [fuentes e ingesta](architecture/source-ingestion.md), [contrato del intérprete](architecture/ai-interpretation.md), [evaluación](architecture/evaluation.md) y [evidencia del problema](business/evidence.md). La respuesta punto por punto está en [revisión](review.md#respuesta-a-la-revisión-de-claude).

La [revisión de Scamio](business/scamio-review.md) reúne evidencia, límites y ajustes propuestos de negocio, privacidad y experiencia. No cambia las decisiones de stack pendientes.

Los wireframes están disponibles como [consulta](diagrams/rendered/wireframe-consultation.svg), [revisión en curso](diagrams/rendered/wireframe-analysis.svg), [historial](diagrams/rendered/wireframe-history.svg) y [beneficio de registro](diagrams/rendered/wireframe-signup.svg). Sus fuentes están en [wireframes.puml](diagrams/wireframes.puml).

## Decisiones y revisión

| Tema | Estado |
|---|---|
| Infraestructura AWS | Indicada por JP |
| Backend como API separada | Indicado por JP |
| Negocio, flujos y alcance | Borrador para revisión |
| Lenguaje de la API y autenticación | Consulta pendiente: propuesta Phoenix, PostgreSQL y Cognito |
| Modelo físico y despliegue | Se completan sobre el stack acordado |
| C4 lógico | Borrador modelado y validado con Structurizr |
| Nombre y marca | Propuestas, sin selección definitiva |
| Implementación | En espera de validación de la definición |

## Entrega del evento y arquitectura objetivo

La columna de entrega es una propuesta de compromiso, pendiente de validar y ejecutar. No hay una URL pública verificada ni resultados de operación en esta revisión; documentar un componente no significa tenerlo funcionando.

| Entrega propuesta para el evento | Arquitectura objetivo | Fuera del primer corte o pendiente, con motivo |
|---|---|---|
| P0: consulta anónima de texto/enlaces, evidencias y siguiente acción | Web pública y API separada sobre AWS | Lenguaje, servicios y despliegue por acordar; el prototipo Cloudflare no acredita despliegue AWS |
| P0: explicación y seguimiento acotado, con piso de reglas | Intérprete con contrato, presupuesto y evaluación | Proveedor/modelo por elegir; sospecha sólo por IA identificada como interpretación |
| P1: cuenta, mayor uso, guardado voluntario e historial, solicitados por JP | Identidad gestionada y acceso por propietario | Cognito, BFF y almacenamiento siguen como propuestas; P1 es orden de ejecución, no exclusión del evento |
| P0: dominios oficiales con procedencia y un feed integrado y probado | Catálogos versionados e ingesta de varias fuentes | Phishing.Database propuesto como primer feed, con licencia contrastada; falta validar versión, frescura e integración. SBS y canales no se anuncian integrados antes de hacerlo |
| P0: evaluación mínima reproducible y métricas sin texto | Evaluador local/CI e informe ampliado P2 | Calidad y costos aún no medidos; el informe completo puede ampliarse después, las comprobaciones mínimas no se difieren |
| P0: conservar extracción de números en texto y sus límites | Canales oficiales curados y entrada dedicada P2 | Comparación de remitentes por validar; sin búsqueda de titulares |
| P0: resultado breve y evidencia ampliable | Experiencia móvil accesible y continuidad de casos | Capturas/PDF/QR, reportes, compartir, extensión y apps diferidos para contener alcance y tratamiento de datos |

Después de aprobar la definición, el primer hito de implementación será una consulta completa en el entorno acordado y su comprobación en ventana privada. La vista de despliegue se completa al cerrar el stack. La entrega del evento vence el 18 de octubre a las 09:00; no se compromete una capacidad por figurar en este objetivo.

### Orden de ejecución y recortes propuestos

| Prioridad | Contenido | Criterio |
|---|---|---|
| P0 | Consulta completa, catálogos mínimos, primer feed, IA acotada, acciones y evaluación mínima con fallos de dependencias | Validar que funciona en el entorno acordado y en ventana privada; sin esto no hay base útil |
| P1 | Cuenta, mayor cuota, guardado, historial privado y borrado | Parte de la entrega solicitada por JP, construida sobre P0; verificar aislamiento y continuidad |
| P2 | Informe ampliado de 50 a 100 casos, comparación de varios modelos, entrada dedicada de teléfonos y fuentes adicionales | Primer candidato a recortar si afecta el cierre; sólo se anuncia lo implementado y medido |

Esta propuesta no elimina cuenta e historial ni aplaza las pruebas mínimas para habilitar IA. Si P0 y P1 corren riesgo, se reduce primero P2; cualquier cambio del alcance solicitado se revisa con JP. La amplitud del catálogo de patrones no obliga a implementar protocolos detallados de todas las modalidades en el evento.

## Cómo mantener los diagramas

PlantUML representa el VSM, los wireframes, el modelo de datos y las secuencias. Structurizr DSL será la fuente única de los diagramas C4 de contexto, contenedores y componentes; sus exportaciones se generarán desde el modelo.

Para renderizar los diagramas PlantUML con una instalación local:

```sh
plantuml -tsvg -o rendered docs/diagrams/value-stream.puml docs/diagrams/wireframes.puml docs/diagrams/data-model.puml docs/diagrams/source-catalog.puml docs/diagrams/sequences.puml
```

Con el binario oficial de Structurizr 2026.09.19 y Java 21:

```sh
java -jar /ruta/a/structurizr-2026.09.19.war validate -workspace docs/architecture/workspace.dsl
java -jar /ruta/a/structurizr-2026.09.19.war export -workspace docs/architecture/workspace.dsl -format plantuml -output docs/diagrams/c4
plantuml -tsvg -o ../rendered docs/diagrams/c4/*.puml
```

El binario se obtiene de la [distribución oficial](https://docs.structurizr.com/binaries) y no se incorpora al repositorio. Las exportaciones `docs/diagrams/c4/` se regeneran; no se editan manualmente.

C4 es el modelo de vistas, Structurizr describe la arquitectura y PlantUML permite exportar y versionar las representaciones. No son tres arquitecturas distintas. Referencias: [C4](https://c4model.com/diagrams), [Structurizr DSL](https://docs.structurizr.com/dsl), [PlantUML](https://plantuml.com/).
