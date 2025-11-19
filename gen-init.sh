#!/usr/bin/env bash

set -e

COMMAND="$1"

if [ -z "$COMMAND" ]; then
  echo "Uso:"
  echo "  $0 init <go_module_name>        # Ej: $0 init github.com/user/mi-api"
  echo "  $0 module <nombre_modulo>       # Ej: $0 module user"
  echo "  $0 generate                     # Genera código sqlc"
  exit 1
fi

# ---------- helpers ----------

get_module_name() {
  if [ -f "go.mod" ]; then
    grep "^module " go.mod | awk '{print $2}'
  else
    echo ""
  fi
}

create_base_structure() {
  echo "📁 Creando estructura de proyecto..."

  mkdir -p cmd/api
  mkdir -p internal/{config,database,router}
  mkdir -p internal/user/{dto,entity,repository,service,controller}
  mkdir -p sql/{schema,queries}
  mkdir -p sqldb
}

create_main_go() {
  local MODULE_NAME="$1"

  cat <<EOF > cmd/api/main.go
package main

import (
	"log"

	"$MODULE_NAME/internal/config"
	"$MODULE_NAME/internal/database"
	"$MODULE_NAME/internal/router"
)

func main() {
	cfg := config.Load()
	db := database.NewPostgresConnection(cfg)
	defer db.Close()

	r := router.NewRouter(db)

	log.Println("🚀 Server running at http://localhost:8080")
	if err := r.Run(":8080"); err != nil {
		log.Fatalf("Error: %v", err)
	}
}
EOF
}

create_config() {
  mkdir -p internal/config

  cat << 'EOF' > internal/config/config.go
package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DBUser string
	DBPass string
	DBHost string
	DBPort string
	DBName string
}

func Load() *Config {
	// Cargar variables de entorno desde .env
	if err := godotenv.Load(); err != nil {
		log.Println("No se encontró archivo .env, usando variables de entorno del sistema")
	}

	cfg := &Config{
		DBUser: os.Getenv("DB_USER"),
		DBPass: os.Getenv("DB_PASS"),
		DBHost: os.Getenv("DB_HOST"),
		DBPort: os.Getenv("DB_PORT"),
		DBName: os.Getenv("DB_NAME"),
	}

	if cfg.DBUser == "" {
		log.Fatal("DB_USER is required")
	}

	return cfg
}

EOF
}

create_sqlc_config() {
  cat << 'EOF' > sqlc.yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "sql/queries"
    schema: "sql/schema"
    gen:
      go:
        package: "sqldb"
        out: "sqldb"
        emit_json_tags: true
        emit_prepared_queries: false
        emit_interface: true
        emit_exact_table_names: false
        emit_empty_slices: true
EOF
}

