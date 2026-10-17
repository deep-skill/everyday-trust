# ¿Es estafa? (nombre provisional)

Verificador de estafas para el Perú. Pegas el mensaje, link o número que te llegó por WhatsApp o SMS y recibes un veredicto en semáforo, el porqué en lenguaje simple y qué hacer.

Proyecto de Deep Skill para Hack the Andes 2026, track Seguridad.

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
```

## Despliegue

Worker de Cloudflare con assets estáticos (SvelteKit + `adapter-cloudflare`):

```bash
npm run deploy
```

## Limitaciones conocidas

- Los dominios `.pe` no publican fecha de creación (ni RDAP ni WHOIS de NIC.pe), así que su antigüedad no se evalúa.
- Solo se siguen redirecciones de acortadores: muchos links de phishing llevan un identificador por víctima y visitarlos confirmaría que la persona hizo clic.
