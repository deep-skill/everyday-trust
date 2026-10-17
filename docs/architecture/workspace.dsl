workspace "Verificador de mensajes" "Arquitectura lógica propuesta; tecnologías pendientes de acuerdo con JP" {
    model {
        visitor = person "Persona que consulta" "Evalúa un mensaje y decide su siguiente acción, con o sin cuenta."
        operator = person "Operador" "Mantiene fuentes, costos y funcionamiento sin leer mensajes en logs."
        identity = softwareSystem "Servicio de identidad" "Registro y acceso a cuentas; Cognito es el candidato sobre AWS."
        intelligence = softwareSystem "Proveedor de IA" "Interpreta casos y seguimiento con respuesta estructurada y plazo máximo."
        sources = softwareSystem "Fuentes verificables" "Páginas oficiales de marcas, avisos SBS, feeds de phishing y RDAP, con procedencia."

        product = softwareSystem "Verificador de mensajes" "Señales, explicación y ayuda ante mensajes sospechosos para personas en Perú." {
            web = container "Web" "Consulta abierta, resultado, seguimiento e historial privado." "SvelteKit y Tailwind, propuesta de continuidad"
            api = container "API" "Acceso, análisis, conversación, cuotas e historial." "HTTP JSON; lenguaje pendiente" {
                access = component "Acceso y cuotas" "Valida identidad, titularidad de casos temporales y presupuesto de operaciones." "Módulo de aplicación"
                cases = component "Casos" "Entrega evidencia inicial, coordina actualizaciones y mantiene contexto minimizado y cobertura." "Módulo de aplicación"
                signals = component "Señales verificables" "Comprueba dominios y fuentes con red restringida y caché." "Módulo de aplicación"
                privacy = component "Minimización de datos" "Prepara contexto permitido antes del modelo, estado temporal y guardado; valida también las salidas." "Módulo de aplicación"
                policy = component "Política de riesgo" "Conserva el piso de reglas; limita a sospechoso una elevación sólo por interpretación." "Módulo de aplicación"
                conversation = component "Interpretación y seguimiento" "Aísla el proveedor de IA, valida salidas y acota el seguimiento al caso." "Adaptador de IA"
                history = component "Historial" "Guarda resúmenes saneados y controla lectura y borrado por propietario." "Módulo de aplicación"
                ingestion = component "Ingesta de fuentes" "Valida snapshots; revisa dominios, canales y políticas oficiales antes de publicar." "Trabajos del backend; ejecución pendiente"
            }
            database = container "Datos persistentes" "Historial, marcas, dominios, canales, políticas, indicadores, avisos y versiones." "Base relacional; motor pendiente" {
                tags "Database"
            }
            temporary = container "Estado temporal y cuotas" "Casos con vencimiento, contexto y contadores compartidos entre réplicas." "Almacenamiento compartido; servicio pendiente" {
                tags "Database"
            }
            evaluator = container "Evaluador" "Ejecuta corpus sintético o saneado y produce métricas versionadas fuera del tráfico de usuarios." "Herramienta local o CI; por implementar"
        }

        visitor -> web "Consulta y guarda casos" "HTTPS"
        operator -> product "Mantiene fuentes y operación" "Acceso operativo"
        web -> api "Gestiona casos e historial" "HTTPS / JSON"
        web -> identity "Inicia acceso" "OIDC, propuesta"
        api -> identity "Obtiene claves públicas" "HTTPS / OIDC"
        api -> intelligence "Interpreta contexto minimizado" "HTTPS"
        api -> sources "Consulta evidencia" "HTTPS"
        api -> database "Lee y guarda datos" "Conexión protegida"
        api -> temporary "Casos y cuotas" "Conexión protegida"
        operator -> evaluator "Revisa calidad y costos"
        evaluator -> api "Evalúa entorno de prueba" "HTTP / fixtures"

        web -> access "Inicia una operación"
        access -> identity "Valida identidad" "HTTPS / OIDC"
        access -> temporary "Controla cuota y sesión"
        access -> cases "Autoriza consulta"
        access -> history "Autoriza historial"
        cases -> signals "Analiza"
        signals -> sources "Consulta evidencia" "HTTPS"
        signals -> database "Consulta snapshots y versiones"
        cases -> policy "Evalúa riesgo"
        cases -> privacy "Minimiza contexto"
        cases -> conversation "Explica"
        conversation -> privacy "Valida entrada y salida"
        conversation -> intelligence "Envía contexto permitido" "HTTPS"
        cases -> temporary "Mantiene etapas y contexto"
        history -> temporary "Comprueba caso y acceso"
        history -> privacy "Restringe campos"
        history -> database "Gestiona datos del titular"
        operator -> ingestion "Aprueba catálogos"
        ingestion -> sources "Obtiene snapshots" "HTTPS / fuentes configuradas"
        ingestion -> database "Valida y publica versiones"
    }

    views {
        systemContext product "Context" {
            title "Contexto del verificador de mensajes"
            include *
            autoLayout lr
        }
        container product "Containers" {
            title "Contenedores lógicos del verificador de mensajes"
            include *
            autoLayout lr
        }
        component api "ApiComponents" {
            title "Componentes lógicos de la API"
            include *
            autoLayout tb 300 220
        }
        styles {
            element "Element" {
                color #0f172a
                background #e2e8f0
            }
            element "Person" {
                shape Person
                color #ffffff
                background #1e3a8a
            }
            element "Software System" {
                color #ffffff
                background #1d4ed8
            }
            element "Container" {
                background #dbeafe
            }
            element "Component" {
                background #eff6ff
            }
            element "Database" {
                shape Cylinder
                background #dcfce7
            }
        }
    }
}