create_makefile() {
  local MODULE_NAME="$1"
  
  cat <<'EOF' > Makefile
.PHONY: help install-tools dev build run test clean sqlc-generate migrate-up migrate-down migrate-create migrate-force db-create db-drop db-reset

# Shell
SHELL := /bin/bash
export PATH := $(HOME)/go/bin:$(PATH)

# Variables
DB_HOST ?= localhost
DB_PORT ?= 5432
DB_USER ?= testuser
DB_PASS ?= .sweetpwd.
DB_NAME ?= testdb
MIGRATE_VERSION ?= latest

# Colors para output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
RESET := \033[0m

help: ## Muestra esta ayuda
	@echo -e "$(BLUE)Comandos disponibles:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'

install-tools: ## Instala herramientas necesarias (sqlc, migrate, air)
	@echo -e "$(BLUE)Instalando herramientas...$(RESET)"
	@command -v go >/dev/null 2>&1 || { echo -e "$(RED)Error: Go no está instalado o no está en PATH$(RESET)"; exit 1; }
	@echo -e "$(BLUE)Instalando sqlc...$(RESET)"
	@go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest || { echo -e "$(RED)Error instalando sqlc$(RESET)"; exit 1; }
	@echo -e "$(BLUE)Instalando golang-migrate...$(RESET)"
	@go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest || { echo -e "$(RED)Error instalando migrate$(RESET)"; exit 1; }
	@echo -e "$(BLUE)Instalando air...$(RESET)"
	@go install github.com/air-verse/air@latest || { echo -e "$(RED)Error instalando air$(RESET)"; exit 1; }
	@echo -e "$(GREEN)✓ Herramientas instaladas$(RESET)"

dev: ## Inicia el servidor en modo desarrollo con hot-reload
	@echo -e "$(BLUE)Iniciando servidor en modo desarrollo...$(RESET)"
	@air

build: ## Compila el proyecto
	@echo -e "$(BLUE)Compilando proyecto...$(RESET)"
	@command -v go >/dev/null 2>&1 || { echo -e "$(RED)Error: Go no está instalado$(RESET)"; exit 1; }
	@go build -o bin/api ./cmd/api
	@echo -e "$(GREEN)✓ Compilación exitosa: bin/api$(RESET)"

run: ## Ejecuta el proyecto
	@echo -e "$(BLUE)Ejecutando proyecto...$(RESET)"
	@command -v go >/dev/null 2>&1 || { echo -e "$(RED)Error: Go no está instalado$(RESET)"; exit 1; }
	@go run ./cmd/api

test: ## Ejecuta los tests
	@echo -e "$(BLUE)Ejecutando tests...$(RESET)"
	@command -v go >/dev/null 2>&1 || { echo -e "$(RED)Error: Go no está instalado$(RESET)"; exit 1; }
	@go test -v ./...

test-coverage: ## Ejecuta tests con coverage
	@echo -e "$(BLUE)Ejecutando tests con coverage...$(RESET)"
	@command -v go >/dev/null 2>&1 || { echo -e "$(RED)Error: Go no está instalado$(RESET)"; exit 1; }
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo -e "$(GREEN)✓ Coverage generado: coverage.html$(RESET)"

clean: ## Limpia archivos generados
	@echo -e "$(YELLOW)Limpiando archivos generados...$(RESET)"
	@rm -rf bin/ coverage.out coverage.html
	@echo -e "$(GREEN)✓ Limpieza completada$(RESET)"

# --- SQLc ---

sqlc-generate: ## Genera código Go desde queries SQL
	@echo -e "$(BLUE)Generando código sqlc...$(RESET)"
	@command -v sqlc >/dev/null 2>&1 || { echo -e "$(RED)Error: sqlc no está instalado. Ejecuta: make install-tools$(RESET)"; exit 1; }
	@sqlc generate
	@echo -e "$(GREEN)✓ Código generado en sqldb/$(RESET)"

sqlc-verify: ## Verifica la configuración de sqlc
	@echo -e "$(BLUE)Verificando sqlc...$(RESET)"
	@command -v sqlc >/dev/null 2>&1 || { echo -e "$(RED)Error: sqlc no está instalado. Ejecuta: make install-tools$(RESET)"; exit 1; }
	@sqlc verify

# --- Migraciones ---

MIGRATE_DSN := "postgres://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=disable"

migrate-create: ## Crea una nueva migración (uso: make migrate-create name=add_users_table)
	@command -v migrate >/dev/null 2>&1 || { echo "$(RED)Error: migrate no está instalado. Ejecuta: make install-tools$(RESET)"; exit 1; }
	@if [ -z "$(name)" ]; then \
		echo -e "$(RED)Error: Debes especificar un nombre$(RESET)"; \
		echo "Uso: make migrate-create name=add_users_table"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)Creando migración: $(name)$(RESET)"
	@mkdir -p sql/migrations
	@migrate create -ext sql -dir sql/migrations -seq $(name)
	@echo -e "$(GREEN)✓ Migración creada en sql/migrations/$(RESET)"

migrate-up: ## Ejecuta todas las migraciones pendientes
	@echo -e "$(BLUE)Ejecutando migraciones...$(RESET)"
	@command -v migrate >/dev/null 2>&1 || { echo -e "$(RED)Error: migrate no está instalado. Ejecuta: make install-tools$(RESET)"; exit 1; }
	@migrate -path sql/migrations -database $(MIGRATE_DSN) up
	@echo -e "$(GREEN)✓ Migraciones aplicadas$(RESET)"

migrate-down: ## Revierte la última migración
	@echo -e "$(YELLOW)Revirtiendo última migración...$(RESET)"
	@command -v migrate >/dev/null 2>&1 || { echo -e "$(RED)Error: migrate no está instalado. Ejecuta: make install-tools$(RESET)"; exit 1; }
	@migrate -path sql/migrations -database $(MIGRATE_DSN) down 1
	@echo -e "$(GREEN)✓ Migración revertida$(RESET)"

migrate-down-all: ## Revierte TODAS las migraciones (¡CUIDADO!)
	@echo -e "$(RED)⚠️  ADVERTENCIA: Esto revertirá TODAS las migraciones$(RESET)"
	@command -v migrate >/dev/null 2>&1 || { echo -e "$(RED)Error: migrate no está instalado. Ejecuta: make install-tools$(RESET)"; exit 1; }
	@read -p "¿Estás seguro? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@migrate -path sql/migrations -database $(MIGRATE_DSN) down -all
	@echo -e "$(GREEN)✓ Todas las migraciones revertidas$(RESET)"

migrate-force: ## Fuerza la versión de migración (uso: make migrate-force version=2)
	@command -v migrate >/dev/null 2>&1 || { echo "$(RED)Error: migrate no está instalado. Ejecuta: make install-tools$(RESET)"; exit 1; }
	@if [ -z "$(version)" ]; then \
		echo -e "$(RED)Error: Debes especificar una versión$(RESET)"; \
		echo "Uso: make migrate-force version=2"; \
		exit 1; \
	fi
	@echo -e "$(YELLOW)Forzando versión de migración a: $(version)$(RESET)"
	@migrate -path sql/migrations -database $(MIGRATE_DSN) force $(version)
	@echo -e "$(GREEN)✓ Versión forzada$(RESET)"

migrate-version: ## Muestra la versión actual de las migraciones
	@echo -e "$(BLUE)Versión actual de migraciones:$(RESET)"
	@command -v migrate >/dev/null 2>&1 || { echo -e "$(RED)Error: migrate no está instalado. Ejecuta: make install-tools$(RESET)"; exit 1; }
	@migrate -path sql/migrations -database $(MIGRATE_DSN) version

migrate-status: ## Alias para migrate-version
	@make migrate-version

# --- Base de datos ---

db-create: ## Crea la base de datos
	@echo -e "$(BLUE)Creando base de datos $(DB_NAME)...$(RESET)"
	@command -v psql >/dev/null 2>&1 || { echo -e "$(RED)Error: psql (PostgreSQL client) no está instalado$(RESET)"; exit 1; }
	@PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres -c "CREATE DATABASE $(DB_NAME);" 2>/dev/null || echo "Database already exists"
	@echo -e "$(GREEN)✓ Base de datos creada$(RESET)"

db-drop: ## Elimina la base de datos (¡CUIDADO!)
	@echo -e "$(RED)⚠️  ADVERTENCIA: Esto eliminará la base de datos $(DB_NAME)$(RESET)"
	@command -v psql >/dev/null 2>&1 || { echo -e "$(RED)Error: psql (PostgreSQL client) no está instalado$(RESET)"; exit 1; }
	@read -p "¿Estás seguro? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres -c "DROP DATABASE IF EXISTS $(DB_NAME);"
	@echo -e "$(GREEN)✓ Base de datos eliminada$(RESET)"

db-reset: db-drop db-create migrate-up ## Resetea la base de datos y ejecuta migraciones
	@echo -e "$(GREEN)✓ Base de datos reseteada$(RESET)"

db-console: ## Abre consola PostgreSQL
	@echo -e "$(BLUE)Abriendo consola PostgreSQL...$(RESET)"
	@command -v psql >/dev/null 2>&1 || { echo -e "$(RED)Error: psql (PostgreSQL client) no está instalado$(RESET)"; exit 1; }
	@PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)

