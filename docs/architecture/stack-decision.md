# Decisiones técnicas

Estado al 18-oct-2026: stack desplegado en AWS. Las alternativas indicadas se descartaron o aplazaron para este corte; no implican compromisos sobre versiones futuras.

| Decisión | Motivo | Alternativa descartada en este corte | Fecha |
|---|---|---|---|
| SvelteKit, Svelte 5, TypeScript y Tailwind 4 | Continuidad con la base web, UI y BFF en el mismo origen | Reescribir la interfaz con otro framework | 17-oct-2026 |
| API separada con Elixir 1.18.4/OTP 27 y Phoenix 1.8.15 | Aplicación modular, concurrencia y contrato HTTP independiente | Go o Rust; la concurrencia no sustituye redundancia ni límites | 17-oct-2026 |
| Cognito User Pool | Identidad gestionada en AWS para acceso, confirmación y recuperación | Better Auth/D1; la rama experimental permanece fuera de main | 17-oct-2026 |
| BFF con cookie opaca HttpOnly/Secure y tokens cifrados en servidor | El navegador no almacena tokens; renovación y titularidad verificadas | JWT de aplicación elegido por el navegador o tokens en localStorage | 17-oct-2026 |
| RDS PostgreSQL privado | Datos separados del host, TLS, roles y backups gestionados; cuotas compartidas | PostgreSQL de producción en EC2 y D1 | 17-oct-2026 |
| EC2 T3a con Docker Compose y Nginx | Despliegue inicial simple, imágenes reproducibles y separación de servicios | ECS Fargate, Kubernetes y microservicios por función aplazados | 17-oct-2026 |
| Cloudflare Tunnel saliente | Entrada pública HTTPS sin puertos entrantes ni SSH público en EC2 | Exponer puertos de aplicación del host | 17-oct-2026 |
| Actions, GHCR, OIDC y SSM | Checks, imágenes por digest y despliegue sin llaves AWS persistentes | Compilar en producción, emulación ARM/amd64 y despliegue manual por SSH | 17-oct-2026 |
| Muse Spark 1.3 Contributor por API directa | Interpretar mensaje y evidencia con salida estructurada y piso de reglas | DeepSeek queda como adaptador alternativo sin activar | 18-oct-2026 |
| Contexto completo durante el piloto | El modelo recibe el mensaje original y todas las comprobaciones; original fuera de historial/logs | Códigos de señales sin texto como entrada del piloto; revisar modalidad antes de difusión general | 18-oct-2026 |
| Structurizr DSL/C4 y PlantUML | Fuentes editables para contexto, contenedores, componentes, datos y secuencias | Diagramas sin fuente reproducible | 17-oct-2026 |

## Restricciones del corte

Un EC2 y RDS Single-AZ no ofrecen alta disponibilidad. La cuota global de IA limita llamadas, no gasto monetario garantizado. Las vistas C4 exportadas son anteriores a métricas y reseñas; el índice identifica su alcance. Extensiones y aplicaciones instalables quedan fuera del primer corte.

La [implementación](implementation.md) describe comportamiento y pruebas; la [arquitectura AWS](aws-deployment.md) explica entrega y red. Los recursos reales, permisos, secretos por referencia, costos, backups y procedimientos se mantienen en `../devops-agents/docs/hack-the-andes-seguridad.md`, fuera del repositorio público.
