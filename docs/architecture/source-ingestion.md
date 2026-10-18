# Catálogos peruanos e ingesta de fuentes

Estado: diseño objetivo y primer importador implementado en Phoenix. Ver [implementación](implementation.md) para las reglas concretas de publicación y caducidad. La existencia de una descarga o investigación local no significa que esté integrada en la API. Los términos de acceso, redistribución y uso comercial deben verificarse para cada fuente antes de habilitarla.

## Fuentes y situación actual

| Fuente o catálogo | Situación del prototipo | Propuesta |
|---|---|---|
| Marcas y dominios oficiales | Lista estática en el motor; falta migrar procedencia por registro al modelo nuevo | Curación manual con página oficial, alcance de coincidencia y fecha de verificación |
| Canales oficiales | Sin catálogo integrado de remitentes y contactos | Distinguir remitente publicado de canal de ayuda; verificar cada valor antes de activarlo |
| Políticas oficiales de marcas | Sin catálogo `BrandPolicy` integrado | Curar enunciado, canal, acción prohibida, condiciones, fuente y vigencia antes de generar una advertencia |
| Phishing.Database y PhishTank | Copias locales disponibles; no conectadas al análisis actual | Importación acotada, normalización y snapshot con procedencia |
| SBS, entidades informales | Investigación disponible; exportación pendiente de integrar | Avisos fechados, preservando nombre, modalidad y comunicado; coincidencia aproximada requiere revisión |
| RDAP | Consulta ya usada por el prototipo cuando está disponible | Mantener comprobación acotada y caché; ausencia de fecha no significa antigüedad ni legitimidad |

Referencias primarias: [SBS](https://www.sbs.gob.pe/usuarios/entidades-informales-identificadas), [Phishing.Database](https://github.com/Phishing-Database/Phishing.Database), [PhishTank](https://phishtank.org/). Las condiciones de esas fuentes no se presuponen idénticas.

## Primer feed propuesto

Phishing.Database queda como candidato preferido para el primer corte: su repositorio publica una [licencia MIT](https://github.com/Phishing-Database/Phishing.Database/blob/master/LICENSE) y distribuye un [archivo de dominios activos](https://github.com/Phishing-Database/Phishing.Database/blob/master/phishing-domains-ACTIVE.txt). Se debe conservar el aviso de licencia y copyright en las copias que se redistribuyan. El primer corte no depende de conseguir una cuenta nueva de otro proveedor.

La copia local inspeccionada contiene 392.178 líneas no vacías y 392.164 valores distintos antes de normalizar. No se anuncia esa cantidad como cobertura vigente ni se importa sin deduplicación y validación. SHA-256 de esa copia:

```text
70c6c2e24e6b3484e7ace27b079723e55937bc1f4cbd98bea38a472ec8e37326
```

La descarga no prueba frescura: antes de activarlo se registra una versión reproducible, fecha de publicación disponible y política de vencimiento. Si no cumple la antigüedad permitida, se declara la limitación en lugar de presentarlo como una comprobación vigente. Su integración y la elección definitiva siguen pendientes de validación. PhishTank queda como fuente adicional posible, sin bloquear esa primera prueba.

## Flujo de publicación

El módulo de ingesta pertenece al backend modular. Sus trabajos ocurren fuera de la consulta del usuario; no se obliga a descargar un feed completo durante un análisis ni se presupone otro microservicio.

1. Obtener exclusión por fuente para evitar publicaciones simultáneas entre réplicas. Usar únicamente destinos configurados, con plazos, tamaño máximo y validación de formato.
2. Registrar intento y preparar una versión en staging. Validar integridad, tipos, fechas, cantidad de registros y cambios anómalos frente a la versión activa.
3. Normalizar hosts y dominios sin visitar los destinos denunciados. Guardar el valor original sólo si es permitido y necesario para trazabilidad; no incorporar URLs personales completas a los resultados del usuario.
4. Exigir revisión manual antes de activar marcas, dominios, canales y políticas oficiales nuevos o modificados. Un error en esos catálogos puede legitimar una imitación o generar una acusación incorrecta. Los feeds de amenazas siguen su política de validación y caducidad, sin asumir que todo dominio permanece peligroso para siempre.
5. Publicar atómicamente la versión aprobada y conservar procedencia. Las consultas usan una versión coherente; una importación incompleta no reemplaza la anterior.
6. Si falla la actualización, conservar la última versión admitida, indicar su fecha y evaluar su vencimiento. Una fuente demasiado antigua pasa a no disponible según su política; no genera una comprobación satisfactoria.

Registrar versión, checksum, fecha, estado y conteos, sin contenido de mensajes de usuarios. El operador puede rechazar o revertir una publicación. La frecuencia y tolerancia de antigüedad se definen por fuente, según sus condiciones y las mediciones de operación.

## Semántica de las señales

Un dominio oficial acredita una relación publicada con la marca, no que el mensaje sea auténtico. El alcance de coincidencia, host exacto o dominio registrable, debe estar definido para cada registro; no aceptar un nombre de marca dentro de un dominio ajeno como coincidencia oficial.

Una coincidencia con un remitente publicado no autentica al emisor. La ausencia en un catálogo posiblemente incompleto queda como desconocida; no sube automáticamente el riesgo. Una contradicción con una política oficial explícita puede producir una advertencia independiente, con fuente y alcance.

Las políticas se conservan en `BrandPolicy`. La advertencia enlaza la política vigente y la comprobación del pedido en el mensaje, con el canal y condiciones aplicables. Un consejo que dice «no compartas tu clave» no contradice una política de no solicitarla. Las solicitudes detectadas sólo por interpretación mantienen esa atribución; no se convierten automáticamente en una señal determinista alta.

Un número extranjero por sí solo no demuestra fraude. No se identifica al titular ni se construye una lista pública de teléfonos acusados. Los teléfonos oficiales publicados son datos del catálogo; los números recibidos del usuario no se conservan en historial ni logs.

Un indicador de amenaza expresa el reporte de una fuente y su fecha. `first_seen` es la primera observación en esa fuente, no necesariamente el registro del dominio o el inicio del fraude. Una similitud con un nombre de un aviso SBS no basta para identificar una entidad; se presenta la limitación y el comunicado, sin convertirla en una acusación.

El [modelo de datos](data-model.md) separa estas entidades y su procedencia. El catálogo de acciones usa sólo canales y políticas curados; el modelo de IA no inventa teléfonos, enlaces de bloqueo ni instrucciones bancarias.

## Snapshot contrastado durante la implementación

La descarga íntegra del 17-oct coincide con el SHA anterior y el blob Git `067505dbc834384b48c3cd9e62114ad9c86ce6cd`, commit `12a20bf8dd2b7e78d9d38fc12b3e5c970f79d1a7`. Su publicación es del 2-oct-2026, no del día de descarga. El importador distingue ambas fechas y trata esta versión como histórica, con cobertura parcial y peso medio de sus reportes. La descarga reciente no renueva su publicación.

El archivo también incluye IPv4: se normalizan como hosts reportados sin visitarlos. La coincidencia es exacta; los conflictos con dominios oficiales exigen revisión. La ausencia de un host en esta versión histórica no habilita verde. El dataset crudo permanece ignorado y no se publica con el repositorio.
