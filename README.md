# 🚀 Gin API Generator

Generador de proyectos API REST con Go, Gin Framework, sqlc, PostgreSQL y arquitectura limpia. Crea scaffolding completo con best practices, migraciones de base de datos, hot-reload y herramientas de desarrollo profesionales.

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Requisitos Previos](#-requisitos-previos)
- [Instalación](#-instalación)
- [Uso Rápido](#-uso-rápido)
- [Comandos Disponibles](#-comandos-disponibles)
- [Estructura del Proyecto](#-estructura-del-proyecto-generado)
- [Flujo de Trabajo Completo](#-flujo-de-trabajo-completo)
- [Ejemplos Prácticos](#-ejemplos-prácticos)
- [Makefile - Comandos de Desarrollo](#-makefile---comandos-de-desarrollo)
- [Arquitectura](#-arquitectura)
- [Tecnologías Utilizadas](#-tecnologías-utilizadas)
- [FAQ](#-preguntas-frecuentes)

## ✨ Características

- 🏗️ **Clean Architecture** - Separación clara en capas (Controller → Service → Repository → Entity)
- 🔒 **Type-Safe SQL** - Generación de código Go type-safe con **sqlc** desde queries SQL
- 📊 **Migraciones Automáticas** - Control de versiones de base de datos con **golang-migrate** (up/down)
- 🔥 **Hot Reload** - Desarrollo ágil con recarga automática usando **Air**
- 🐳 **Docker Ready** - `docker-compose.yml` incluido para PostgreSQL
- 📦 **Makefile Completo** - Más de 30 comandos para desarrollo, testing y despliegue
- 🎯 **Generación Modular** - Crea nuevos módulos completos con un solo comando
- 🛠️ **Variables de Entorno** - Configuración flexible con `.env` y godotenv
- 🗄️ **PostgreSQL** - Soporte completo para PostgreSQL 13+
- 📝 **Documentación** - README.md detallado generado automáticamente

## 📋 Requisitos del Sistema

### Para usar el generador

| Herramienta | Versión Mínima | Propósito | Instalación |
|-------------|----------------|-----------|-------------|
| **Bash** | 4.0+ | Ejecutar el script generador | Preinstalado en Linux/macOS |
| **Git** | 2.0+ | Control de versiones | [git-scm.com](https://git-scm.com) |

### Para los proyectos generados

| Herramienta | Versión Mínima | Requerido | Propósito | Instalación |
|-------------|----------------|-----------|-----------|-------------|
| **Go** | 1.21+ | ✅ Sí | Lenguaje de programación | [golang.org/dl](https://golang.org/dl/) |
| **PostgreSQL** | 13+ | ✅ Sí | Base de datos | [postgresql.org/download](https://www.postgresql.org/download/) |
| **Make** | 3.8+ | ✅ Sí | Automatización de tareas | Preinstalado en Linux/macOS, Windows: [Chocolatey](https://chocolatey.org/) |
| **sqlc** | 1.20+ | ⚙️ Auto | Generador de código SQL type-safe | Se instala con `make install-tools` |
| **golang-migrate** | 4.15+ | ⚙️ Auto | Gestor de migraciones | Se instala con `make install-tools` |
| **Air** | 1.40+ | ⚙️ Auto | Hot-reload para desarrollo | Se instala con `make install-tools` |
| **Docker** | 20.0+ | 📦 Opcional | PostgreSQL en contenedor | [docker.com](https://www.docker.com/products/docker-desktop) |

> **Nota:** Las herramientas marcadas como "⚙️ Auto" se instalan automáticamente al ejecutar `make setup` o `make install-tools` en el proyecto generado.

### Verificación rápida

```bash
# Verificar Go
go version  # Debe mostrar 1.21 o superior

# Verificar PostgreSQL
psql --version  # Debe mostrar 13 o superior

# Verificar Make
make --version  # Debe mostrar 3.8 o superior

# Verificar Git
git --version
```

## 🚀 Instalación del Generador

```bash
# Clonar el repositorio
git clone https://github.com/eondev-inc/gin-generator.git
cd gin-generator

# Dar permisos de ejecución
chmod +x gen-init.sh

# (Opcional) Instalación global
sudo cp gen-init.sh /usr/local/bin/gin-gen
```

Si instalas globalmente, usa `gin-gen` en lugar de `./gen-init.sh`

## ⚡ Inicio Rápido

### 1. Generar nuevo proyecto

```bash
# Sintaxis
./gen-init.sh init <go_module_name>

# Ejemplo
./gen-init.sh init github.com/miuser/mi-api
```

### 2. Configurar entorno

```bash
cd mi-api

# Copiar variables de entorno
cp .env.example .env

# Editar .env con tus credenciales de PostgreSQL
nano .env  # o usar tu editor preferido
```

**Ejemplo de `.env`:**
```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=tu_password
DB_NAME=mi_api_db
SERVER_PORT=8080
```

### 3. Levantar el proyecto

```bash
# Opción A: Setup completo automatizado (recomendado para primera vez)
make setup
# Instala herramientas (sqlc, migrate, air)
# Crea la base de datos
# Ejecuta migraciones
# Genera código sqlc

# Opción B: Si PostgreSQL está en Docker
make docker-up     # Levanta PostgreSQL en contenedor
make migrate-up    # Ejecuta migraciones
make sqlc-generate # Genera código

# Iniciar servidor con hot-reload
make dev
```

**¡Listo!** Tu API está corriendo en `http://localhost:8080` 🎉

### Verificar que funciona

```bash
# Obtener todos los usuarios
curl http://localhost:8080/api/v1/users

# Crear un usuario
curl -X POST http://localhost:8080/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'
```

## 📚 Comandos Disponibles

### 1. `init` - Crear nuevo proyecto

```bash
./gen-init.sh init <go_module_name>
```

**Descripción:** Inicializa un nuevo proyecto completo con toda la estructura base.

**Ejemplo:**
```bash
./gen-init.sh init github.com/acme/ecommerce-api
```

**Genera:**
- Estructura de carpetas completa
- Módulo Go inicializado
- Módulo de ejemplo (users) con CRUD
- Archivos de configuración
- Makefile con comandos
- Docker Compose para MySQL
- Migraciones iniciales
- README.md del proyecto

### 2. `module` - Agregar nuevo módulo

```bash
./gen-init.sh module <nombre_modulo>
```

**Descripción:** Genera un nuevo módulo dentro del proyecto existente.

**Ejemplo:**
```bash
./gen-init.sh module product
```

**Genera para el módulo:**
```
internal/product/
├── controller/controller.go   # Handlers HTTP
├── dto/create_product_dto.go  # Data Transfer Objects
├── entity/product.go           # Entidad de dominio
├── repository/repository.go    # Capa de datos con sqlc
└── service/service.go          # Lógica de negocio

sql/
├── schema/product.sql          # DDL del schema
├── queries/product.sql         # Queries SQL para sqlc
└── migrations/
    ├── 000002_create_products_table.up.sql
    └── 000002_create_products_table.down.sql
```

**Siguientes pasos:**
```bash
# Regenerar código sqlc
make sqlc-generate

# Aplicar migraciones
make migrate-up

# Registrar rutas en internal/router/router.go
# (Agregar manualmente las rutas del nuevo módulo)
```

### 3. `generate` - Generar código sqlc

```bash
./gen-init.sh generate
```

**Descripción:** Ejecuta `sqlc generate` para crear código Go desde tus queries SQL.

**Cuándo usar:**
- Después de modificar archivos `.sql` en `sql/queries/`
- Después de crear un nuevo módulo
- Después de cambiar `sqlc.yaml`

**Valida:**
- ✅ Que sqlc esté instalado
- ✅ Que exista `sqlc.yaml`
- ✅ Que las queries SQL sean válidas

## 🏗️ Estructura del Proyecto Generado

```
mi-api/
├── cmd/
│   └── api/
│       └── main.go                    # Entry point de la aplicación
│
├── internal/                          # Código privado de la aplicación
│   ├── config/
│   │   └── config.go                  # Configuración (env vars con godotenv)
│   │
│   ├── database/
│   │   └── postgres.go                # Conexión a PostgreSQL
│   │
│   ├── router/
│   │   └── router.go                  # Definición de rutas HTTP
│   │
│   └── user/                          # Módulo de ejemplo
│       ├── controller/
│       │   └── controller.go          # Handlers HTTP (FindAll, FindByID, Create)
│       ├── dto/
│       │   ├── create_user_dto.go     # DTO para crear usuario
│       │   └── update_user_dto.go     # DTO para actualizar usuario
│       ├── entity/
│       │   └── user.go                # Entidad de dominio User
│       ├── repository/
│       │   └── repository.go          # Acceso a datos usando sqlc
│       └── service/
│           └── service.go             # Lógica de negocio
│
├── sql/
│   ├── migrations/                    # Migraciones de base de datos
│   │   ├── 000001_create_users_table.up.sql
│   │   └── 000001_create_users_table.down.sql
│   │
│   ├── queries/                       # Queries SQL para sqlc
│   │   └── user.sql                   # Queries: ListUsers, GetUserByID, etc.
│   │
│   └── schema/                        # Schemas SQL (referencia)
│       └── user.sql                   # DDL de la tabla users
│
├── sqldb/                             # Código generado por sqlc (no editar)
│   ├── db.go
│   ├── models.go
│   ├── querier.go
│   └── user.sql.go
│
├── .devcontainer/                     # 🐳 Configuración DevContainer
│   ├── devcontainer.json              # Config principal
│   ├── Dockerfile                     # Imagen con Go + herramientas
│   ├── docker-compose.yml             # PostgreSQL + app
│   ├── post-create.sh                 # Script setup automático
│   └── README.md                      # Documentación DevContainer
│
├── .air.toml                          # Configuración hot-reload
├── .dockerignore                      # Archivos ignorados en builds
├── .env                               # Variables de entorno (git-ignored)
├── .env.example                       # Template de variables de entorno
├── .gitignore                         # Archivos a ignorar en git
├── docker-compose.yml                 # PostgreSQL en Docker
├── go.mod                             # Dependencias Go
├── go.sum
├── Makefile                           # Comandos de desarrollo
├── README.md                          # Documentación del proyecto
└── sqlc.yaml                          # Configuración de sqlc
```

**Nota:** La carpeta `.devcontainer/` contiene todo lo necesario para desarrollo en cualquier SO usando VS Code + Docker.

## 🔄 Flujo de Trabajo Completo

### 1️⃣ Crear Proyecto Nuevo

```bash
# Crear proyecto
./gen-init.sh init github.com/mycompany/shop-api

# Entrar al directorio
cd shop-api

# Configurar entorno
cp .env.example .env
nano .env  # Editar credenciales
```

**Archivo `.env`:**
```env
DB_USER=root
DB_PASS=tu_password
DB_HOST=localhost
DB_PORT=3306
DB_NAME=shop_db
SERVER_PORT=8080
```

### 2️⃣ Setup Inicial

```bash
# Opción A: Setup automático (recomendado)
make setup
# Esto ejecuta:
# - make install-tools (sqlc, migrate, air)
# - make deps (go mod download)
# - make db-create (crea la BD)
# - make migrate-up (aplica migraciones)
# - make sqlc-generate (genera código)

# Opción B: Manual paso a paso
make install-tools
make deps
make db-create
make migrate-up
make sqlc-generate
```

### 3️⃣ Desarrollo

```bash
# Iniciar con hot-reload (recomendado)
make dev

# O ejecutar directamente
make run

# O compilar y ejecutar
make build
./bin/api
```

### 4️⃣ Probar API

```bash
# Listar usuarios
curl http://localhost:8080/api/users

# Obtener usuario por ID
curl http://localhost:8080/api/users/1

# Crear usuario
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'
```

### 5️⃣ Agregar Nuevo Módulo (Productos)

```bash
# Generar módulo
./gen-init.sh module product

# Regenerar código sqlc
make sqlc-generate

# Aplicar migraciones
make migrate-up
```

**Editar `internal/router/router.go`:**
```go
import (
    // ... imports existentes
    productController "yourmodule/internal/product/controller"
    productRepository "yourmodule/internal/product/repository"
    productService "yourmodule/internal/product/service"
)

func NewRouter(db *sql.DB) *gin.Engine {
    r := gin.Default()

    // ... código existente (users)

    // Agregar módulo de productos
    productRepo := productRepository.NewProductRepository(db)
    productSvc := productService.NewProductService(productRepo)
    productCtrl := productController.NewProductController(productSvc)

    api := r.Group("/api")
    {
        products := api.Group("/products")
        {
            products.GET("", productCtrl.FindAll)
            // Agregar más rutas según necesites
        }
    }

    return r
}
```

### 6️⃣ Personalizar Queries

**Editar `sql/queries/product.sql`:**
```sql
-- name: GetProductsByCategory :many
SELECT id, name, category, price, created_at, updated_at
FROM products
WHERE category = ?
ORDER BY created_at DESC;

-- name: GetProductsInStock :many
SELECT id, name, stock, price
FROM products
WHERE stock > 0;
```

**Regenerar código:**
```bash
make sqlc-generate
```

**Usar en repository:**
```go
func (r *ProductRepository) FindByCategory(ctx context.Context, category string) ([]entity.Product, error) {
    products, err := r.queries.GetProductsByCategory(ctx, category)
    if err != nil {
        return nil, err
    }
    // Convertir y retornar
}
```

## 💡 Ejemplos Prácticos

### Ejemplo 1: Proyecto de Blog

```bash
# Crear proyecto
./gen-init.sh init github.com/myblog/api

cd api
cp .env.example .env
# Editar .env

# Setup
make setup

# Crear módulos
./gen-init.sh module post
./gen-init.sh module comment
./gen-init.sh module category

# Generar código
make sqlc-generate
make migrate-up

# Desarrollar
make dev
```

### Ejemplo 2: E-commerce API

```bash
# Crear proyecto
./gen-init.sh init github.com/myshop/backend-api

cd backend-api

# Usar Docker para MySQL
make docker-up

# Setup
make setup

# Módulos
./gen-init.sh module product
./gen-init.sh module category
./gen-init.sh module order
./gen-init.sh module cart

# Generar todo
make sqlc-generate
make migrate-up
make dev
```

### Ejemplo 3: Agregar Autenticación

```bash
# Crear módulo de autenticación
./gen-init.sh module auth

# Crear migración para tabla de tokens
make migrate-create name=add_auth_tokens_table

# Editar sql/migrations/000002_add_auth_tokens_table.up.sql
# Agregar:
# CREATE TABLE auth_tokens (...)

# Aplicar
make migrate-up

# Desarrollar en sql/queries/auth.sql
# Regenerar
make sqlc-generate
```

## 🛠️ Makefile - Comandos de Desarrollo

### Comandos Generales

| Comando | Descripción |
|---------|-------------|
| `make help` | Muestra todos los comandos disponibles |
| `make setup` | Setup completo del proyecto |
| `make dev` | Inicia servidor con hot-reload |
| `make run` | Ejecuta el servidor |
| `make build` | Compila el binario |
| `make test` | Ejecuta tests |
| `make test-coverage` | Tests con reporte HTML |
| `make clean` | Limpia archivos generados |

### Base de Datos

| Comando | Descripción |
|---------|-------------|
| `make db-create` | Crea la base de datos |
| `make db-drop` | Elimina la BD (¡con confirmación!) |
| `make db-reset` | Drop + Create + Migrate |
| `make db-console` | Abre consola MySQL |

### Migraciones

| Comando | Descripción |
|---------|-------------|
| `make migrate-create name=<nombre>` | Crea nueva migración |
| `make migrate-up` | Aplica todas las migraciones |
| `make migrate-down` | Revierte última migración |
| `make migrate-down-all` | Revierte todas (¡CUIDADO!) |
| `make migrate-force version=N` | Fuerza versión específica |
| `make migrate-version` | Muestra versión actual |

### SQLc

| Comando | Descripción |
|---------|-------------|
| `make sqlc-generate` | Genera código Go desde SQL |
| `make sqlc-verify` | Verifica configuración |

### Docker

| Comando | Descripción |
|---------|-------------|
| `make docker-up` | Inicia MySQL en Docker |
| `make docker-down` | Detiene contenedores |
| `make docker-logs` | Muestra logs |

### Herramientas

| Comando | Descripción |
|---------|-------------|
| `make install-tools` | Instala sqlc, migrate, air |
| `make deps` | Instala dependencias Go |
| `make deps-upgrade` | Actualiza dependencias |
| `make fmt` | Formatea código |
| `make lint` | Ejecuta linter |

### Comandos Combinados

| Comando | Descripción |
|---------|-------------|
| `make reset-all` | Limpia todo y resetea BD |

## 🏛️ Arquitectura

### Capas del Sistema

```
┌─────────────────────────────────────┐
│         HTTP Layer (Gin)            │
│  Controllers (Handlers, Validation) │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│      Business Logic Layer           │
│  Services (Domain Logic, Rules)     │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│       Data Access Layer             │
│  Repositories (sqlc queries)        │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│          Database Layer             │
│        MySQL + Migrations           │
└─────────────────────────────────────┘
```

### Flujo de una Petición

```
1. Request HTTP → Gin Router
2. Router → Controller (valida DTO)
3. Controller → Service (lógica de negocio)
4. Service → Repository (queries sqlc)
5. Repository → Database (MySQL)
6. Database → Repository (resultados)
7. Repository → Service (entities)
8. Service → Controller (entities)
9. Controller → Response JSON
```

### Separación Entity vs Model

- **Entity** (`internal/*/entity/`): Estructuras de dominio, lógica de negocio
- **Model** (generado en `sqldb/`): Estructuras de BD generadas por sqlc
- **DTO** (`internal/*/dto/`): Estructuras para APIs (request/response)

## 🔧 Tecnologías Utilizadas

| Tecnología | Propósito | Documentación |
|------------|-----------|---------------|
| **Go** | Lenguaje de programación | [golang.org](https://golang.org) |
| **Gin** | Framework HTTP/REST | [gin-gonic.com](https://gin-gonic.com) |
| **sqlc** | Generador de código SQL type-safe | [sqlc.dev](https://sqlc.dev) |
| **golang-migrate** | Migraciones de BD | [github.com/golang-migrate](https://github.com/golang-migrate/migrate) |
| **Air** | Hot reload para desarrollo | [github.com/air-verse/air](https://github.com/air-verse/air) |
| **PostgreSQL** | Base de datos relacional | [postgresql.org](https://www.postgresql.org) |
| **godotenv** | Carga variables de entorno desde .env | [github.com/joho/godotenv](https://github.com/joho/godotenv) |
| **Docker** | Containerización (opcional) | [docker.com](https://www.docker.com) |

## ❓ Preguntas Frecuentes

### ¿Cómo cambio el puerto del servidor?

Edita el archivo `.env`:

```env
SERVER_PORT=3000
```

Y actualiza `cmd/api/main.go` para leer esta variable usando `cfg.ServerPort`.

### ¿Las variables de entorno se cargan automáticamente?

Sí. El proyecto generado incluye `github.com/joho/godotenv` que carga automáticamente el archivo `.env` al iniciar la aplicación. Solo necesitas:

1. Copiar `.env.example` a `.env`
2. Editar las variables según tu configuración
3. Ejecutar la aplicación con `make dev` o `make run`

### ¿Cómo uso PostgreSQL en lugar de MySQL?

El generador ya está configurado para PostgreSQL por defecto. Incluye:

- ✅ Engine: `postgresql` en `sqlc.yaml`
- ✅ Driver: `github.com/lib/pq`
- ✅ Conexión: `NewPostgresConnection` en `database/postgres.go`
- ✅ Sintaxis SQL: BIGSERIAL, placeholders $1, $2, etc.
- ✅ Migraciones: Compatible con golang-migrate para PostgreSQL
- ✅ Docker: PostgreSQL 13 en `docker-compose.yml`

Si prefieres MySQL, debes modificar manualmente estos archivos en tu proyecto generado.

### ¿Cómo agrego autenticación JWT?

1. Instala librería: `go get github.com/golang-jwt/jwt/v5`
2. Crea middleware en `internal/middleware/auth.go`
3. Aplica middleware en router para rutas protegidas

### ¿Cómo ejecuto tests?

```bash
# Todos los tests
make test

# Con coverage
make test-coverage

# Test específico
go test -v ./internal/user/service
```

### ¿Qué hago si una migración falla?

```bash
# Ver estado actual
make migrate-version

# Si está "dirty", forzar versión anterior
make migrate-force version=1

# Corregir archivo SQL
# Aplicar de nuevo
make migrate-up
```

### ¿Cómo depliego en producción?

```bash
# 1. Compilar para producción
GOOS=linux GOARCH=amd64 go build -o api ./cmd/api

# 2. Copiar binario al servidor

# 3. Crear .env en servidor

# 4. Aplicar migraciones
migrate -path sql/migrations -database "mysql://..." up

# 5. Ejecutar
./api
```

### ¿Puedo personalizar el generador?

¡Sí! El script `gen-init.sh` es completamente editable. Puedes:

- Cambiar estructura de carpetas
- Modificar templates
- Agregar más dependencias
- Personalizar el Makefile generado

### ¿Cómo uso el DevContainer en el proyecto generado?

El DevContainer está incluido en cada proyecto generado:

```bash
# 1. Genera el proyecto
./gen-init.sh init github.com/user/mi-api
cd mi-api

# 2. Abre en VS Code
code .

# 3. Reabre en Container
# F1 → "Dev Containers: Reopen in Container"

# 4. Espera ~5-10 min (primera vez)

# 5. Una vez dentro:
make setup
make dev
```

**Requisitos:** Docker Desktop + VS Code con extensión "Dev Containers"

### ¿El DevContainer funciona en Windows?

¡Sí! El DevContainer funciona perfectamente en:

- ✅ Windows 10/11 (con WSL2 + Docker Desktop)
- ✅ macOS (Intel y Apple Silicon)
- ✅ Linux (cualquier distribución)

Solo necesitas Docker Desktop y VS Code instalados.

### ¿Qué incluye el DevContainer?

- **Go 1.23** + todas las herramientas (sqlc, migrate, air, golangci-lint)
- **PostgreSQL 16** en contenedor separado
- **Extensiones VS Code** preinstaladas (Go, Docker, SQLTools, GitLens)
- **Zsh + Oh My Zsh** para mejor terminal
- **Docker-in-Docker** para ejecutar contenedores adicionales
- **Configuración automática** con script post-create

Ver documentación completa en `.devcontainer/README.md` de cada proyecto generado.

## 📞 Soporte

Si tienes problemas o sugerencias:
- 🐛 Reporta bugs abriendo un issue
- 💡 Sugiere features vía pull request
- 📖 Consulta la documentación de cada tecnología

## 📄 Licencia

MIT

---

**Happy Coding! 🚀**
