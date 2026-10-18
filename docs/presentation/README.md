# Presentación de ¿Es estafa?

Cinco slides, pensadas para tres minutos con una demo breve. HTML/CSS/JavaScript sin bibliotecas, fuentes externas, analítica ni llamadas al modelo. Fuente editable en este directorio. Publicación en `/presentacion/` mediante `scripts/sync-presentation.mjs` antes del build; no editar la copia generada en static.

1. Problema y registros denunciados del MPFN en2025. No son personas únicas ni casos exclusivamente bancarios.
2. Producto disponible y ejemplo ficticio, con explicación de capacidades y límites.
3. Extensión y agentes en PC/celular como roadmap con permisos. La monetización de prevención personal/familiar es una hipótesis.
4. Arquitectura AWS de alto nivel, adaptada del C4: entrada, ejecución, datos, identidad, IA y operación.
5. Gracias, preguntas y URL para probar.

Abrir `index.html` o servir con `python3 -m http.server 8137 --bind 127.0.0.1 --directory docs/presentation`. Flechas, espacio y PageUp/PageDown navegan; F cambia pantalla completa, N muestra notas y D abre la demo. El control de animación pausa las flechas y respeta movimiento reducido. Imprimir permite obtener páginas16:9. No requiere conexión para mostrar el contenido; la demo y las fuentes sí.

El diagrama SVG conserva texto y flechas editables. Los símbolos originales AWS se incorporan sin modificar sus proporciones. La línea discontinua animada representa el recorrido lógico, no tráfico ni telemetría en tiempo real. El diagrama muestra un EC2 y RDS Single-AZ; no afirma alta disponibilidad. CloudWatch representa el grupo de logs creado, sin alarmas operativas todavía.

Fuentes: [evidencia y método MPFN](../business/evidence.md), [C4](../architecture/workspace.dsl), [implementación](../architecture/implementation.md) y [revisión de seguridad](../architecture/security-review.md). Símbolos: [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/), paquete oficial del31-jul-2026; los siete SVG originales usados están en `icons/`. Marca propia en `mark.svg`.
