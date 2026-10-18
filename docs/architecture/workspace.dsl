workspace "Verificador de mensajes" "Stack confirmado; despliegue AWS propuesto y todavía sin aprovisionar" {
    model {
        visitor = person "Persona que consulta" "Evalúa un mensaje y decide su siguiente acción, con o sin cuenta."
        operator = person "Operador" "Mantiene fuentes, costos y funcionamiento sin leer mensajes en logs."
        identity = softwareSystem "Servicio de identidad" "Registro, confirmación, recuperación y acceso con Amazon Cognito."
        intelligence = softwareSystem "Proveedor de IA" "API directa: Muse Spark 1.3 Contributor o deepseek-flash; elección y condiciones pendientes."
        sources = softwareSystem "Fuentes verificables" "Páginas oficiales de marcas, avisos SBS, feeds de phishing y RDAP, con procedencia."

        product = softwareSystem "Verificador de mensajes" "Señales, explicación y ayuda ante mensajes sospechosos para personas en Perú." {
            web = container "Web" "Consulta abierta, resultado, seguimiento e historial privado." "SvelteKit / TypeScript / Tailwind; BFF Node.js"
            api = container "API" "Acceso, análisis, conversación, cuotas e historial." "Elixir / Phoenix; release OTP" {
                access = component "Acceso y cuotas" "Valida identidad, titularidad de casos temporales y presupuesto de operaciones." "Módulo de aplicación"
                cases = component "Casos" "Entrega evidencia inicial, coordina actualizaciones y mantiene contexto minimizado y cobertura." "Módulo de aplicación"
                signals = component "Señales verificables" "Comprueba dominios y fuentes con red restringida y caché." "Módulo de aplicación"
                privacy = component "Minimización de datos" "Prepara contexto permitido antes del modelo, estado temporal y guardado; valida también las salidas." "Módulo de aplicación"
                policy = component "Política de riesgo" "Conserva el piso de reglas; limita a sospechoso una elevación sólo por interpretación." "Módulo de aplicación"
                conversation = component "Interpretación y seguimiento" "Aísla el proveedor de IA, valida salidas y acota el seguimiento al caso." "Adaptador de IA"
                history = component "Historial" "Guarda resúmenes saneados y controla lectura y borrado por propietario." "Módulo de aplicación"
                ingestion = component "Ingesta de fuentes" "Valida snapshots; revisa dominios, canales y políticas oficiales antes de publicar." "Trabajos del backend; ejecución pendiente"
            }
            database = container "Datos persistentes" "Historial, catálogos y evidencia; sesiones BFF en esquema y rol propios." "PostgreSQL en Amazon RDS" {
                tags "Database"
            }
            temporary = container "Estado temporal y cuotas" "Casos con vencimiento, contexto y contadores compartidos entre réplicas." "Mismo RDS PostgreSQL; TTL y cuotas atómicas" {
                tags "Database"
            }
            evaluator = container "Evaluador" "Ejecuta corpus sintético o saneado y produce métricas versionadas fuera del tráfico de usuarios." "Herramienta local o CI; por implementar"
        }

        visitor -> web "Consulta y guarda casos" "HTTPS"
        operator -> product "Mantiene fuentes y operación" "Acceso operativo"
        web -> api "Gestiona consultas" "HTTP / JSON; red Docker interna"
        web -> identity "Gestiona acceso" "OIDC / Code + PKCE"
        web -> database "Sesiones BFF cifradas" "PostgreSQL / TLS; rol propio"
        api -> identity "Obtiene claves públicas" "HTTPS / OIDC"
        api -> intelligence "Interpreta contexto minimizado" "HTTPS"
        api -> sources "Consulta evidencia" "HTTPS"
        api -> database "Lee y guarda datos" "Conexión protegida"
        api -> temporary "Casos y cuotas" "Conexión protegida"
        operator -> evaluator "Revisa calidad y costos"
        evaluator -> api "Ejecuta corpus" "HTTP / fixtures"

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
        production = deploymentEnvironment "AWS propuesta" {
            deploymentNode "Cloudflare" "Borde público; funciones sujetas al plan." "Cloudflare" {
                edge = infrastructureNode "DNS, HTTPS y WAF" "Mitiga tráfico antes del origen." "Cloudflare Free; reglas limitadas"
            }
            deploymentNode "GitHub" "Entrega propuesta; no hay workflows activos de esta arquitectura." "GitHub" {
                ci = infrastructureNode "GitHub Actions" "Checks, build y publicación por commit." "Runner Linux amd64"
                registry = infrastructureNode "GHCR" "Imágenes web y API identificadas por digest." "OCI Registry"
            }
            deploymentNode "AWS / us-east-1" "Primera región propuesta." "Amazon Web Services" {
                deploymentNode "VPC" "Aplicaciones y datos con security groups separados." "Amazon VPC" {
                    deploymentNode "Subred de aplicación" "Ruta a Internet; IPv4 de salida, sin ingreso al SG." "Subnet" {
                        deploymentNode "EC2 / Docker Compose" "Un host T3a propuesto; sin alta disponibilidad." "Linux amd64 / t3a.medium" {
                            tunnel = infrastructureNode "cloudflared" "Conexión saliente al borde." "Contenedor; túnel nombrado"
                            gateway = infrastructureNode "Nginx" "Límites, cabeceras y rutas al BFF." "Contenedor; puerto interno 8080"
                            webInstance = containerInstance web
                            apiInstance = containerInstance api
                            agent = infrastructureNode "SSM Agent" "Despliegue acotado, sin SSH público." "Amazon SSM"
                        }
                    }
                    deploymentNode "Subredes privadas de datos / 2 AZ" "DB subnet group; una instancia inicial Single-AZ." "Private subnets" {
                        deploymentNode "RDS PostgreSQL" "Un motor físico, sin endpoint público; cifrado y backups." "db.t4g.micro / Single-AZ / gp3" {
                            containerInstance database
                            containerInstance temporary
                        }
                    }
                }
                deploymentNode "Cognito User Pool" "Identidad gestionada; pendiente de crear." "Amazon Cognito" {
                    softwareSystemInstance identity
                }
                secrets = infrastructureNode "Parameter Store" "Secretos cifrados y acceso mediante Instance Profile." "SSM SecureString"
                logs = infrastructureNode "CloudWatch" "Logs saneados, métricas y alarmas." "Amazon CloudWatch"
                artifacts = infrastructureNode "S3 privado" "Artefactos versionados y snapshots de fuentes permitidas." "Amazon S3"
                oidc = infrastructureNode "IAM / OIDC" "Confianza restringida a repo y rama o environment." "AWS IAM"
            }
            deploymentNode "API externa de IA" "Proveedor pendiente; sólo contexto permitido." "HTTPS" {
                softwareSystemInstance intelligence
            }
            ci -> registry "Publica imágenes por SHA/digest" "HTTPS"
            ci -> oidc "Solicita credenciales temporales" "OIDC / STS"
            oidc -> agent "Autoriza deploy acotado" "SSM"
            ci -> artifacts "Entrega manifiesto versionado" "HTTPS / credenciales temporales"
            agent -> artifacts "Obtiene artefacto autorizado" "HTTPS / Instance Profile"
            agent -> registry "Descarga digests aprobados" "HTTPS"
            tunnel -> edge "Establece túnel saliente" "QUIC o HTTP/2 cifrado"
            edge -> tunnel "Entrega peticiones públicas" "Conexión establecida"
            tunnel -> gateway "Encamina hostname publicado" "HTTP; red Docker de entrada"
            gateway -> webInstance "Entrega todas las rutas públicas" "HTTP; red Docker"
            webInstance -> secrets "Obtiene secretos de sesión" "HTTPS / rol EC2"
            apiInstance -> secrets "Obtiene secretos de aplicación" "HTTPS / rol EC2"
            apiInstance -> artifacts "Publica snapshots permitidos" "HTTPS / rol EC2"
            apiInstance -> logs "Emite métricas y logs saneados" "Sin texto ni tokens"
        }
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
            autoLayout lr 300 250
        }
        component api "ApiComponents" {
            title "Componentes lógicos de la API"
            include *
            autoLayout tb 300 220
        }
        deployment * production "AwsDeployment" {
            title "AWS propuesto: EC2, RDS, Cognito y entrega con Actions/GHCR"
            include *
            autoLayout lr
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
            element "Deployment Node" {
                background #f8fafc
                color #334155
            }
            element "Infrastructure Node" {
                background #fef3c7
                color #78350f
            }
            element "Database" {
                shape Cylinder
                background #dcfce7
            }
        }
    }
}
