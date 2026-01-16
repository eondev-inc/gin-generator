# Gin API Generator v2.0

Generador CLI que crea proyectos API REST completos con **Go**, **Gin Framework**, **sqlc**, **PostgreSQL** y arquitectura **Domain-Driven Design (DDD)**. Incluye wizard interactivo, features opcionales y scaffolding profesional.

## Novedades v2.0

- **Wizard Interactivo** - Configura tu proyecto paso a paso con prompts intuitivos
- **Arquitectura DDD** - Estructura Domain-Driven Design con separación clara de capas
- **Features Opcionales** - JWT, Swagger, CORS, Rate Limiting, Health Checks, Logging estructurado, Docker multi-stage
- **Comando Quick** - Generación rápida sin prompts para CI/CD o scripts
- **Documentación en Español** - README generado en español

## Tabla de Contenidos

- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Comandos Disponibles](#comandos-disponibles)
- [Uso](#uso)
  - [Wizard Interactivo](#1-wizard-interactivo-init)
  - [Generación Rápida](#2-generación-rápida-quick)
  - [Agregar Módulos](#3-agregar-módulos-module)
- [Estructura DDD Generada](#estructura-ddd-generada)
- [Features Opcionales](#features-opcionales)
- [Makefile - Comandos de Desarrollo](#makefile---comandos-de-desarrollo)
- [Arquitectura DDD](#arquitectura-ddd)
- [FAQ](#preguntas-frecuentes)

## Requisitos

### Para usar el generador

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| **Bash** | 4.0+ | Ejecutar el script |
| **Git** | 2.0+ | Control de versiones |

### Para los proyectos generados

| Herramienta | Versión | Requerido | Instalación |
|-------------|---------|-----------|-------------|
| **Go** | 1.21+ | ✅ Sí | [golang.org/dl](https://golang.org/dl/) |
| **PostgreSQL** | 13+ | ✅ Sí | [postgresql.org](https://www.postgresql.org/download/) |
| **Make** | 3.8+ | ✅ Sí | Preinstalado en Linux/macOS |
| **sqlc** | 1.20+ | ⚙️ Auto | `make install-tools` |
| **golang-migrate** | 4.15+ | ⚙️ Auto | `make install-tools` |
| **Air** | 1.40+ | ⚙️ Auto | `make install-tools` |
| **Docker** | 20.0+ | 📦 Opcional | [docker.com](https://www.docker.com) |

## Instalación

```bash
# Clonar repositorio
git clone https://github.com/eondev-inc/gin-generator.git
cd gin-generator

# Dar permisos de ejecución
chmod +x gen-init.sh

# (Opcional) Instalación global
sudo cp gen-init.sh /usr/local/bin/gin-gen
```

## Comandos Disponibles

| Comando | Descripción |
|---------|-------------|
| `./gen-init.sh init` | Wizard interactivo para crear proyecto |
| `./gen-init.sh quick <nombre> [modulo]` | Generación rápida sin prompts |
| `./gen-init.sh module <nombre>` | Agregar módulo DDD al proyecto |
| `./gen-init.sh generate` | Regenerar código sqlc |
| `./gen-init.sh help` | Mostrar ayuda |

## Uso

### 1. Wizard Interactivo (`init`)

El wizard te guía paso a paso para configurar tu proyecto:

```bash
./gen-init.sh init
```

**Pasos del wizard:**

1. **Nombre del proyecto** - Nombre de la carpeta (ej: `mi-api`)
2. **Módulo Go** - Path del módulo (ej: `github.com/usuario/mi-api`)
3. **Puerto del servidor** - Puerto HTTP (default: `8080`)
4. **Base de datos** - Nombre de la BD PostgreSQL
5. **Features opcionales** - Selección interactiva de características

**Ejemplo de sesión:**

```
╔══════════════════════════════════════════════════════════════╗
║                   GIN API GENERATOR v2.0                      ║
║           Generador de APIs REST con Go y Gin                 ║
╚══════════════════════════════════════════════════════════════╝

📦 Nombre del proyecto: mi-ecommerce-api
📦 Nombre del módulo Go [github.com/user/mi-ecommerce-api]: 
🌐 Puerto del servidor [8080]: 3000
🗄️  Nombre de la base de datos [mi_ecommerce_api_db]: ecommerce_db

🔧 Selecciona las features que deseas incluir:

   [1] JWT Authentication     - Autenticación con JSON Web Tokens
   [2] Swagger/OpenAPI        - Documentación automática de la API
   [3] CORS Middleware        - Cross-Origin Resource Sharing
   [4] Rate Limiting          - Límite de peticiones por IP
   [5] Health Checks          - Endpoints /health y /ready
   [6] Structured Logging     - Logging con slog (JSON/text)
   [7] Docker Multi-stage     - Dockerfile optimizado para producción

Ingresa los números separados por espacio (ej: 1 3 5) o 'all' para todos:
> 1 3 5 6

✅ Proyecto 'mi-ecommerce-api' creado exitosamente!
```

### 2. Generación Rápida (`quick`)

Para scripts, CI/CD o cuando ya conoces la configuración:

```bash
# Sintaxis
./gen-init.sh quick <nombre_proyecto> [modulo_go]

# Ejemplos
./gen-init.sh quick mi-api
./gen-init.sh quick mi-api github.com/empresa/mi-api
```

Genera un proyecto con configuración por defecto:
- Puerto: 8080
- Features: CORS, Health Checks, Logging
- Módulo user de ejemplo

### 3. Agregar Módulos (`module`)

Dentro de un proyecto existente, agrega nuevos módulos DDD:

```bash
cd mi-proyecto
../gen-init.sh module product
```

**Genera:**

```
internal/
├── domain/product/
│   ├── entity.go           # Entidad Product
│   ├── repository.go       # Interface ProductRepository
│   └── errors.go           # Errores de dominio
├── application/product/
│   ├── service.go          # ProductService
│   └── dto.go              # CreateProductDTO, UpdateProductDTO
└── infrastructure/persistence/postgres/
    └── product_repository.go  # Implementación del repositorio

sql/
├── schema/product.sql
├── queries/product.sql
└── migrations/
    ├── 000002_create_products_table.up.sql
    └── 000002_create_products_table.down.sql
```

**Post-generación:**

```bash
# Regenerar código sqlc
make sqlc-generate

# Aplicar migraciones
make migrate-up

# Registrar rutas en router (manual)
```

## Estructura DDD Generada

```
mi-proyecto/
├── cmd/
│   └── api/
│       └── main.go                         # Entry point con graceful shutdown
│
├── internal/
│   ├── domain/                             # 🎯 CAPA DE DOMINIO
│   │   └── user/
│   │       ├── entity.go                   # Entidad User (reglas de negocio)
│   │       ├── repository.go               # Interface UserRepository
│   │       └── errors.go                   # ErrUserNotFound, ErrUserExists
│   │
│   ├── application/                        # 📋 CAPA DE APLICACIÓN
│   │   └── user/
│   │       ├── service.go                  # UserService (casos de uso)
│   │       └── dto.go                      # CreateUserDTO, UpdateUserDTO
│   │
│   ├── infrastructure/                     # 🔧 CAPA DE INFRAESTRUCTURA
│   │   ├── config/
│   │   │   └── config.go                   # Carga de variables de entorno
│   │   └── persistence/
│   │       └── postgres/
│   │           ├── connection.go           # Pool de conexiones PostgreSQL
│   │           └── user_repository.go      # Implementación UserRepository
│   │
│   └── interfaces/                         # 🌐 CAPA DE INTERFACES
│       └── http/
│           ├── server/
│           │   └── server.go               # Configuración del servidor Gin
│           ├── router/
│           │   └── router.go               # Definición de rutas
│           ├── handler/
│           │   └── user_handler.go         # Handlers HTTP (controllers)
│           ├── middleware/
│           │   ├── auth.go                 # JWT middleware (si habilitado)
│           │   ├── cors.go                 # CORS middleware (si habilitado)
│           │   ├── ratelimit.go            # Rate limiting (si habilitado)
│           │   ├── logger.go               # Request logging (si habilitado)
│           │   └── recovery.go             # Panic recovery
│           └── response/
│               └── response.go             # Response wrapper estándar
│
├── pkg/                                    # 📦 PAQUETES PÚBLICOS
│   ├── errors/
│   │   └── errors.go                       # Errores personalizados (AppError)
│   ├── jwt/                                # (si JWT habilitado)
│   │   └── jwt.go                          # Helpers para generar/validar tokens
│   └── logger/                             # (si logging habilitado)
│       └── logger.go                       # Setup de slog
│
├── sql/
│   ├── migrations/                         # Migraciones up/down
│   ├── queries/                            # Queries para sqlc
│   └── schema/                             # DDL de tablas
│
├── sqldb/                                  # Código generado por sqlc (no editar)
│
├── .air.toml                               # Hot-reload config
├── .env.example                            # Template de variables
├── docker-compose.yml                      # PostgreSQL en Docker
├── Dockerfile                              # (si Docker habilitado) Multi-stage build
├── Makefile                                # Comandos de desarrollo
├── sqlc.yaml                               # Configuración sqlc
└── README.md                               # Documentación en español
```

## Features Opcionales

### JWT Authentication

Cuando habilitas JWT, se genera:

- `pkg/jwt/jwt.go` - Funciones para generar y validar tokens
- `internal/interfaces/http/middleware/auth.go` - Middleware de autenticación
- Variables de entorno: `JWT_SECRET`, `JWT_EXPIRATION`

**Uso:**

```go
// Generar token
token, err := jwt.GenerateToken(userID, email)

// Proteger rutas
authorized := router.Group("/api/v1")
authorized.Use(middleware.AuthMiddleware())
{
    authorized.GET("/profile", handler.GetProfile)
}
```

### Swagger/OpenAPI

Genera documentación automática con [swaggo/swag](https://github.com/swaggo/swag):

```bash
# Generar docs
make swagger

# Acceder
http://localhost:8080/swagger/index.html
```

### CORS Middleware

Configuración flexible de CORS:

```go
// Orígenes permitidos desde .env
CORS_ORIGINS=http://localhost:3000,https://miapp.com
```

### Rate Limiting

Limita peticiones por IP usando token bucket:

```go
// Configuración en .env
RATE_LIMIT=100        # peticiones por minuto
RATE_LIMIT_BURST=10   # ráfaga permitida
```

### Health Checks

Endpoints para Kubernetes/Docker:

- `GET /health` - Liveness check
- `GET /ready` - Readiness check (verifica conexión a BD)

### Structured Logging

Logging con `slog` (stdlib Go 1.21+):

```go
// JSON en producción, texto en desarrollo
LOG_FORMAT=json  # o "text"
LOG_LEVEL=info   # debug, info, warn, error
```

### Docker Multi-stage

Dockerfile optimizado:

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder
# ... compilación

# Runtime stage
FROM alpine:3.18
# Imagen final ~15MB
```

### GitHub Actions CI

Pipeline completo de CI/CD:

**Workflows generados:**

- `.github/workflows/ci.yml` - Lint, Test, Build, Security scan
- `.github/workflows/release.yml` - Build y push de imagen Docker (si Docker habilitado)
- `.github/dependabot.yml` - Actualizaciones automáticas de dependencias

**Jobs del CI:**

| Job | Descripción |
|-----|-------------|
| **lint** | Ejecuta golangci-lint |
| **test** | Tests con PostgreSQL en GitHub Actions |
| **build** | Compila binario y sube artefacto |
| **security** | Escaneo con Gosec |

**Triggers:**

- Push a `main`, `master`, `develop`
- Pull requests a estas ramas
- Tags `v*` para releases

## Makefile - Comandos de Desarrollo

### Generales

| Comando | Descripción |
|---------|-------------|
| `make help` | Muestra todos los comandos |
| `make setup` | Setup completo (tools + db + migrate + sqlc) |
| `make dev` | Servidor con hot-reload |
| `make run` | Ejecutar servidor |
| `make build` | Compilar binario |
| `make test` | Ejecutar tests |
| `make lint` | Ejecutar linter |

### Base de Datos

| Comando | Descripción |
|---------|-------------|
| `make db-create` | Crear base de datos |
| `make db-drop` | Eliminar base de datos |
| `make db-reset` | Drop + Create + Migrate |
| `make docker-up` | Iniciar PostgreSQL en Docker |
| `make docker-down` | Detener contenedores |

### Migraciones

| Comando | Descripción |
|---------|-------------|
| `make migrate-create name=xxx` | Crear nueva migración |
| `make migrate-up` | Aplicar migraciones |
| `make migrate-down` | Revertir última migración |
| `make migrate-version` | Ver versión actual |

### SQLc

| Comando | Descripción |
|---------|-------------|
| `make sqlc-generate` | Generar código Go |
| `make sqlc-verify` | Verificar configuración |

## Arquitectura DDD

### Capas y Responsabilidades

```
┌─────────────────────────────────────────────────────────────────┐
│                    INTERFACES (HTTP/gRPC/CLI)                    │
│  Handlers, Middleware, Response formatting, Input validation    │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                        APPLICATION                               │
│  Services (Use Cases), DTOs, Orquestación de dominio            │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                          DOMAIN                                  │
│  Entities, Repository interfaces, Domain errors, Value objects  │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      INFRASTRUCTURE                              │
│  PostgreSQL repos, External APIs, Config, Persistence           │
└─────────────────────────────────────────────────────────────────┘
```

### Principios

1. **Dependency Inversion** - El dominio no depende de infraestructura
2. **Interface Segregation** - Interfaces pequeñas y específicas
3. **Single Responsibility** - Cada capa tiene un propósito claro
4. **Testability** - Fácil de mockear gracias a interfaces

### Flujo de una Petición

```
HTTP Request
    │
    ▼
Handler (valida input, convierte a DTO)
    │
    ▼
Service (ejecuta caso de uso, lógica de negocio)
    │
    ▼
Repository Interface (definida en domain)
    │
    ▼
Repository Impl (infraestructura, usa sqlc)
    │
    ▼
PostgreSQL
```

## Preguntas Frecuentes

### ¿Cómo migro de la estructura anterior a DDD?

La v2.0 genera proyectos nuevos con estructura DDD. Para proyectos existentes:

1. Genera un proyecto nuevo con v2.0
2. Migra tu lógica de negocio a `internal/domain/`
3. Migra tus servicios a `internal/application/`
4. Adapta tus handlers a `internal/interfaces/http/handler/`

### ¿Puedo usar MySQL en lugar de PostgreSQL?

Actualmente el generador está optimizado para PostgreSQL. Para MySQL:

1. Modifica `sqlc.yaml` (engine: mysql)
2. Cambia las queries SQL (sintaxis MySQL)
3. Actualiza `docker-compose.yml`
4. Modifica el driver en `connection.go`

### ¿Cómo agrego un nuevo endpoint a un módulo existente?

1. Agrega la query en `sql/queries/<modulo>.sql`
2. Ejecuta `make sqlc-generate`
3. Actualiza el repository en `internal/infrastructure/persistence/`
4. Agrega el método en el service `internal/application/<modulo>/`
5. Crea el handler en `internal/interfaces/http/handler/`
6. Registra la ruta en `internal/interfaces/http/router/`

### ¿Cómo ejecuto tests?

```bash
# Todos los tests
make test

# Con coverage
make test-coverage

# Tests de un paquete
go test -v ./internal/application/user/...
```

### ¿Cómo despliego en producción?

```bash
# Con Docker (recomendado)
docker build -t mi-api .
docker run -p 8080:8080 --env-file .env.prod mi-api

# Sin Docker
make build
./bin/api
```

### ¿Puedo personalizar las templates?

Sí, el script `gen-init.sh` contiene todas las templates. Busca las funciones `generate_*` para modificarlas.

## Migración desde v1.x

| v1.x | v2.0 |
|------|------|
| `./gen-init.sh init <module>` | `./gen-init.sh init` (wizard) |
| Estructura flat (`internal/<modulo>/`) | Estructura DDD (`domain/`, `application/`, etc.) |
| Sin features opcionales | JWT, CORS, Rate Limit, etc. |
| Configuración hardcodeada | Wizard interactivo |

## Contribuir

1. Fork el repositorio
2. Crea una rama (`git checkout -b feature/nueva-feature`)
3. Commit tus cambios (`git commit -m 'Agrega nueva feature'`)
4. Push a la rama (`git push origin feature/nueva-feature`)
5. Abre un Pull Request

## Licencia

MIT

---

**Happy Coding! 🚀**
