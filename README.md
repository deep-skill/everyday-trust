# Everyday Trust

**¿Es estafa? · Revisa antes de responder.**

Verificador de mensajes sospechosos con contexto peruano, por Deep Skill para Hack the Andes 2026, track Seguridad. Everyday Trust es el proyecto público; ¿Es estafa? es su primera web.

El usuario consulta sin cuenta y recibe señales, un resumen y un siguiente paso. Con Cognito puede acceder a mayor uso, guardar voluntariamente resúmenes, consultar su historial privado y borrar consultas o su cuenta. La UI usa la [identidad visual provisional](docs/design/brand.md).

## Estado comprobable

Implementación desplegada en AWS en una red privada: SvelteKit/TypeScript/Tailwind, BFF Node, API Elixir/Phoenix, RDS PostgreSQL y Cognito Essentials. Incluye OIDC/PKCE, cookies opacas, tokens cifrados, autorización por propietario, cuotas atómicas, vencimiento y borrado. Hay 67 pruebas Phoenix, 45 Node y 29 comprobaciones de navegador con identidad simulada. Otras 12 comprobaciones integran Cognito y RDS reales con dos cuentas sintéticas, eliminadas al finalizar y sin envío de emails/SMS. El recorrido OIDC completo en navegador contra AWS sigue pendiente.

La ingesta de Phishing.Database valida snapshots y publica una versión atómica. El snapshot contrastado fue publicado el 2-oct: se trata como histórico y no como una comprobación vigente del día. El resultado muestra cobertura y fechas. Los adaptadores directos de IA están escritos; todavía no se han activado con mensajes reales.

CI, imágenes amd64 en GHCR y despliegue AWS por OIDC/SSM ejecutados correctamente. EC2 no tiene puertos entrantes. El acceso público por Cloudflare Tunnel está pendiente de un token con permisos de escritura. La [implementación](docs/architecture/implementation.md) distingue estas capacidades de la [arquitectura objetivo](docs/architecture/aws-deployment.md).

## Desarrollo local

Requisitos: Node 24, Docker/Compose. Elixir y PostgreSQL se ejecutan en contenedores.

```bash
npm ci
cp .env.example .env

docker compose -f compose.dev.yml up -d --build
docker compose -f compose.dev.yml exec api-dev mix deps.get --check-locked
docker compose -f compose.dev.yml exec api-dev mix ecto.setup
node --env-file=.env scripts/migrate-web.mjs
```

En terminales separadas:

```bash
docker compose -f compose.dev.yml exec api-dev mix phx.server
npm run dev
```

La consulta anónima funciona sin configurar Cognito ni IA. El registro aparece como pendiente hasta completar la configuración de identidad. La configuración local desactiva consultas de red por defecto; para probarlas conscientemente, pasar NETWORK_CHECKS=true al proceso de API. El historial nunca conserva el texto original.

## Comprobaciones

```bash
npm run check
npm test

docker compose -f compose.dev.yml exec -e MIX_ENV=test api-dev mix ecto.setup
docker compose -f compose.dev.yml exec -e MIX_ENV=test api-dev mix test
```

Las 43 regresiones TypeScript conservan el motor anterior como referencia. Phoenix añade pruebas de reglas, redirects restringidos, JWT, cuotas concurrentes, aislamiento, borrado e ingesta. No dependen de red externa.

La prueba completa de navegador requiere Python con Playwright y Google Chrome Dev, y puertos 4000/4173 libres. Usa una base E2E separada y claves efímeras, fuerza renovación/rotación de sesión y no llama a Cognito real:

```bash
python3 tests/e2e/run.py
```

Se puede indicar el Python con Playwright instalado mediante E2E_PYTHON. Los helpers de identidad de prueba están excluidos de las imágenes de producción.

## Configuración de producción

Web: API_BASE_URL, API_SERVICE_TOKEN, WEB_DATABASE_URL, DATABASE_CA_FILE, COGNITO_ISSUER/CLIENT_ID/DOMAIN y SESSION_ENCRYPTION_KEY de 32 bytes en base64. La imagen de producción exige COGNITO_CLIENT_SECRET y ORIGIN HTTPS. API: DATABASE_URL, DATABASE_CA_FILE, SECRET_KEY_BASE, API_SERVICE_TOKEN y los mismos issuer/client id. Ver plantillas de entorno y [decisiones implementadas](docs/architecture/implementation.md).

Las URLs PostgreSQL no incluyen opciones SSL: se configura una CA explícita con verificación de hostname. Las credenciales de migración se separan de los roles de ejecución; el BFF sólo accede al esquema de sesiones. Ningún secreto entra en las imágenes.

Producción usa RDS privado y EC2/Docker/Nginx/Cloudflare Tunnel según el [diagrama AWS](docs/diagrams/rendered/structurizr-AwsDeployment.svg). Compose, Nginx, roles y script operativo se centralizan en `../devops-agents/everyday-trust/`; recursos, permisos y evidencia en el runbook de ese repositorio. Los workflows públicos ejecutan CI y permiten publicar imágenes GHCR por SHA; el CD usa OIDC/SSM y un token GHCR efímero, sin llaves AWS persistentes ni SSH.

## Documentación

[Negocio, VSM, UX, arquitectura y datos](docs/README.md), [implementación](docs/architecture/implementation.md), [fuentes e ingesta](docs/architecture/source-ingestion.md) e [identidad visual](docs/design/brand.md). Fuentes editables de diagramas en PlantUML y [Structurizr DSL](docs/architecture/workspace.dsl).

Las consultas no autentican al remitente ni garantizan seguridad. Sólo se siguen acortadores permitidos y se detienen antes del destino final; una dependencia fallida o una fuente histórica no habilitan un resultado verde. El endpoint anterior POST /api/analyze está retirado y devuelve 410; el flujo actual usa /api/v1/cases.

La API también publica métricas agregadas en `/api/v1/stats`, separando ejemplos de consultas. Ver [estado de implementación](docs/architecture/implementation.md).
