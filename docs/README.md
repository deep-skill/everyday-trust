# Everyday Trust: producto y arquitectura

Los documentos describen el producto objetivo. La [implementación del primer corte](architecture/implementation.md) registra lo construido y las diferencias frente a las propuestas. JP confirmó el stack el 17-oct-2026: SvelteKit, API Elixir/Phoenix, PostgreSQL, Cognito y BFF. JP eligió RDS PostgreSQL después de considerar alojarlo en EC2. Se conserva la distinción entre diseño, implementación y verificación en vivo.

## Orden de lectura

1. [Negocio y alcance](business/product.md): usuario, promesa, beneficios de cuenta, límites, ingresos por validar y criterios B01 a B08.
2. [Mapa del flujo de valor](business/value-stream.md): situación actual supuesta, flujo objetivo y medición de trabajo y espera.
3. [Experiencia de usuario](design/experience.md): navegación, recorridos, estados, accesibilidad y pruebas de uso.
4. [Nombre e identidad visual](design/brand.md): nombre y bajada elegidos, logo, favicon y propuesta de UI para móvil/escritorio.
5. [Modelo lógico de datos](architecture/data-model.md): titularidad, evidencias, datos temporales, conservación y borrado.
6. [Arquitectura lógica](architecture/overview.md): responsabilidades, análisis, continuidad y condiciones para varias réplicas.
7. [Modelo C4 en Structurizr](architecture/workspace.dsl): contexto, contenedores y componentes, con tecnologías confirmadas y una vista de despliegue propuesta.
8. [Decisiones de stack](architecture/stack-decision.md): decisiones confirmadas y ajustes de infraestructura inicial en EC2.
9. [Contrato funcional de la API](architecture/api-contract.md): recursos, acceso, estados y errores, sin presentarlos como implementados.
10. [Despliegue AWS, Docker y CI/CD](architecture/aws-deployment.md): EC2/Compose/Nginx, RDS privado, Cloudflare y Actions/GHCR.
11. [Revisión antes de programar](review.md): trazabilidad B01 a B08, comprobaciones y decisiones pendientes.