# --- Dependencias ---

deps: ## Instala/actualiza dependencias de Go
	@echo -e "$(BLUE)Instalando dependencias...$(RESET)"
	@command -v go >/dev/null 2>&1 || { echo -e "$(RED)Error: Go no está instalado$(RESET)"; exit 1; }
	@go mod download
	@go mod tidy
	@echo -e "$(GREEN)✓ Dependencias actualizadas$(RESET)"

deps-upgrade: ## Actualiza todas las dependencias
	@echo -e "$(BLUE)Actualizando dependencias...$(RESET)"
	@command -v go >/dev/null 2>&1 || { echo -e "$(RED)Error: Go no está instalado$(RESET)"; exit 1; }
	@go get -u ./...
	@go mod tidy
	@echo -e "$(GREEN)✓ Dependencias actualizadas$(RESET)"

# --- Docker (opcional) ---

docker-up: ## Inicia contenedores Docker
	@echo -e "$(BLUE)Iniciando contenedores...$(RESET)"
	@docker compose up -d
	@echo -e "$(GREEN)✓ Contenedores iniciados$(RESET)"

docker-down: ## Detiene contenedores Docker
	@echo -e "$(YELLOW)Deteniendo contenedores...$(RESET)"
	@docker compose down
	@echo -e "$(GREEN)✓ Contenedores detenidos$(RESET)"

docker-logs: ## Muestra logs de contenedores
	@docker compose logs -f

# --- Linting y formato ---

fmt: ## Formatea el código
	@echo -e "$(BLUE)Formateando código...$(RESET)"
	@command -v go >/dev/null 2>&1 || { echo -e "$(RED)Error: Go no está instalado$(RESET)"; exit 1; }
	@go fmt ./...
	@echo -e "$(GREEN)✓ Código formateado$(RESET)"

lint: ## Ejecuta el linter (requiere golangci-lint)
	@echo -e "$(BLUE)Ejecutando linter...$(RESET)"
	@golangci-lint run ./...

# --- Comandos de desarrollo rápido ---

setup: install-tools sqlc-generate deps db-create migrate-up ## Setup completo del proyecto
	@echo -e "$(GREEN)✓ Proyecto configurado completamente$(RESET)"
	@echo -e "$(BLUE)Ejecuta 'make dev' para iniciar el servidor$(RESET)"

