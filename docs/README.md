# Everyday Trust: producto y arquitectura

Estado al 18-oct-2026: web y API desplegadas en AWS. Este índice separa la implementación actual, el diseño del producto y las hipótesis pendientes. El [estado de implementación](architecture/implementation.md) es la referencia de capacidades y comprobaciones; las [decisiones técnicas](architecture/stack-decision.md) explican el stack.

## Orden de lectura

1. [Negocio y alcance](business/product.md): problema, usuario, promesa, beneficios de cuenta, hipótesis de ingresos y criterios B01 a B08.
2. [Evidencia del problema](business/evidence.md) y [flujo de valor](business/value-stream.md): cifras con fuentes y recorrido del usuario.
3. [Experiencia](design/experience.md) e [identidad visual](design/brand.md): navegación, estados y marca.
4. [Implementación actual](architecture/implementation.md): comportamiento, validación, entrega y límites.
5. [Decisiones de stack](architecture/stack-decision.md), [arquitectura lógica](architecture/overview.md) y [despliegue AWS](architecture/aws-deployment.md).
6. [Modelo de datos](architecture/data-model.md), [contrato funcional](architecture/api-contract.md) y [OpenAPI](architecture/openapi.json): diseño y contrato de recursos; implementación detalla el comportamiento vigente.
7. [Fuentes e ingesta](architecture/source-ingestion.md), [contrato de IA](architecture/ai-interpretation.md), [evaluación reproducible](architecture/evaluation.md) e [informe](architecture/evaluation-report.json).
8. [Seguridad y límites](architecture/security-review.md) y [cómo reportar vulnerabilidades](../SECURITY.md).
9. [Presentación pública](https://verifica.deepskill.space/presentacion/), [fuente HTML](presentation/index.html) y [guía del pitch](presentation/README.md).

## Estado de entrega

| Área | Estado actual | Pendiente o límite |
|---|---|---|
| Consulta y ayuda | Texto/enlaces sin cuenta, evidencias, cobertura y seguimiento acotado | Capturas, PDF/QR y entrada dedicada de teléfonos fuera del corte |
| Cuenta e historial | Cognito, acceso, guardado voluntario, lectura privada y borrado | Acceso, guardado e historial comprobados en navegador privado; logout corregido pasó por HTTP, repetición visual final pendiente. Alta/recuperación con correo real sin probar |
| IA | Muse Spark Contributor por API directa, activo con mensaje completo y evidencia durante el piloto | Salida validada y piso de reglas; revisar proveedor y datos antes de difusión general |
| Fuentes | Catálogo oficial, RDAP, comprobación HEAD y 391.548 hosts de Phishing.Database | Snapshot del 2-oct histórico y cobertura parcial; fuentes adicionales por integrar |
| Evaluación | 24 fixtures sintéticos offline ejecutados en ExUnit/CI, con informe versionado | No mide calidad del modelo, precisión real ni eficacia de prevención |
| Tracción | Visitas aproximadas, consultas y valoraciones agregadas, separadas de demos | No equivale a personas únicas; comentarios privados y fuera de IA |
| Infraestructura | EC2/Compose/Nginx, RDS privado, Cognito, Tunnel y Actions/GHCR/OIDC/SSM operativos | EC2 único, RDS Single-AZ, restauración sin ejercicio y alarmas pendientes |
| Roadmap | Extensión, agentes en PC/celular y prevención personal/familiar | No implementados; monetización por validar |

## Diagramas

[workspace.dsl](architecture/workspace.dsl) es la fuente C4. Las vistas exportadas de contexto, contenedores, componentes y AWS en `docs/diagrams/` son anteriores a métricas y reseñas y todavía no las muestran. También pueden conservar descripciones anteriores de IA y validación OIDC. No se regeneraron durante el cierre; la fuente DSL, implementación y contrato de IA describen el estado actual.

PlantUML conserva las fuentes de VSM, wireframes, datos y secuencias. Las exportaciones se regeneran con las herramientas originales, no se editan a mano. Instrucciones de renderizado en [diagramas](architecture/overview.md#vistas-c4); herramientas: [Structurizr](https://docs.structurizr.com/binaries) y [PlantUML](https://plantuml.com/).

## Análisis y archivo

La [revisión de Scamio](business/scamio-review.md) y la [evaluación de WhatsApp/Zavu](business/whatsapp-zavu.md) conservan evidencia y propuestas, sin anunciar integraciones no implementadas.

Las [revisiones documentales](archive/review.md), la [revisión externa de Claude](archive/review-claude.md) y los [borradores sociales](archive/social-copy.md) son archivos históricos. No representan el backlog vigente ni publicaciones realizadas. El [historial de implementación](archive/implementation-history.md) está separado del estado actual.

La operación de AWS, Docker, Cloudflare, secretos por referencia, costos e inventarios se centraliza en `../devops-agents/docs/hack-the-andes-seguridad.md`, fuera de este repositorio público.