Documentos que completan las brechas de la [revisión de Claude](review-claude.md): [fuentes e ingesta](architecture/source-ingestion.md), [contrato del intérprete](architecture/ai-interpretation.md), [evaluación](architecture/evaluation.md) y [evidencia del problema](business/evidence.md). La respuesta punto por punto está en [revisión](review.md#respuesta-a-la-revisión-de-claude).

La [revisión de Scamio](business/scamio-review.md) reúne evidencia, límites y ajustes propuestos de negocio, privacidad y experiencia. No cambia el stack confirmado.

La [evaluación de WhatsApp con Zavu](business/whatsapp-zavu.md) propone un canal adicional con el mismo backend. Documenta sandbox, onboarding, costos y tratamiento de datos; no cambia el alcance ni acredita una integración aprobada.

Los wireframes están disponibles como [consulta](diagrams/rendered/wireframe-consultation.svg), [revisión en curso](diagrams/rendered/wireframe-analysis.svg), [historial](diagrams/rendered/wireframe-history.svg) y [beneficio de registro](diagrams/rendered/wireframe-signup.svg). Sus fuentes están en [wireframes.puml](diagrams/wireframes.puml).

## Decisiones y revisión

| Tema | Estado |
|---|---|
| Infraestructura AWS | Indicada por JP |
| Backend como API separada | Indicado por JP |
| Negocio, flujos y alcance | Borrador para revisión |
| Web, API, datos y autenticación | Confirmados: SvelteKit, Elixir/Phoenix, PostgreSQL, Cognito y BFF con cookie opaca |
| Modelo físico y despliegue | EC2 + Compose + Nginx, RDS privado y Cognito desplegados; Actions/GHCR/OIDC/SSM y Tunnel público verificados |
| C4 lógico | Borrador modelado y validado con Structurizr |
| Nombre y marca | Everyday Trust confirmado para el proyecto y `deep-skill/everyday-trust` para el repo. Web: ¿Es estafa? + «Revisa antes de responder»; identidad visual aprobada provisionalmente; pantallas para revisión |
| IA | Contributor con mensaje completo y evidencia, activo en la URL pública del piloto de hackathon por autorización expresa de JP. Verificado con ejemplos ficticios; revisar modelo/modalidad antes de la difusión general |
| Implementación | API, BFF, UI, sesiones e historial implementados. Consulta pública verificada y 12 comprobaciones de identidad/propiedad/borrado con Cognito real; OIDC completo en navegador AWS pendiente |

## Entrega del evento y arquitectura objetivo

La web está disponible en [verifica.deepskill.space](https://verifica.deepskill.space). La tabla conserva el alcance de entrega; la [implementación](architecture/implementation.md) registra las comprobaciones realizadas y lo que sigue pendiente.

| Entrega propuesta para el evento | Arquitectura objetivo | Fuera del primer corte o pendiente, con motivo |
|---|---|---|
| P0: consulta anónima de texto/enlaces, evidencias y siguiente acción | Web pública y API separada sobre AWS | Desplegado y consulta anónima pública comprobada |
| P0: explicación y seguimiento acotado, con piso de reglas | Intérprete con contrato, presupuesto y evaluación | Contributor desplegado con mensaje completo, señales, dominios y cobertura; salida estructurada, fallback y piso de reglas. Comparación de calidad/costo pendiente |
| P1: cuenta, mayor uso, guardado voluntario e historial, solicitados por JP | Identidad gestionada y acceso por propietario | Implementado y probado con Cognito/RDS reales; recorrido OIDC completo de navegador pendiente |
| P0: dominios oficiales con procedencia y un feed integrado y probado | Catálogos versionados e ingesta de varias fuentes | 391.548 hosts de Phishing.Database cargados en RDS; snapshot histórico del 2-oct y cobertura parcial. SBS y canales no se anuncian integrados |
| P0: evaluación mínima reproducible y métricas sin texto | Evaluador local/CI e informe ampliado P2 | Calidad y costos aún no medidos; el informe completo puede ampliarse después, las comprobaciones mínimas no se difieren |
| P0: conservar extracción de números en texto y sus límites | Canales oficiales curados y entrada dedicada P2 | Comparación de remitentes por validar; sin búsqueda de titulares |
| P0: resultado breve y evidencia ampliable | Experiencia móvil accesible y continuidad de casos | Capturas/PDF/QR, reportes, compartir, extensión y apps diferidos para contener alcance y tratamiento de datos |

La consulta pública está comprobada en Chrome, incluida una ventana privada; sigue pendiente el recorrido completo de cuenta contra AWS. La [arquitectura AWS y Docker](architecture/aws-deployment.md) y su vista C4 describen el despliegue. La documentación operativa se centraliza en `../devops-agents/docs/hack-the-andes-seguridad.md`, junto con los inventarios AWS y Cloudflare; esos archivos son del workspace de Deep Skill y no se publican con este repo. La entrega del evento vence el 18 de octubre a las 09:00; no se compromete una capacidad por figurar en este objetivo.

### Orden de ejecución y recortes propuestos

| Prioridad | Contenido | Criterio |
|---|---|---|
| P0 | Consulta completa, catálogos mínimos, primer feed, IA acotada, acciones y evaluación mínima con fallos de dependencias | Validar que funciona en el entorno acordado y en ventana privada; sin esto no hay base útil |
| P1 | Cuenta, mayor cuota, guardado, historial privado y borrado | Parte de la entrega solicitada por JP, construida sobre P0; verificar aislamiento y continuidad |
| P2 | Informe ampliado de 50 a 100 casos, comparación de varios modelos, entrada dedicada de teléfonos y fuentes adicionales | Primer candidato a recortar si afecta el cierre; sólo se anuncia lo implementado y medido |

Esta propuesta no elimina cuenta e historial ni aplaza las pruebas mínimas para habilitar IA. Si P0 y P1 corren riesgo, se reduce primero P2; cualquier cambio del alcance solicitado se revisa con JP. La amplitud del catálogo de patrones no obliga a implementar protocolos detallados de todas las modalidades en el evento.

## Cómo mantener los diagramas

PlantUML representa el VSM, los wireframes, el modelo de datos y las secuencias. Structurizr DSL es la fuente única de los diagramas C4 de contexto, contenedores, componentes y despliegue; sus exportaciones se generarán desde el modelo.

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


## Presentación y cierre del piloto

[Slides HTML](presentation/index.html), [guía del pitch](presentation/README.md), [revisión de seguridad y límites](architecture/security-review.md) y [borradores para redes personales](launch/social-copy.md). Las visitas aproximadas y las valoraciones se muestran discretamente en la web; los comentarios llegan sólo al equipo. La tabla del alcance distingue lo implementado del roadmap de prevención.