reset-all: clean db-reset sqlc-generate ## Resetea todo (BD + archivos generados)
	@echo -e "$(GREEN)✓ Reset completo realizado$(RESET)"
EOF
}

create_air_config() {
  cat <<'EOF' > .air.toml
root = "."
testdata_dir = "testdata"
tmp_dir = "tmp"

[build]
  args_bin = []
  bin = "./tmp/main"
  cmd = "go build -o ./tmp/main ./cmd/api"
  delay = 1000
  exclude_dir = ["assets", "tmp", "vendor", "testdata", "sqldb"]
  exclude_file = []
  exclude_regex = ["_test.go"]
  exclude_unchanged = false
  follow_symlink = false
  full_bin = ""
  include_dir = []
  include_ext = ["go", "tpl", "tmpl", "html"]
  include_file = []
  kill_delay = "0s"
  log = "build-errors.log"
  poll = false
  poll_interval = 0
  rerun = false
  rerun_delay = 500
  send_interrupt = false
  stop_on_error = false

[color]
  app = ""
  build = "yellow"
  main = "magenta"
  runner = "green"
  watcher = "cyan"

[log]
  main_only = false
  time = false

[misc]
  clean_on_exit = false

[screen]
  clear_on_rebuild = false
  keep_scroll = true
EOF
}

create_env_example() {
  cat <<'EOF' > .env.example
# Database Configuration
DB_USER=testuser
DB_PASS=mysuperpwd.
DB_HOST=localhost
DB_PORT=5432
DB_NAME=testdb

# Server Configuration
SERVER_PORT=8080
EOF
}

create_gitignore() {
  cat <<'EOF' > .gitignore
# Binaries
bin/
tmp/
*.exe
*.exe~
*.dll
*.so
*.dylib

# Test and coverage
*.test
*.out
coverage.html
coverage.out

# Go workspace file
go.work

# Environment variables
.env

# IDE
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store

# Air
build-errors.log
EOF
}

create_docker_compose() {
  cat <<'EOF' > docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:13
    container_name: test_postgres
    environment:
      POSTGRES_DB: testdb
	  POSTGRES_USER: testuser
	  POSTGRES_PASSWORD: mysuperpwd.
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "testuser"]
      timeout: 20s
      retries: 10

volumes:
  postgres_data:
EOF
}

