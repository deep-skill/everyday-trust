# Everyday Trust

**¿Es estafa? · Revisa antes de responder.**

Verificador de estafas para el Perú. Pegas el mensaje, link o número que te llegó por WhatsApp o SMS y recibes un veredicto en semáforo, el porqué en lenguaje simple y qué hacer.

Everyday Trust es el nombre del proyecto público de Deep Skill para Hack the Andes 2026, track Seguridad. **¿Es estafa?** es su primera web, enfocada en revisar mensajes con contexto peruano. El nombre general permite evolucionar hacia prevención digital sin cambiar cómo se presenta la web a sus usuarios.

La [definición de negocio, UX y arquitectura](docs/README.md) describe el producto objetivo antes de continuar la implementación. El stack confirmado es SvelteKit, API Elixir/Phoenix, PostgreSQL y Cognito, con BFF y sesión opaca. La [propuesta AWS](docs/architecture/aws-deployment.md) usa un EC2 con Docker Compose, RDS PostgreSQL privado, Cognito y Cloudflare; CI/CD propuesto con GitHub Actions y GHCR; todavía no está implementada. Las instrucciones Cloudflare de este archivo corresponden al prototipo existente.

La [identidad visual](docs/design/brand.md), con logo, favicon, paleta y tipografía, está aprobada provisionalmente. Las vistas de móvil/escritorio siguen para revisión y todavía están separadas de la app.

## Cómo decide

El veredicto combina señales verificables, no solo la opinión de un modelo:

| Señal | Fuente |
|---|---|
| El link menciona una marca peruana (BCP, Yape, SUNAT, Serpost…) pero no es su dominio oficial | Lista curada de dominios oficiales + detección de typosquatting y leetspeak |
| Dominio recién creado | RDAP (`rdap.org`) |
| Acortadores que esconden el destino | Se sigue la redirección (solo en acortadores) |
| Dominio con letras de otros alfabetos | Punycode (`xn--`) |
| Terminaciones baratas muy usadas en phishing | Lista de TLD |
| Números extranjeros | Prefijo internacional |
| Lenguaje típico de estafa: claves, urgencia, premios, paquete retenido, familiar con número nuevo, extorsión | Reglas de texto |

## Desarrollo

```bash
npm install
cp .dev.vars.example .dev.vars   # llaves locales, nunca se commitean
npm run dev
npm run check                    # tipos
npm test                         # build + pruebas de regresión, sin requests externos
```

## Arquitectura objetivo

La [vista AWS propuesta](docs/diagrams/rendered/structurizr-AwsDeployment.svg) muestra EC2 con Nginx, SvelteKit/BFF y Phoenix, RDS PostgreSQL privado, Cognito, Cloudflare Tunnel y entrega mediante Actions/GHCR. Se genera desde [Structurizr DSL](docs/architecture/workspace.dsl); detalles y estado en [despliegue](docs/architecture/aws-deployment.md).

## Despliegue del prototipo

Worker de Cloudflare con assets estáticos (SvelteKit + `adapter-cloudflare`):

```bash
npm run deploy
```

## Limitaciones conocidas

- Los dominios `.pe` no publican fecha de creación (ni RDAP ni WHOIS de NIC.pe), así que su antigüedad no se evalúa.
- Solo se consultan acortadores conocidos por HTTPS. Al encontrar el destino final, se analiza su dominio sin visitarlo: un link de phishing puede identificar a la víctima.
- Se analizan los dominios de todos los links, con consultas externas para los primeros cinco. Si quedan verificaciones pendientes o hay señales de riesgo, no se muestra un veredicto verde.
- Las reglas reconocen algunas advertencias y negaciones explícitas; todavía no interpretan todo el contexto de un mensaje.
