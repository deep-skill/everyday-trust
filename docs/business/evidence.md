# Evidencia del problema y alcance de las cifras

Estado: cálculo MPFN reproducido y boletín INEI contrastado el 17 de octubre de 2026. No miden demanda del producto ni casos exclusivamente bancarios.

El [conjunto del Ministerio Público en la Plataforma Nacional de Datos Abiertos](https://www.datosabiertos.gob.pe/dataset/delitos-inform%C3%A1ticos-denunciados-ante-el-ministerio-p%C3%BAblico-mpfn) publica cantidades por tipo de delito y distrito fiscal, bajo la Ley de Delitos Informáticos. La copia analizada contiene 250 filas agregadas para enero a diciembre de 2025.

| Categoría en el CSV | Artículo | Suma de `cantidad` |
|---|---|---|
| Fraude informático | 8 | 29.342 |
| Suplantación de identidad | 9 | 10.559 |

Son cálculos propios sobre registros de delitos denunciados, no personas únicas, condenas ni pérdidas económicas. Las dos categorías no se suman para afirmar una cantidad de víctimas. No identifican cuántos hechos comenzaron en un mensaje de banco o billetera.

## Método y trazabilidad

Se revisó el agregador local antes de ejecutarlo y se contrastó con una segunda suma usando cantidades enteras. Filtros: `anio_denuncia = 2025`, `periodo_denuncia = ENERO - DICIEMBRE` y `tipo_caso = DENUNCIA`; agrupación por `articulo` y `des_articulo`, sumando `cantidad`. Todas las filas de esta copia pertenecen a ese periodo y tipo.

SHA-256 de los bytes de la copia analizada:

```text
7db6258b95be8e85f948b60ad515b730452271c8383b9f646c83ce27134ec182
```

El CSV declara fecha de publicación 21/09/2026. Durante esta revisión, la apertura directa del portal devolvió 403; no se descargó una versión nueva. El cálculo corresponde a esa copia, sin afirmar que sea la última disponible. Los datos crudos permanecen fuera del repositorio público.

## Personas: estimación ENAPRES del INEI

El [boletín de seguridad ciudadana, febrero a julio de 2026](https://www.inei.gob.pe/media/MenuRecursivo/boletines/boletin-seguridad-ciudadana-feb-jul-2026.pdf), cuadro resumen de la página 4, estima victimización por delitos informáticos en el 3,6% de la población urbana de 15 años o más; en el semestre comparable de 2025 fue 2,3%. La estimación de 2026 es preliminar.

El semestre móvil agrupa entrevistas; la pregunta de victimización se refiere a los últimos doce meses. No describir el dato como hechos ocurridos exclusivamente entre febrero y julio. La categoría incluye fraude bancario, suplantación, ciberacoso y otras modalidades; no es una tasa específica de phishing o estafas de Yape.

Es una estimación de encuesta sobre personas, distinta del registro administrativo del MPFN. No se suman ni se convierten en una cantidad de víctimas únicas del producto. Se verificaron la tabla y sus notas en el PDF, además de la definición temporal de su presentación y glosario.

## Uso en negocio y presentación

Redacción posible: «Al sumar el CSV 2025 del Ministerio Público, encontramos 29.342 registros de fraude informático y 10.559 de suplantación de identidad. Queremos ayudar a detectar señales antes de actuar ante un mensaje sospechoso».

Citar institución, periodo y cálculo propio. La relación entre esas cifras y nuestro segmento es una hipótesis: entrevistas y pruebas deben verificar qué mensajes reciben, cómo deciden hoy, si entienden la ayuda y si vuelven a usarla. No afirmar prevención efectiva o ahorro monetario a partir de estos conteos.