create_readme() {
  local MODULE_NAME="$1"
  
  cat <<EOF > README.md
# $MODULE_NAME

Proyecto API REST con Go, Gin y sqlc.

## 🚀 Quick Start

### Requisitos previos

- Go 1.21+
- PostgreSQL 13+
- Make

### Instalación

\`\`\`bash
# 1. Clonar el repositorio
git clone <tu-repo>
cd <tu-proyecto>

# 2. Copiar variables de entorno
cp .env.example .env
# Edita .env con tus credenciales

# 3. Setup completo (instala herramientas, crea BD, ejecuta migraciones)
make setup

# 4. Iniciar servidor en modo desarrollo
make dev
\`\`\`

## 📋 Comandos Disponibles

\`\`\`bash
make help              # Muestra todos los comandos disponibles
\`\`\`

### Desarrollo

\`\`\`bash
make dev               # Inicia servidor con hot-reload
make run               # Ejecuta el servidor
make build             # Compila el proyecto
make test              # Ejecuta tests
make fmt               # Formatea código
\`\`\`

### Base de Datos

\`\`\`bash
make db-create         # Crea la base de datos
make db-drop           # Elimina la base de datos
make db-reset          # Resetea BD y ejecuta migraciones
make db-console        # Abre consola PostgreSQL
\`\`\`

### Migraciones

\`\`\`bash
make migrate-create name=add_users_table  # Crea nueva migración
make migrate-up                           # Aplica migraciones
make migrate-down                         # Revierte última migración
make migrate-version                      # Muestra versión actual
\`\`\`

### SQLc

\`\`\`bash
make sqlc-generate     # Genera código Go desde SQL
\`\`\`

## 🏗️ Estructura del Proyecto

\`\`\`
.
├── cmd/api/              # Entry point
├── internal/
│   ├── config/          # Configuración
│   ├── database/        # Conexión a BD
│   ├── router/          # Rutas HTTP
│   └── user/            # Módulo de ejemplo
│       ├── controller/  # Handlers HTTP
│       ├── dto/         # Data Transfer Objects
│       ├── entity/      # Entidades de dominio
│       ├── repository/  # Capa de datos
│       └── service/     # Lógica de negocio
├── sql/
│   ├── migrations/      # Migraciones de BD
│   ├── queries/         # Queries SQL para sqlc
│   └── schema/          # Schemas SQL
├── sqldb/               # Código generado por sqlc
├── Makefile             # Comandos útiles
├── sqlc.yaml            # Configuración sqlc
└── .air.toml            # Configuración hot-reload
\`\`\`

## 🔧 Tecnologías

- **Go** - Lenguaje de programación
- **Gin** - Framework HTTP
- **sqlc** - Generador de código type-safe SQL
- **golang-migrate** - Migraciones de BD
- **PostgreSQL** - Base de datos
- **Air** - Hot reload para desarrollo

## 📝 Flujo de Desarrollo

### Agregar un nuevo módulo

\`\`\`bash
# 1. Generar estructura del módulo
./gen-init.sh module product

# 2. Editar SQL queries en sql/queries/product.sql

# 3. Regenerar código sqlc
make sqlc-generate

# 4. Crear migración
make migrate-create name=add_products_table

# 5. Editar archivo de migración en sql/migrations/

# 6. Aplicar migración
make migrate-up

# 7. Registrar rutas en internal/router/router.go
\`\`\`

## 🐳 Docker

\`\`\`bash
make docker-up         # Inicia PostgreSQL en Docker
make docker-down       # Detiene contenedores
make docker-logs       # Muestra logs
\`\`\`

## 📄 Licencia

MIT
EOF
}

create_database_postgres() {
  local MODULE_NAME="$1"
  mkdir -p internal/database

  cat <<EOF > internal/database/postgres.go
package database

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/lib/pq"

	"$MODULE_NAME/internal/config"
)

func NewPostgresConnection(cfg *config.Config) *sql.DB {
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		cfg.DBHost,
		cfg.DBPort,
		cfg.DBUser,
		cfg.DBPass,
		cfg.DBName,
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Error abriendo la BD: %v", err)
	}

	if err := db.Ping(); err != nil {
		log.Fatalf("Error conectando BD: %v", err)
	}

	return db
}
EOF
}

create_router() {
  local MODULE_NAME="$1"
  mkdir -p internal/router

  cat <<EOF > internal/router/router.go
package router

import (
	"database/sql"

	"github.com/gin-gonic/gin"

	userController "github.com/eondev/nexus-sanitas-api-v2/internal/user/controller"
	userRepository "github.com/eondev/nexus-sanitas-api-v2/internal/user/repository"
	userService "github.com/eondev/nexus-sanitas-api-v2/internal/user/service"
)

func NewRouter(db *sql.DB) *gin.Engine {
	r := gin.Default()

	userRep := userRepository.NewUserRepository(db)
	userSvc := userService.NewUserService(userRep)
	userCon := userController.NewUserController(userSvc)

	api := r.Group("/api")
	{
		users := api.Group("/users")
		{
			users.GET("", userCon.FindAll)
			users.GET("/:id", userCon.FindByID)
			users.POST("", userCon.Create)
		}
	}

	return r
}
EOF
}

create_user_sql_schema() {
  cat << 'EOF' > sql/schema/user.sql
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
}

create_initial_migration() {
  mkdir -p sql/migrations
  
  # Crear archivo de migracion UP
  cat << 'EOF' > sql/migrations/000001_create_users_table.up.sql
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
EOF

  # Crear archivo de migracion DOWN
  cat << 'EOF' > sql/migrations/000001_create_users_table.down.sql
DROP TABLE IF EXISTS users;
EOF
}

create_user_sql_queries() {
  cat << 'EOF' > sql/queries/user.sql
-- name: ListUsers :many
SELECT id, name, email, created_at, updated_at
FROM users
ORDER BY id;

-- name: GetUserByID :one
SELECT id, name, email, created_at, updated_at
FROM users
WHERE id = $1;

-- name: CreateUser :one
INSERT INTO users (name, email, created_at, updated_at)
VALUES ($1, $2, $3, $4)
RETURNING id, name, email, created_at, updated_at;

-- name: UpdateUser :exec
UPDATE users
SET name = $1, email = $2, updated_at = $3
WHERE id = $4;

-- name: DeleteUser :exec
DELETE FROM users
WHERE id = $1;
EOF
}

create_module_structure() {
  local MODULE="$1"
  mkdir -p "internal/$MODULE"/{dto,entity,repository,service,controller}
}

create_user_sample_module() {
  local MODULE_NAME="$1"
  local MOD_DIR="internal/user"

  mkdir -p "$MOD_DIR"/{dto,entity,repository,service,controller}

  # DTOs
  cat << 'EOF' > "$MOD_DIR/dto/create_user_dto.go"
package dto

type CreateUserDTO struct {
	Name  string `json:"name" binding:"required"`
	Email string `json:"email" binding:"required,email"`
}
EOF

  cat << 'EOF' > "$MOD_DIR/dto/update_user_dto.go"
package dto

type UpdateUserDTO struct {
	Name  *string `json:"name,omitempty"`
	Email *string `json:"email,omitempty"`
}
EOF

  # Entity
  cat << 'EOF' > "$MOD_DIR/entity/user.go"
package entity

import "time"

type User struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
EOF

  # Repository with sqlc
  cat <<EOF > "$MOD_DIR/repository/repository.go"
package repository

import (
	"context"
	"database/sql"

	"github.com/eondev/nexus-sanitas-api-v2/internal/user/entity"
	"github.com/eondev/nexus-sanitas-api-v2/sqldb"
)

type UserRepository interface {
	FindAll(ctx context.Context) ([]entity.User, error)
	FindByID(ctx context.Context, id int64) (*entity.User, error)
	Create(ctx context.Context, u *entity.User) error
}

type userRepository struct {
	queries *sqldb.Queries
}

func NewUserRepository(db *sql.DB) UserRepository {
	return &userRepository{
		queries: sqldb.New(db),
	}
}

func (r *userRepository) FindAll(ctx context.Context) ([]entity.User, error) {
	users, err := r.queries.ListUsers(ctx)
	if err != nil {
		return nil, err
	}

	// Convertir de sqldb.User a entity.User
	result := make([]entity.User, len(users))
	for i, u := range users {
		result[i] = entity.User{
			ID:        u.ID,
			Name:      u.Name,
			Email:     u.Email,
			CreatedAt: u.CreatedAt.Time,
			UpdatedAt: u.UpdatedAt.Time,
		}
	}

	return result, nil
}

func (r *userRepository) FindByID(ctx context.Context, id int64) (*entity.User, error) {
	u, err := r.queries.GetUserByID(ctx, id)
	if err != nil {
		return nil, err
	}

	return &entity.User{
		ID:        u.ID,
		Name:      u.Name,
		Email:     u.Email,
		CreatedAt: u.CreatedAt.Time,
		UpdatedAt: u.UpdatedAt.Time,
	}, nil
}

func (r *userRepository) Create(ctx context.Context, u *entity.User) error {
	created, err := r.queries.CreateUser(ctx, sqldb.CreateUserParams{
		Name:      u.Name,
		Email:     u.Email,
		CreatedAt: sql.NullTime{Time: u.CreatedAt, Valid: true},
		UpdatedAt: sql.NullTime{Time: u.UpdatedAt, Valid: true},
	})
	if err != nil {
		return err
	}

	// Actualizar el ID del usuario creado
	u.ID = created.ID
	return nil
}
EOF

  # Service
  cat <<EOF > "$MOD_DIR/service/service.go"
package service

import (
	"context"
	"time"

	"$MODULE_NAME/internal/user/dto"
	"$MODULE_NAME/internal/user/entity"
	"$MODULE_NAME/internal/user/repository"
)

type UserService interface {
	FindAll(ctx context.Context) ([]entity.User, error)
	FindByID(ctx context.Context, id int64) (*entity.User, error)
	Create(ctx context.Context, data *dto.CreateUserDTO) (*entity.User, error)
}

type userService struct {
	repo repository.UserRepository
}

func NewUserService(repo repository.UserRepository) UserService {
	return &userService{repo: repo}
}

func (s *userService) FindAll(ctx context.Context) ([]entity.User, error) {
	return s.repo.FindAll(ctx)
}

func (s *userService) FindByID(ctx context.Context, id int64) (*entity.User, error) {
	return s.repo.FindByID(ctx, id)
}

func (s *userService) Create(ctx context.Context, data *dto.CreateUserDTO) (*entity.User, error) {
	now := time.Now()

	user := &entity.User{
		Name:      data.Name,
		Email:     data.Email,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := s.repo.Create(ctx, user); err != nil {
		return nil, err
	}

	return user, nil
}
EOF

  # Controller
  cat <<EOF > "$MOD_DIR/controller/controller.go"
package controller

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"$MODULE_NAME/internal/user/dto"
	"$MODULE_NAME/internal/user/service"
)

type UserController struct {
	svc service.UserService
}

func NewUserController(svc service.UserService) *UserController {
	return &UserController{svc: svc}
}

func (c *UserController) FindAll(ctx *gin.Context) {
	users, err := c.svc.FindAll(ctx)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, users)
}

func (c *UserController) FindByID(ctx *gin.Context) {
	idStr := ctx.Param("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	user, err := c.svc.FindByID(ctx, id)
	if err != nil {
		ctx.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}

	ctx.JSON(http.StatusOK, user)
}

func (c *UserController) Create(ctx *gin.Context) {
	var body dto.CreateUserDTO
	if err := ctx.ShouldBindJSON(&body); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, err := c.svc.Create(ctx, &body)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	ctx.JSON(http.StatusCreated, user)
}
EOF
}

create_module_sql_schema() {
  local MOD="$1"
  
  cat <<EOF > "sql/schema/${MOD}.sql"
CREATE TABLE IF NOT EXISTS ${MOD}s (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
}

create_module_migration() {
  local MOD="$1"
  
  # Encontrar el siguiente número de migración
  local NEXT_NUM="000001"
  if [ -d "sql/migrations" ]; then
    local LAST_FILE=$(ls sql/migrations/*.up.sql 2>/dev/null | tail -1)
    if [ -n "$LAST_FILE" ]; then
      local LAST_NUM=$(basename "$LAST_FILE" | cut -d'_' -f1)
      NEXT_NUM=$(printf "%06d" $((10#$LAST_NUM + 1)))
    fi
  fi
  
  mkdir -p sql/migrations
  
  # Crear archivo UP
  cat <<EOF > "sql/migrations/${NEXT_NUM}_create_${MOD}s_table.up.sql"
CREATE TABLE IF NOT EXISTS ${MOD}s (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_${MOD}s_name ON ${MOD}s(name);
EOF

  # Crear archivo DOWN
  cat <<EOF > "sql/migrations/${NEXT_NUM}_create_${MOD}s_table.down.sql"
DROP TABLE IF EXISTS ${MOD}s;
EOF
}

create_module_sql_queries() {
  local MOD="$1"
  
  cat <<EOF > "sql/queries/${MOD}.sql"
-- name: List${MOD^}s :many
SELECT id, name, created_at, updated_at
FROM ${MOD}s
ORDER BY id;

-- name: Get${MOD^}ByID :one
SELECT id, name, created_at, updated_at
FROM ${MOD}s
WHERE id = \$1;

-- name: Create${MOD^} :one
INSERT INTO ${MOD}s (name, created_at, updated_at)
VALUES (\$1, \$2, \$3)
RETURNING id, name, created_at, updated_at;

-- name: Update${MOD^} :exec
UPDATE ${MOD}s
SET name = \$1, updated_at = \$2
WHERE id = \$3;

-- name: Delete${MOD^} :exec
DELETE FROM ${MOD}s
WHERE id = \$1;
EOF
}

create_generic_module() {
  local MOD="$1"
  local MODULE_NAME
  MODULE_NAME=$(get_module_name)

  if [ -z "$MODULE_NAME" ]; then
    echo "No se pudo detectar module name desde go.mod"
    exit 1
  fi

  local MOD_DIR="internal/$MOD"
  mkdir -p "$MOD_DIR"/{dto,entity,repository,service,controller}

  # DTO simple
  cat <<EOF > "$MOD_DIR/dto/create_${MOD}_dto.go"
package dto

type Create${MOD^}DTO struct {
	Name string \`json:"name" binding:"required"\`
}
EOF

  # Entity simple
  cat <<EOF > "$MOD_DIR/entity/${MOD}.go"
package entity

import "time"

type ${MOD^} struct {
	ID        int64     \`json:"id"\`
	Name      string    \`json:"name"\`
	CreatedAt time.Time \`json:"created_at"\`
	UpdatedAt time.Time \`json:"updated_at"\`
}
EOF

  # Repository with sqlc
  cat <<EOF > "$MOD_DIR/repository/repository.go"
package repository

import (
	"context"
	"database/sql"

	"$MODULE_NAME/internal/$MOD/entity"
	"$MODULE_NAME/sqldb"
)

type ${MOD^}Repository interface {
	FindAll(ctx context.Context) ([]entity.${MOD^}, error)
}

type ${MOD}Repository struct {
	queries *sqldb.Queries
}

func New${MOD^}Repository(db *sql.DB) ${MOD^}Repository {
	return &${MOD}Repository{
		queries: sqldb.New(db),
	}
}

func (r *${MOD}Repository) FindAll(ctx context.Context) ([]entity.${MOD^}, error) {
	items, err := r.queries.List${MOD^}s(ctx)
	if err != nil {
		return nil, err
	}

	// Convertir de sqldb.${MOD^} a entity.${MOD^}
	result := make([]entity.${MOD^}, len(items))
	for i, it := range items {
		result[i] = entity.${MOD^}{
			ID:        it.ID,
			Name:      it.Name,
			CreatedAt: it.CreatedAt,
			UpdatedAt: it.UpdatedAt,
		}
	}

	return result, nil
}
EOF

  # Service
  cat <<EOF > "$MOD_DIR/service/service.go"
package service

import (
	"context"

	"$MODULE_NAME/internal/$MOD/entity"
	"$MODULE_NAME/internal/$MOD/repository"
)

type ${MOD^}Service interface {
	FindAll(ctx context.Context) ([]entity.${MOD^}, error)
}

type ${MOD}Service struct {
	repo repository.${MOD^}Repository
}

func New${MOD^}Service(repo repository.${MOD^}Repository) ${MOD^}Service {
	return &${MOD}Service{repo: repo}
}

func (s *${MOD}Service) FindAll(ctx context.Context) ([]entity.${MOD^}, error) {
	return s.repo.FindAll(ctx)
}
EOF

  # Controller
  cat <<EOF > "$MOD_DIR/controller/controller.go"
package controller

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"$MODULE_NAME/internal/$MOD/service"
)

type ${MOD^}Controller struct {
	svc service.${MOD^}Service
}

func New${MOD^}Controller(svc service.${MOD^}Service) *${MOD^}Controller {
	return &${MOD^}Controller{svc: svc}
}

func (c *${MOD^}Controller) FindAll(ctx *gin.Context) {
	items, err := c.svc.FindAll(ctx)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, items)
}
EOF

  echo "✅ Módulo '$MOD' creado en internal/$MOD (recuerda agregar sus rutas en internal/router/router.go)"
}

# ---------- comandos ----------

case "$COMMAND" in
  init)
    MODULE_NAME="$2"
    if [ -z "$MODULE_NAME" ]; then
      echo "Uso: $0 init <go_module_name>"
      exit 1
    fi

    echo "🧪 Inicializando proyecto con módulo Go: $MODULE_NAME"

    go mod init "$MODULE_NAME"
    go get github.com/gin-gonic/gin
    go get github.com/lib/pq
    go get github.com/joho/godotenv

    create_base_structure
    create_sqlc_config
    create_makefile "$MODULE_NAME"
    create_air_config
    create_env_example
    create_gitignore
    create_docker_compose
    create_readme "$MODULE_NAME"
    create_user_sql_schema
    create_initial_migration
    create_user_sql_queries
    create_main_go "$MODULE_NAME"
    create_config
    create_database_postgres "$MODULE_NAME"
    create_router "$MODULE_NAME"
    create_user_sample_module "$MODULE_NAME"

    echo ""
    echo "✨ Proyecto base creado con sqlc!"
    echo ""
    echo "🐳 DevContainer configurado - Desarrollo en cualquier SO"
    echo ""
    echo "📋 Próximos pasos:"
    echo ""
    echo "  Opción A - DevContainer (Recomendado):"
    echo "    1. Abre el proyecto en VS Code"
    echo "    2. F1 → 'Dev Containers: Reopen in Container'"
    echo "    3. Espera construcción (~5-10 min primera vez)"
    echo "    4. make setup && make dev"
    echo ""
    echo "  Opción B - Local:"
    echo "    1. Configura .env: cp .env.example .env (y edítalo)"
    echo "    2. Setup completo: make setup"
    echo "    3. Inicia desarrollo: make dev"
    echo ""
    echo "📚 Comandos útiles:"
    echo "  make help              → Ver todos los comandos"
    echo "  make sqlc-generate     → Generar código sqlc"
    echo "  make migrate-up        → Aplicar migraciones"
    echo "  make docker-up         → Iniciar PostgreSQL en Docker"
    echo ""
    echo "📁 Archivos creados:"
    echo "  - Makefile           → Comandos de desarrollo"
    echo "  - .air.toml          → Configuración hot-reload"
    echo "  - .env.example       → Variables de entorno"
    echo "  - docker-compose.yml → PostgreSQL en Docker"
    echo "  - README.md          → Documentación"
    ;;

  module)
    MOD_NAME="$2"
    if [ -z "$MOD_NAME" ]; then
      echo "Uso: $0 module <nombre_modulo>"
      exit 1
    fi

    echo "🧪 Creando módulo: $MOD_NAME"
    create_module_sql_schema "$MOD_NAME"
    create_module_migration "$MOD_NAME"
    create_module_sql_queries "$MOD_NAME"
    create_generic_module "$MOD_NAME"
    echo ""
    echo "✅ Módulo '$MOD_NAME' creado"
    echo "📋 Próximos pasos:"
    echo "  1. Regenera código sqlc: $0 generate"
    echo "  2. Registra las rutas en internal/router/router.go"
    ;;

  generate)
    echo "🔄 Generando código sqlc..."
    
    if ! command -v sqlc &> /dev/null; then
      echo "❌ sqlc no está instalado"
      echo "Instálalo con: go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest"
      exit 1
    fi

    if [ ! -f "sqlc.yaml" ]; then
      echo "❌ No se encontró sqlc.yaml"
      echo "Ejecuta primero: $0 init <module_name>"
      exit 1
    fi

    sqlc generate
    
    echo "✅ Código generado en sqldb/"
    echo "Ejecuta: go mod tidy"
    ;;

  *)
    echo "Comando no reconocido: $COMMAND"
    echo "Comandos disponibles: init, module, generate"
    exit 1
    ;;
esac
