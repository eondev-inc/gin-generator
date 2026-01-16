#!/usr/bin/env bash

# ============================================================
# Gin API Generator v2.0
# Generador de APIs REST con Go, Gin, sqlc y PostgreSQL
# Arquitectura: Domain-Driven Design (DDD)
# ============================================================

set -e

VERSION="2.0.0"

# ============================================================
# SECCIÓN 1: COLORES Y CONFIGURACIÓN
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Variables globales del proyecto
PROJECT_NAME=""
MODULE_NAME=""
SERVER_PORT="8080"
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="postgres"
DB_PASS="postgres"
DB_NAME=""

# Features (1=habilitado, 0=deshabilitado)
FEATURE_JWT=1
FEATURE_SWAGGER=1
FEATURE_CORS=1
FEATURE_RATELIMIT=1
FEATURE_HEALTHCHECK=1
FEATURE_LOGGING=1
FEATURE_DOCKER=1
FEATURE_GITHUB_ACTIONS=1

# ============================================================
# SECCIÓN 2: FUNCIONES DE UTILIDAD
# ============================================================

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║             🚀 Gin API Generator v${VERSION}                 ║"
    echo "║                                                           ║"
    echo "║   Generador de APIs REST con Go, Gin, sqlc y PostgreSQL   ║"
    echo "║   Arquitectura: Domain-Driven Design (DDD)                ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

print_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

print_error() {
    echo -e "${RED}✗ $1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${RESET}"
}

print_step() {
    echo -e "${MAGENTA}→ $1${RESET}"
}

print_section() {
    echo ""
    echo -e "${BOLD}${WHITE}$1${RESET}"
    echo -e "${WHITE}$(printf '─%.0s' {1..50})${RESET}"
}

validate_project_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        return 1
    fi
    return 0
}

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
        return 0
    fi
    return 1
}

get_module_name_from_gomod() {
    if [ -f "go.mod" ]; then
        grep "^module " go.mod | awk '{print $2}'
    else
        echo ""
    fi
}

to_pascal_case() {
    echo "$1" | sed -r 's/(^|_)([a-z])/\U\2/g'
}

to_camel_case() {
    local pascal=$(to_pascal_case "$1")
    echo "$(echo ${pascal:0:1} | tr '[:upper:]' '[:lower:]')${pascal:1}"
}

# ============================================================
# SECCIÓN 2.5: VERIFICACIÓN DE HERRAMIENTAS
# ============================================================

check_command() {
    command -v "$1" >/dev/null 2>&1
}

get_version() {
    local cmd="$1"
    case "$cmd" in
        go)
            go version 2>/dev/null | grep -oP 'go\d+\.\d+(\.\d+)?' | head -1
            ;;
        docker)
            docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        git)
            git --version 2>/dev/null | grep -oP '\d+\.\d+(\.\d+)?' | head -1
            ;;
        make)
            make --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+(\.\d+)?' | head -1
            ;;
        psql)
            psql --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1
            ;;
        sqlc)
            sqlc version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        migrate)
            migrate -version 2>/dev/null | head -1
            ;;
        air)
            air -v 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
            ;;
        *)
            echo "desconocida"
            ;;
    esac
}

check_required_tools() {
    local missing_required=0
    local missing_optional=0
    
    print_section "🔍 Verificando herramientas"
    
    # Herramientas requeridas para el generador
    echo -e "${WHITE}Herramientas del generador:${RESET}"
    
    if check_command bash; then
        local bash_version=$(bash --version | head -1 | grep -oP '\d+\.\d+' | head -1)
        echo -e "  ${GREEN}✓${RESET} bash ($bash_version)"
    else
        echo -e "  ${RED}✗${RESET} bash - Requerido para ejecutar el generador"
        missing_required=1
    fi
    
    if check_command git; then
        echo -e "  ${GREEN}✓${RESET} git ($(get_version git))"
    else
        echo -e "  ${RED}✗${RESET} git - Requerido para control de versiones"
        missing_required=1
    fi
    
    echo ""
    echo -e "${WHITE}Herramientas para proyectos generados:${RESET}"
    
    # Go - Requerido
    if check_command go; then
        local go_version=$(get_version go)
        echo -e "  ${GREEN}✓${RESET} go ($go_version)"
        
        # Verificar versión mínima (1.21)
        local go_major=$(echo "$go_version" | grep -oP '\d+' | head -1)
        local go_minor=$(echo "$go_version" | grep -oP '\d+' | head -2 | tail -1)
        if [[ "$go_major" -eq 1 && "$go_minor" -lt 21 ]]; then
            echo -e "    ${YELLOW}⚠ Se recomienda Go 1.21+ para slog${RESET}"
        fi
    else
        echo -e "  ${RED}✗${RESET} go - Requerido para compilar el proyecto"
        echo -e "    ${CYAN}Instalar: https://golang.org/dl/${RESET}"
        missing_required=1
    fi
    
    # Make - Requerido
    if check_command make; then
        echo -e "  ${GREEN}✓${RESET} make ($(get_version make))"
    else
        echo -e "  ${RED}✗${RESET} make - Requerido para comandos de desarrollo"
        echo -e "    ${CYAN}Instalar: apt install make (Debian/Ubuntu)${RESET}"
        missing_required=1
    fi
    
    # PostgreSQL client - Opcional pero recomendado
    if check_command psql; then
        echo -e "  ${GREEN}✓${RESET} psql ($(get_version psql))"
    else
        echo -e "  ${YELLOW}○${RESET} psql - Opcional (cliente PostgreSQL)"
        echo -e "    ${CYAN}Instalar: apt install postgresql-client${RESET}"
        missing_optional=1
    fi
    
    # Docker - Opcional
    if check_command docker; then
        echo -e "  ${GREEN}✓${RESET} docker ($(get_version docker))"
        
        # Verificar si Docker daemon está corriendo
        if docker info >/dev/null 2>&1; then
            echo -e "    ${GREEN}✓${RESET} Docker daemon corriendo"
        else
            echo -e "    ${YELLOW}⚠${RESET} Docker daemon no está corriendo"
        fi
    else
        echo -e "  ${YELLOW}○${RESET} docker - Opcional (para PostgreSQL en contenedor)"
        echo -e "    ${CYAN}Instalar: https://docs.docker.com/get-docker/${RESET}"
        missing_optional=1
    fi
    
    echo ""
    echo -e "${WHITE}Herramientas auto-instalables (make install-tools):${RESET}"
    
    # sqlc - Auto instalable
    if check_command sqlc; then
        echo -e "  ${GREEN}✓${RESET} sqlc ($(get_version sqlc))"
    else
        echo -e "  ${CYAN}○${RESET} sqlc - Se instalará con 'make install-tools'"
    fi
    
    # migrate - Auto instalable
    if check_command migrate; then
        echo -e "  ${GREEN}✓${RESET} migrate"
    else
        echo -e "  ${CYAN}○${RESET} migrate - Se instalará con 'make install-tools'"
    fi
    
    # air - Auto instalable
    if check_command air; then
        echo -e "  ${GREEN}✓${RESET} air ($(get_version air))"
    else
        echo -e "  ${CYAN}○${RESET} air - Se instalará con 'make install-tools'"
    fi
    
    echo ""
    
    # Resumen
    if [[ $missing_required -eq 1 ]]; then
        print_error "Faltan herramientas requeridas. Instálalas antes de continuar."
        echo ""
        echo -ne "${YELLOW}¿Continuar de todas formas? [s/N]: ${RESET}"
        read -r input
        if [[ "${input,,}" != "s" && "${input,,}" != "si" && "${input,,}" != "y" && "${input,,}" != "yes" ]]; then
            print_info "Instalación cancelada. Instala las herramientas requeridas y vuelve a intentar."
            exit 1
        fi
        echo ""
    elif [[ $missing_optional -eq 1 ]]; then
        print_warning "Algunas herramientas opcionales no están instaladas."
        print_info "El proyecto funcionará, pero podrías necesitar instalarlas luego."
        echo ""
    else
        print_success "Todas las herramientas están instaladas!"
        echo ""
    fi
}

skip_tool_check() {
    # Retorna 0 si se debe saltar el chequeo
    for arg in "$@"; do
        if [[ "$arg" == "--skip-check" || "$arg" == "-s" ]]; then
            return 0
        fi
    done
    return 1
}

# ============================================================
# SECCIÓN 3: FUNCIONES DEL WIZARD
# ============================================================

ask_project_name() {
    while true; do
        echo -ne "${CYAN}Nombre del proyecto: ${RESET}"
        read -r PROJECT_NAME
        
        if [ -z "$PROJECT_NAME" ]; then
            print_error "El nombre del proyecto es requerido"
            continue
        fi
        
        if ! validate_project_name "$PROJECT_NAME"; then
            print_error "Nombre inválido. Usa solo letras minúsculas, números y guiones. Debe comenzar con letra."
            continue
        fi
        
        if [ -d "$PROJECT_NAME" ]; then
            print_error "Ya existe un directorio con ese nombre"
            continue
        fi
        
        break
    done
    
    # Default para DB_NAME
    DB_NAME="${PROJECT_NAME//-/_}_db"
}

ask_module_name() {
    local default_module="github.com/user/${PROJECT_NAME}"
    echo -ne "${CYAN}Módulo Go [${default_module}]: ${RESET}"
    read -r input
    MODULE_NAME="${input:-$default_module}"
}

ask_server_port() {
    while true; do
        echo -ne "${CYAN}Puerto del servidor [${SERVER_PORT}]: ${RESET}"
        read -r input
        local port="${input:-$SERVER_PORT}"
        
        if validate_port "$port"; then
            SERVER_PORT="$port"
            break
        else
            print_error "Puerto inválido. Debe ser un número entre 1024 y 65535"
        fi
    done
}

ask_database_config() {
    print_section "🗄️  Configuración de Base de Datos"
    
    echo -ne "${CYAN}Host [${DB_HOST}]: ${RESET}"
    read -r input
    DB_HOST="${input:-$DB_HOST}"
    
    echo -ne "${CYAN}Puerto [${DB_PORT}]: ${RESET}"
    read -r input
    DB_PORT="${input:-$DB_PORT}"
    
    echo -ne "${CYAN}Usuario [${DB_USER}]: ${RESET}"
    read -r input
    DB_USER="${input:-$DB_USER}"
    
    echo -ne "${CYAN}Contraseña [${DB_PASS}]: ${RESET}"
    read -r input
    DB_PASS="${input:-$DB_PASS}"
    
    echo -ne "${CYAN}Nombre de la BD [${DB_NAME}]: ${RESET}"
    read -r input
    DB_NAME="${input:-$DB_NAME}"
}

ask_features() {
    print_section "🔧 Features Opcionales"
    echo -e "${WHITE}Responde s/n para cada feature:${RESET}"
    echo ""
    
    echo -ne "${CYAN}JWT Authentication - Autenticación con tokens JWT [S/n]: ${RESET}"
    read -r input
    [[ "${input,,}" == "n" ]] && FEATURE_JWT=0
    
    echo -ne "${CYAN}Swagger/OpenAPI - Documentación automática de API [S/n]: ${RESET}"
    read -r input
    [[ "${input,,}" == "n" ]] && FEATURE_SWAGGER=0
    
    echo -ne "${CYAN}CORS - Configuración Cross-Origin [S/n]: ${RESET}"
    read -r input
    [[ "${input,,}" == "n" ]] && FEATURE_CORS=0
    
    echo -ne "${CYAN}Rate Limiting - Limitación de requests por IP [S/n]: ${RESET}"
    read -r input
    [[ "${input,,}" == "n" ]] && FEATURE_RATELIMIT=0
    
    echo -ne "${CYAN}Health Checks - Endpoints /health y /ready [S/n]: ${RESET}"
    read -r input
    [[ "${input,,}" == "n" ]] && FEATURE_HEALTHCHECK=0
    
    echo -ne "${CYAN}Logging Estructurado - Logs JSON con slog [S/n]: ${RESET}"
    read -r input
    [[ "${input,,}" == "n" ]] && FEATURE_LOGGING=0
    
    echo -ne "${CYAN}Docker Multi-stage - Dockerfile optimizado [S/n]: ${RESET}"
    read -r input
    [[ "${input,,}" == "n" ]] && FEATURE_DOCKER=0
    
    echo -ne "${CYAN}GitHub Actions CI - Pipeline de CI/CD automático [S/n]: ${RESET}"
    read -r input
    [[ "${input,,}" == "n" ]] && FEATURE_GITHUB_ACTIONS=0
}

show_summary() {
    print_section "📋 Resumen de Configuración"
    
    echo -e "  ${WHITE}Proyecto:${RESET}    $PROJECT_NAME"
    echo -e "  ${WHITE}Módulo:${RESET}      $MODULE_NAME"
    echo -e "  ${WHITE}Puerto:${RESET}      $SERVER_PORT"
    echo -e "  ${WHITE}Base datos:${RESET}  $DB_NAME@$DB_HOST:$DB_PORT"
    echo ""
    echo -e "  ${WHITE}Features:${RESET}"
    [[ $FEATURE_JWT -eq 1 ]] && echo -e "    ${GREEN}✓${RESET} JWT Authentication"
    [[ $FEATURE_JWT -eq 0 ]] && echo -e "    ${RED}✗${RESET} JWT Authentication"
    [[ $FEATURE_SWAGGER -eq 1 ]] && echo -e "    ${GREEN}✓${RESET} Swagger/OpenAPI"
    [[ $FEATURE_SWAGGER -eq 0 ]] && echo -e "    ${RED}✗${RESET} Swagger/OpenAPI"
    [[ $FEATURE_CORS -eq 1 ]] && echo -e "    ${GREEN}✓${RESET} CORS"
    [[ $FEATURE_CORS -eq 0 ]] && echo -e "    ${RED}✗${RESET} CORS"
    [[ $FEATURE_RATELIMIT -eq 1 ]] && echo -e "    ${GREEN}✓${RESET} Rate Limiting"
    [[ $FEATURE_RATELIMIT -eq 0 ]] && echo -e "    ${RED}✗${RESET} Rate Limiting"
    [[ $FEATURE_HEALTHCHECK -eq 1 ]] && echo -e "    ${GREEN}✓${RESET} Health Checks"
    [[ $FEATURE_HEALTHCHECK -eq 0 ]] && echo -e "    ${RED}✗${RESET} Health Checks"
    [[ $FEATURE_LOGGING -eq 1 ]] && echo -e "    ${GREEN}✓${RESET} Logging Estructurado"
    [[ $FEATURE_LOGGING -eq 0 ]] && echo -e "    ${RED}✗${RESET} Logging Estructurado"
    [[ $FEATURE_DOCKER -eq 1 ]] && echo -e "    ${GREEN}✓${RESET} Docker Multi-stage"
    [[ $FEATURE_DOCKER -eq 0 ]] && echo -e "    ${RED}✗${RESET} Docker Multi-stage"
    [[ $FEATURE_GITHUB_ACTIONS -eq 1 ]] && echo -e "    ${GREEN}✓${RESET} GitHub Actions CI"
    [[ $FEATURE_GITHUB_ACTIONS -eq 0 ]] && echo -e "    ${RED}✗${RESET} GitHub Actions CI"
    echo ""
}

confirm_generation() {
    echo -ne "${YELLOW}¿Continuar con la generación? [S/n]: ${RESET}"
    read -r input
    if [[ "${input,,}" == "n" ]]; then
        print_warning "Generación cancelada"
        exit 0
    fi
}

run_wizard() {
    print_banner
    
    print_section "📦 Configuración del Proyecto"
    ask_project_name
    ask_module_name
    ask_server_port
    
    ask_database_config
    ask_features
    
    show_summary
    confirm_generation
}


# ============================================================
# SECCIÓN 4: GENERADORES DE ESTRUCTURA BASE
# ============================================================

create_directory_structure() {
    print_step "Creando estructura de directorios..."
    
    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    
    # Estructura DDD
    mkdir -p cmd/api
    mkdir -p internal/domain/user
    mkdir -p internal/application/user
    mkdir -p internal/infrastructure/persistence/postgres
    mkdir -p internal/infrastructure/config
    mkdir -p internal/interfaces/http/handler
    mkdir -p internal/interfaces/http/middleware
    mkdir -p internal/interfaces/http/request
    mkdir -p internal/interfaces/http/response
    mkdir -p pkg/errors
    
    # SQL
    mkdir -p sql/schema
    mkdir -p sql/queries
    mkdir -p sql/migrations
    mkdir -p sqldb
    
    # Features opcionales
    [[ $FEATURE_LOGGING -eq 1 ]] && mkdir -p pkg/logger
    [[ $FEATURE_JWT -eq 1 ]] && mkdir -p pkg/jwt
    [[ $FEATURE_SWAGGER -eq 1 ]] && mkdir -p docs
    
    print_success "Estructura de directorios creada"
}

create_go_mod() {
    print_step "Inicializando módulo Go..."
    
    go mod init "$MODULE_NAME"
    
    # Dependencias base
    go get github.com/gin-gonic/gin
    go get github.com/lib/pq
    go get github.com/joho/godotenv
    
    # Dependencias opcionales
    [[ $FEATURE_JWT -eq 1 ]] && go get github.com/golang-jwt/jwt/v5
    [[ $FEATURE_SWAGGER -eq 1 ]] && go get github.com/swaggo/swag/cmd/swag github.com/swaggo/gin-swagger github.com/swaggo/files
    [[ $FEATURE_CORS -eq 1 ]] && go get github.com/gin-contrib/cors
    [[ $FEATURE_RATELIMIT -eq 1 ]] && go get golang.org/x/time/rate
    
    print_success "Módulo Go inicializado"
}

create_main_go() {
    print_step "Creando main.go..."
    
    local imports_extra=""
    local init_logger=""
    local shutdown_log=""
    
    if [[ $FEATURE_LOGGING -eq 1 ]]; then
        imports_extra="\"${MODULE_NAME}/pkg/logger\""
        init_logger="
    // Inicializar logger
    logger.Setup(cfg.Environment)"
        shutdown_log='slog.Info("Servidor iniciado", "puerto", cfg.ServerPort)'
    else
        shutdown_log='log.Printf("🚀 Servidor iniciado en puerto %s", cfg.ServerPort)'
    fi
    
    cat > cmd/api/main.go << EOF
package main

import (
    "context"
    "log"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "${MODULE_NAME}/internal/infrastructure/config"
    "${MODULE_NAME}/internal/infrastructure/persistence/postgres"
    apphttp "${MODULE_NAME}/internal/interfaces/http"
    ${imports_extra}
)

// @title           ${PROJECT_NAME} API
// @version         1.0
// @description     API REST generada con Gin Generator
// @host            localhost:${SERVER_PORT}
// @BasePath        /api/v1
func main() {
    // Cargar configuración
    cfg := config.Load()
    ${init_logger}
    
    // Conectar a base de datos
    db, err := postgres.NewConnection(cfg)
    if err != nil {
        log.Fatalf("Error conectando a la base de datos: %v", err)
    }
    defer db.Close()

    // Crear servidor HTTP
    srv := apphttp.NewServer(cfg, db)

    // Iniciar servidor en goroutine
    go func() {
        ${shutdown_log}
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Error en servidor: %v", err)
        }
    }()

    // Graceful shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    slog.Info("Apagando servidor...")
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        slog.Error("Error en shutdown", "error", err)
    }
    slog.Info("Servidor detenido correctamente")
}
EOF

    print_success "main.go creado"
}

create_config() {
    print_step "Creando configuración..."
    
    cat > internal/infrastructure/config/config.go << EOF
package config

import (
    "log"
    "os"

    "github.com/joho/godotenv"
)

type Config struct {
    // Server
    ServerPort  string
    Environment string

    // Database
    DBHost string
    DBPort string
    DBUser string
    DBPass string
    DBName string
EOF

    # Agregar campos opcionales
    [[ $FEATURE_JWT -eq 1 ]] && cat >> internal/infrastructure/config/config.go << 'EOF'

    // JWT
    JWTSecret         string
    JWTExpirationHours int
EOF

    [[ $FEATURE_CORS -eq 1 ]] && cat >> internal/infrastructure/config/config.go << 'EOF'

    // CORS
    CORSAllowedOrigins []string
EOF

    [[ $FEATURE_RATELIMIT -eq 1 ]] && cat >> internal/infrastructure/config/config.go << 'EOF'

    // Rate Limiting
    RateLimitRPS   int
    RateLimitBurst int
EOF

    cat >> internal/infrastructure/config/config.go << 'EOF'
}

func Load() *Config {
    if err := godotenv.Load(); err != nil {
        log.Println("No se encontró archivo .env, usando variables de entorno del sistema")
    }

    cfg := &Config{
        ServerPort:  getEnv("SERVER_PORT", "8080"),
        Environment: getEnv("ENVIRONMENT", "development"),
        DBHost:      getEnv("DB_HOST", "localhost"),
        DBPort:      getEnv("DB_PORT", "5432"),
        DBUser:      getEnv("DB_USER", "postgres"),
        DBPass:      getEnv("DB_PASS", "postgres"),
        DBName:      getEnv("DB_NAME", "mydb"),
EOF

    [[ $FEATURE_JWT -eq 1 ]] && cat >> internal/infrastructure/config/config.go << 'EOF'
        JWTSecret:         getEnv("JWT_SECRET", "your-secret-key"),
        JWTExpirationHours: getEnvAsInt("JWT_EXPIRATION_HOURS", 24),
EOF

    [[ $FEATURE_CORS -eq 1 ]] && cat >> internal/infrastructure/config/config.go << 'EOF'
        CORSAllowedOrigins: getEnvAsSlice("CORS_ALLOWED_ORIGINS", []string{"*"}),
EOF

    [[ $FEATURE_RATELIMIT -eq 1 ]] && cat >> internal/infrastructure/config/config.go << 'EOF'
        RateLimitRPS:   getEnvAsInt("RATE_LIMIT_RPS", 100),
        RateLimitBurst: getEnvAsInt("RATE_LIMIT_BURST", 200),
EOF

    cat >> internal/infrastructure/config/config.go << 'EOF'
    }

    return cfg
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        var intVal int
        _, err := fmt.Sscanf(value, "%d", &intVal)
        if err == nil {
            return intVal
        }
    }
    return defaultValue
}

func getEnvAsSlice(key string, defaultValue []string) []string {
    if value := os.Getenv(key); value != "" {
        return strings.Split(value, ",")
    }
    return defaultValue
}
EOF

    # Agregar imports necesarios
    sed -i '4a\    "fmt"\n    "strings"' internal/infrastructure/config/config.go 2>/dev/null || \
    sed -i '' '4a\
    "fmt"\
    "strings"
' internal/infrastructure/config/config.go

    print_success "Configuración creada"
}

create_env_example() {
    print_step "Creando .env.example..."
    
    cat > .env.example << EOF
# Entorno
ENVIRONMENT=development

# Servidor
SERVER_PORT=${SERVER_PORT}

# Base de datos PostgreSQL
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_NAME=${DB_NAME}
EOF

    [[ $FEATURE_JWT -eq 1 ]] && cat >> .env.example << 'EOF'

# JWT
JWT_SECRET=tu-clave-secreta-muy-segura
JWT_EXPIRATION_HOURS=24
EOF

    [[ $FEATURE_CORS -eq 1 ]] && cat >> .env.example << 'EOF'

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
EOF

    [[ $FEATURE_RATELIMIT -eq 1 ]] && cat >> .env.example << 'EOF'

# Rate Limiting
RATE_LIMIT_RPS=100
RATE_LIMIT_BURST=200
EOF

    # Copiar a .env
    cp .env.example .env
    
    print_success ".env.example creado"
}

create_gitignore() {
    print_step "Creando .gitignore..."
    
    cat > .gitignore << 'EOF'
# Binarios
bin/
tmp/
*.exe
*.exe~
*.dll
*.so
*.dylib

# Test y coverage
*.test
*.out
coverage.html
coverage.out

# Go workspace
go.work

# Variables de entorno
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

# Swagger docs generados (regenerables)
docs/docs.go
docs/swagger.json
docs/swagger.yaml
EOF

    print_success ".gitignore creado"
}

create_docker_compose() {
    print_step "Creando docker-compose.yml..."
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: ${PROJECT_NAME}_postgres
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
    ports:
      - "${DB_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
EOF

    print_success "docker-compose.yml creado"
}

create_air_config() {
    print_step "Creando .air.toml..."
    
    cat > .air.toml << 'EOF'
root = "."
testdata_dir = "testdata"
tmp_dir = "tmp"

[build]
  args_bin = []
  bin = "./tmp/main"
  cmd = "go build -o ./tmp/main ./cmd/api"
  delay = 1000
  exclude_dir = ["assets", "tmp", "vendor", "testdata", "sqldb", "docs"]
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

    print_success ".air.toml creado"
}

create_sqlc_config() {
    print_step "Creando sqlc.yaml..."
    
    cat > sqlc.yaml << 'EOF'
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

    print_success "sqlc.yaml creado"
}


create_makefile() {
    print_step "Creando Makefile..."
    
    cat > Makefile << 'MAKEFILE_EOF'
.PHONY: help dev build run test clean setup

# Variables
SHELL := /bin/bash
export PATH := $(HOME)/go/bin:$(PATH)

# Colores
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
RESET := \033[0m

# Cargar variables de entorno
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

help: ## Muestra esta ayuda
	@echo -e "$(BLUE)Comandos disponibles:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'

# === Desarrollo ===

dev: ## Inicia servidor con hot-reload
	@echo -e "$(BLUE)Iniciando servidor en modo desarrollo...$(RESET)"
	@air

run: ## Ejecuta el servidor
	@echo -e "$(BLUE)Ejecutando servidor...$(RESET)"
	@go run ./cmd/api

build: ## Compila el proyecto
	@echo -e "$(BLUE)Compilando...$(RESET)"
	@go build -o bin/api ./cmd/api
	@echo -e "$(GREEN)✓ Compilado: bin/api$(RESET)"

test: ## Ejecuta tests
	@echo -e "$(BLUE)Ejecutando tests...$(RESET)"
	@go test -v ./...

test-coverage: ## Tests con coverage
	@echo -e "$(BLUE)Ejecutando tests con coverage...$(RESET)"
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo -e "$(GREEN)✓ Coverage: coverage.html$(RESET)"

clean: ## Limpia archivos generados
	@echo -e "$(YELLOW)Limpiando...$(RESET)"
	@rm -rf bin/ tmp/ coverage.out coverage.html
	@echo -e "$(GREEN)✓ Limpieza completada$(RESET)"

fmt: ## Formatea el código
	@echo -e "$(BLUE)Formateando código...$(RESET)"
	@go fmt ./...
	@echo -e "$(GREEN)✓ Código formateado$(RESET)"

lint: ## Ejecuta linter
	@echo -e "$(BLUE)Ejecutando linter...$(RESET)"
	@golangci-lint run ./...

# === Setup ===

setup: install-tools deps db-create migrate-up sqlc-generate ## Setup completo del proyecto
	@echo -e "$(GREEN)✓ Proyecto configurado$(RESET)"
	@echo -e "$(BLUE)Ejecuta 'make dev' para iniciar$(RESET)"

install-tools: ## Instala herramientas necesarias
	@echo -e "$(BLUE)Instalando herramientas...$(RESET)"
	@go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
	@go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	@go install github.com/air-verse/air@latest
	@echo -e "$(GREEN)✓ Herramientas instaladas$(RESET)"

deps: ## Instala dependencias Go
	@echo -e "$(BLUE)Instalando dependencias...$(RESET)"
	@go mod download
	@go mod tidy
	@echo -e "$(GREEN)✓ Dependencias instaladas$(RESET)"

# === Base de Datos ===

MIGRATE_DSN := "postgres://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=disable"

db-create: ## Crea la base de datos
	@echo -e "$(BLUE)Creando base de datos...$(RESET)"
	@PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres -c "CREATE DATABASE $(DB_NAME);" 2>/dev/null || echo "La base de datos ya existe"
	@echo -e "$(GREEN)✓ Base de datos lista$(RESET)"

db-drop: ## Elimina la base de datos
	@echo -e "$(RED)⚠️  Eliminando base de datos $(DB_NAME)...$(RESET)"
	@read -p "¿Estás seguro? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d postgres -c "DROP DATABASE IF EXISTS $(DB_NAME);"
	@echo -e "$(GREEN)✓ Base de datos eliminada$(RESET)"

db-reset: db-drop db-create migrate-up ## Resetea la base de datos
	@echo -e "$(GREEN)✓ Base de datos reseteada$(RESET)"

db-console: ## Abre consola PostgreSQL
	@PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)

# === Migraciones ===

migrate-create: ## Crea nueva migración (make migrate-create name=add_table)
	@if [ -z "$(name)" ]; then echo -e "$(RED)Error: usa make migrate-create name=nombre$(RESET)"; exit 1; fi
	@migrate create -ext sql -dir sql/migrations -seq $(name)
	@echo -e "$(GREEN)✓ Migración creada$(RESET)"

migrate-up: ## Aplica migraciones pendientes
	@echo -e "$(BLUE)Aplicando migraciones...$(RESET)"
	@migrate -path sql/migrations -database $(MIGRATE_DSN) up
	@echo -e "$(GREEN)✓ Migraciones aplicadas$(RESET)"

migrate-down: ## Revierte última migración
	@echo -e "$(YELLOW)Revirtiendo última migración...$(RESET)"
	@migrate -path sql/migrations -database $(MIGRATE_DSN) down 1
	@echo -e "$(GREEN)✓ Migración revertida$(RESET)"

migrate-down-all: ## Revierte TODAS las migraciones
	@echo -e "$(RED)⚠️  Revirtiendo TODAS las migraciones...$(RESET)"
	@read -p "¿Estás seguro? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@migrate -path sql/migrations -database $(MIGRATE_DSN) down -all
	@echo -e "$(GREEN)✓ Todas las migraciones revertidas$(RESET)"

migrate-force: ## Fuerza versión (make migrate-force version=1)
	@if [ -z "$(version)" ]; then echo -e "$(RED)Error: usa make migrate-force version=N$(RESET)"; exit 1; fi
	@migrate -path sql/migrations -database $(MIGRATE_DSN) force $(version)
	@echo -e "$(GREEN)✓ Versión forzada a $(version)$(RESET)"

migrate-version: ## Muestra versión actual
	@migrate -path sql/migrations -database $(MIGRATE_DSN) version

# === SQLc ===

sqlc-generate: ## Genera código desde SQL
	@echo -e "$(BLUE)Generando código sqlc...$(RESET)"
	@sqlc generate
	@echo -e "$(GREEN)✓ Código generado en sqldb/$(RESET)"

sqlc-verify: ## Verifica configuración sqlc
	@sqlc verify

# === Docker ===

docker-up: ## Inicia contenedores
	@echo -e "$(BLUE)Iniciando contenedores...$(RESET)"
	@docker compose up -d
	@echo -e "$(GREEN)✓ Contenedores iniciados$(RESET)"

docker-down: ## Detiene contenedores
	@docker compose down

docker-logs: ## Muestra logs
	@docker compose logs -f
MAKEFILE_EOF

    # Agregar swagger target si está habilitado
    if [[ $FEATURE_SWAGGER -eq 1 ]]; then
        cat >> Makefile << 'MAKEFILE_SWAGGER'

# === Swagger ===

swagger: ## Genera documentación Swagger
	@echo -e "$(BLUE)Generando documentación Swagger...$(RESET)"
	@swag init -g cmd/api/main.go -o docs
	@echo -e "$(GREEN)✓ Documentación generada en docs/$(RESET)"
MAKEFILE_SWAGGER
    fi

    print_success "Makefile creado"
}


# ============================================================
# SECCIÓN 5: GENERADORES DDD - DOMAIN LAYER
# ============================================================

create_domain_user() {
    print_step "Creando capa de dominio (user)..."
    
    # Entity
    cat > internal/domain/user/entity.go << 'EOF'
package user

import "time"

// User representa la entidad de usuario en el dominio
type User struct {
    ID        int64     `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

// NewUser crea una nueva instancia de User
func NewUser(name, email string) *User {
    now := time.Now()
    return &User{
        Name:      name,
        Email:     email,
        CreatedAt: now,
        UpdatedAt: now,
    }
}

// Update actualiza los campos del usuario
func (u *User) Update(name, email string) {
    if name != "" {
        u.Name = name
    }
    if email != "" {
        u.Email = email
    }
    u.UpdatedAt = time.Now()
}
EOF

    # Repository Interface
    cat > internal/domain/user/repository.go << 'EOF'
package user

import "context"

// Repository define las operaciones de persistencia para User
type Repository interface {
    FindAll(ctx context.Context) ([]*User, error)
    FindByID(ctx context.Context, id int64) (*User, error)
    FindByEmail(ctx context.Context, email string) (*User, error)
    Create(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id int64) error
}
EOF

    # Domain Errors
    cat > internal/domain/user/errors.go << 'EOF'
package user

import "errors"

var (
    ErrUserNotFound      = errors.New("usuario no encontrado")
    ErrUserAlreadyExists = errors.New("el usuario ya existe")
    ErrInvalidEmail      = errors.New("email inválido")
)
EOF

    print_success "Capa de dominio creada"
}

# ============================================================
# SECCIÓN 6: GENERADORES DDD - APPLICATION LAYER
# ============================================================

create_application_user() {
    print_step "Creando capa de aplicación (user)..."
    
    # DTOs
    cat > internal/application/user/dto.go << 'EOF'
package user

import (
    "time"

    domain "MODULE_NAME/internal/domain/user"
)

// CreateUserRequest representa la solicitud para crear un usuario
type CreateUserRequest struct {
    Name  string `json:"name" binding:"required,min=2,max=100"`
    Email string `json:"email" binding:"required,email"`
}

// UpdateUserRequest representa la solicitud para actualizar un usuario
type UpdateUserRequest struct {
    Name  *string `json:"name,omitempty" binding:"omitempty,min=2,max=100"`
    Email *string `json:"email,omitempty" binding:"omitempty,email"`
}

// UserResponse representa la respuesta de un usuario
type UserResponse struct {
    ID        int64     `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

// ToResponse convierte un User del dominio a UserResponse
func ToResponse(u *domain.User) *UserResponse {
    return &UserResponse{
        ID:        u.ID,
        Name:      u.Name,
        Email:     u.Email,
        CreatedAt: u.CreatedAt,
        UpdatedAt: u.UpdatedAt,
    }
}

// ToResponseList convierte una lista de Users a UserResponses
func ToResponseList(users []*domain.User) []*UserResponse {
    result := make([]*UserResponse, len(users))
    for i, u := range users {
        result[i] = ToResponse(u)
    }
    return result
}
EOF

    # Reemplazar MODULE_NAME
    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/application/user/dto.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/application/user/dto.go

    # Service
    cat > internal/application/user/service.go << 'EOF'
package user

import (
    "context"

    domain "MODULE_NAME/internal/domain/user"
)

// Service define las operaciones de negocio para usuarios
type Service interface {
    GetAll(ctx context.Context) ([]*UserResponse, error)
    GetByID(ctx context.Context, id int64) (*UserResponse, error)
    Create(ctx context.Context, req *CreateUserRequest) (*UserResponse, error)
    Update(ctx context.Context, id int64, req *UpdateUserRequest) (*UserResponse, error)
    Delete(ctx context.Context, id int64) error
}

type service struct {
    repo domain.Repository
}

// NewService crea una nueva instancia del servicio de usuarios
func NewService(repo domain.Repository) Service {
    return &service{repo: repo}
}

func (s *service) GetAll(ctx context.Context) ([]*UserResponse, error) {
    users, err := s.repo.FindAll(ctx)
    if err != nil {
        return nil, err
    }
    return ToResponseList(users), nil
}

func (s *service) GetByID(ctx context.Context, id int64) (*UserResponse, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, err
    }
    return ToResponse(user), nil
}

func (s *service) Create(ctx context.Context, req *CreateUserRequest) (*UserResponse, error) {
    // Verificar si ya existe un usuario con ese email
    existing, _ := s.repo.FindByEmail(ctx, req.Email)
    if existing != nil {
        return nil, domain.ErrUserAlreadyExists
    }

    user := domain.NewUser(req.Name, req.Email)
    if err := s.repo.Create(ctx, user); err != nil {
        return nil, err
    }

    return ToResponse(user), nil
}

func (s *service) Update(ctx context.Context, id int64, req *UpdateUserRequest) (*UserResponse, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, err
    }

    name := ""
    email := ""
    if req.Name != nil {
        name = *req.Name
    }
    if req.Email != nil {
        email = *req.Email
    }

    user.Update(name, email)

    if err := s.repo.Update(ctx, user); err != nil {
        return nil, err
    }

    return ToResponse(user), nil
}

func (s *service) Delete(ctx context.Context, id int64) error {
    _, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return err
    }
    return s.repo.Delete(ctx, id)
}
EOF

    # Reemplazar MODULE_NAME
    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/application/user/service.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/application/user/service.go

    print_success "Capa de aplicación creada"
}

# ============================================================
# SECCIÓN 7: GENERADORES DDD - INFRASTRUCTURE LAYER
# ============================================================

create_infrastructure_postgres() {
    print_step "Creando conexión PostgreSQL..."
    
    cat > internal/infrastructure/persistence/postgres/connection.go << 'EOF'
package postgres

import (
    "database/sql"
    "fmt"
    "log"
    "time"

    _ "github.com/lib/pq"

    "MODULE_NAME/internal/infrastructure/config"
)

// NewConnection crea una nueva conexión a PostgreSQL
func NewConnection(cfg *config.Config) (*sql.DB, error) {
    dsn := fmt.Sprintf(
        "host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
        cfg.DBHost,
        cfg.DBPort,
        cfg.DBUser,
        cfg.DBPass,
        cfg.DBName,
    )

    db, err := sql.Open("postgres", dsn)
    if err != nil {
        return nil, fmt.Errorf("error abriendo conexión: %w", err)
    }

    // Configurar pool de conexiones
    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)

    // Verificar conexión
    if err := db.Ping(); err != nil {
        return nil, fmt.Errorf("error conectando a la base de datos: %w", err)
    }

    log.Println("✓ Conexión a PostgreSQL establecida")
    return db, nil
}
EOF

    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/infrastructure/persistence/postgres/connection.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/infrastructure/persistence/postgres/connection.go

    print_success "Conexión PostgreSQL creada"
}

create_infrastructure_repository() {
    print_step "Creando repositorio de usuario..."
    
    cat > internal/infrastructure/persistence/postgres/user_repository.go << 'EOF'
package postgres

import (
    "context"
    "database/sql"

    domain "MODULE_NAME/internal/domain/user"
    "MODULE_NAME/sqldb"
)

type userRepository struct {
    db      *sql.DB
    queries *sqldb.Queries
}

// NewUserRepository crea una nueva instancia del repositorio de usuarios
func NewUserRepository(db *sql.DB) domain.Repository {
    return &userRepository{
        db:      db,
        queries: sqldb.New(db),
    }
}

func (r *userRepository) FindAll(ctx context.Context) ([]*domain.User, error) {
    rows, err := r.queries.ListUsers(ctx)
    if err != nil {
        return nil, err
    }

    users := make([]*domain.User, len(rows))
    for i, row := range rows {
        users[i] = &domain.User{
            ID:        row.ID,
            Name:      row.Name,
            Email:     row.Email,
            CreatedAt: row.CreatedAt.Time,
            UpdatedAt: row.UpdatedAt.Time,
        }
    }

    return users, nil
}

func (r *userRepository) FindByID(ctx context.Context, id int64) (*domain.User, error) {
    row, err := r.queries.GetUserByID(ctx, id)
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, domain.ErrUserNotFound
        }
        return nil, err
    }

    return &domain.User{
        ID:        row.ID,
        Name:      row.Name,
        Email:     row.Email,
        CreatedAt: row.CreatedAt.Time,
        UpdatedAt: row.UpdatedAt.Time,
    }, nil
}

func (r *userRepository) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
    row, err := r.queries.GetUserByEmail(ctx, email)
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, domain.ErrUserNotFound
        }
        return nil, err
    }

    return &domain.User{
        ID:        row.ID,
        Name:      row.Name,
        Email:     row.Email,
        CreatedAt: row.CreatedAt.Time,
        UpdatedAt: row.UpdatedAt.Time,
    }, nil
}

func (r *userRepository) Create(ctx context.Context, user *domain.User) error {
    row, err := r.queries.CreateUser(ctx, sqldb.CreateUserParams{
        Name:      user.Name,
        Email:     user.Email,
        CreatedAt: sql.NullTime{Time: user.CreatedAt, Valid: true},
        UpdatedAt: sql.NullTime{Time: user.UpdatedAt, Valid: true},
    })
    if err != nil {
        return err
    }

    user.ID = row.ID
    return nil
}

func (r *userRepository) Update(ctx context.Context, user *domain.User) error {
    return r.queries.UpdateUser(ctx, sqldb.UpdateUserParams{
        ID:        user.ID,
        Name:      user.Name,
        Email:     user.Email,
        UpdatedAt: sql.NullTime{Time: user.UpdatedAt, Valid: true},
    })
}

func (r *userRepository) Delete(ctx context.Context, id int64) error {
    return r.queries.DeleteUser(ctx, id)
}
EOF

    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/infrastructure/persistence/postgres/user_repository.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/infrastructure/persistence/postgres/user_repository.go

    print_success "Repositorio de usuario creado"
}


# ============================================================
# SECCIÓN 8: GENERADORES DDD - INTERFACES LAYER (HTTP)
# ============================================================

create_http_server() {
    print_step "Creando servidor HTTP..."
    
    cat > internal/interfaces/http/server.go << 'EOF'
package http

import (
    "database/sql"
    "fmt"
    "net/http"

    "github.com/gin-gonic/gin"

    "MODULE_NAME/internal/infrastructure/config"
)

// NewServer crea y configura el servidor HTTP
func NewServer(cfg *config.Config, db *sql.DB) *http.Server {
    // Configurar modo de Gin
    if cfg.Environment == "production" {
        gin.SetMode(gin.ReleaseMode)
    }

    // Crear router
    router := NewRouter(cfg, db)

    // Crear servidor
    srv := &http.Server{
        Addr:    fmt.Sprintf(":%s", cfg.ServerPort),
        Handler: router,
    }

    return srv
}
EOF

    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/server.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/server.go

    print_success "Servidor HTTP creado"
}

create_http_router() {
    print_step "Creando router HTTP..."
    
    # Determinar imports según features
    local middleware_imports=""
    local middleware_setup=""
    local swagger_import=""
    local swagger_route=""
    
    if [[ $FEATURE_CORS -eq 1 ]]; then
        middleware_imports="${middleware_imports}
    \"MODULE_NAME/internal/interfaces/http/middleware\""
    fi
    
    if [[ $FEATURE_SWAGGER -eq 1 ]]; then
        swagger_import="
    _ \"MODULE_NAME/docs\"
    swaggerFiles \"github.com/swaggo/files\"
    ginSwagger \"github.com/swaggo/gin-swagger\""
        swagger_route="
    // Swagger documentation
    r.GET(\"/swagger/*any\", ginSwagger.WrapHandler(swaggerFiles.Handler))"
    fi
    
    cat > internal/interfaces/http/router.go << EOF
package http

import (
    "database/sql"

    "github.com/gin-gonic/gin"

    "MODULE_NAME/internal/infrastructure/config"
    userApp "MODULE_NAME/internal/application/user"
    "MODULE_NAME/internal/infrastructure/persistence/postgres"
    "MODULE_NAME/internal/interfaces/http/handler"
    "MODULE_NAME/internal/interfaces/http/middleware"${swagger_import}
)

// NewRouter crea y configura el router de la aplicación
func NewRouter(cfg *config.Config, db *sql.DB) *gin.Engine {
    r := gin.New()

    // Middlewares globales
    r.Use(gin.Recovery())
    r.Use(middleware.Recovery())
EOF

    # Agregar middlewares según features
    if [[ $FEATURE_LOGGING -eq 1 ]]; then
        cat >> internal/interfaces/http/router.go << 'EOF'
    r.Use(middleware.Logger())
EOF
    fi

    if [[ $FEATURE_CORS -eq 1 ]]; then
        cat >> internal/interfaces/http/router.go << 'EOF'
    r.Use(middleware.CORS(cfg.CORSAllowedOrigins))
EOF
    fi

    if [[ $FEATURE_RATELIMIT -eq 1 ]]; then
        cat >> internal/interfaces/http/router.go << 'EOF'
    r.Use(middleware.RateLimit(cfg.RateLimitRPS, cfg.RateLimitBurst))
EOF
    fi

    # Agregar health checks
    if [[ $FEATURE_HEALTHCHECK -eq 1 ]]; then
        cat >> internal/interfaces/http/router.go << 'EOF'

    // Health checks
    healthHandler := handler.NewHealthHandler(db)
    r.GET("/health", healthHandler.Health)
    r.GET("/ready", healthHandler.Ready)
EOF
    fi

    # Agregar swagger route
    if [[ $FEATURE_SWAGGER -eq 1 ]]; then
        cat >> internal/interfaces/http/router.go << 'EOF'

    // Swagger documentation
    r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
EOF
    fi

    # Agregar rutas de usuario
    cat >> internal/interfaces/http/router.go << 'EOF'

    // Inicializar dependencias
    userRepo := postgres.NewUserRepository(db)
    userService := userApp.NewService(userRepo)
    userHandler := handler.NewUserHandler(userService)

    // Rutas API v1
    v1 := r.Group("/api/v1")
    {
        users := v1.Group("/users")
        {
            users.GET("", userHandler.GetAll)
            users.GET("/:id", userHandler.GetByID)
            users.POST("", userHandler.Create)
            users.PUT("/:id", userHandler.Update)
            users.DELETE("/:id", userHandler.Delete)
        }
    }

    return r
}
EOF

    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/router.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/router.go

    print_success "Router HTTP creado"
}

create_http_handlers() {
    print_step "Creando handlers HTTP..."
    
    # User Handler
    cat > internal/interfaces/http/handler/user_handler.go << 'EOF'
package handler

import (
    "net/http"
    "strconv"

    "github.com/gin-gonic/gin"

    userApp "MODULE_NAME/internal/application/user"
    domain "MODULE_NAME/internal/domain/user"
    "MODULE_NAME/internal/interfaces/http/response"
)

type UserHandler struct {
    service userApp.Service
}

func NewUserHandler(service userApp.Service) *UserHandler {
    return &UserHandler{service: service}
}

// GetAll godoc
// @Summary      Obtener todos los usuarios
// @Description  Retorna una lista de todos los usuarios
// @Tags         users
// @Accept       json
// @Produce      json
// @Success      200  {object}  response.Response{data=[]userApp.UserResponse}
// @Failure      500  {object}  response.Response
// @Router       /users [get]
func (h *UserHandler) GetAll(c *gin.Context) {
    users, err := h.service.GetAll(c.Request.Context())
    if err != nil {
        response.Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
        return
    }
    response.Success(c, http.StatusOK, users)
}

// GetByID godoc
// @Summary      Obtener usuario por ID
// @Description  Retorna un usuario específico por su ID
// @Tags         users
// @Accept       json
// @Produce      json
// @Param        id   path      int  true  "User ID"
// @Success      200  {object}  response.Response{data=userApp.UserResponse}
// @Failure      400  {object}  response.Response
// @Failure      404  {object}  response.Response
// @Router       /users/{id} [get]
func (h *UserHandler) GetByID(c *gin.Context) {
    id, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        response.Error(c, http.StatusBadRequest, "INVALID_ID", "ID inválido")
        return
    }

    user, err := h.service.GetByID(c.Request.Context(), id)
    if err != nil {
        if err == domain.ErrUserNotFound {
            response.Error(c, http.StatusNotFound, "NOT_FOUND", err.Error())
            return
        }
        response.Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
        return
    }

    response.Success(c, http.StatusOK, user)
}

// Create godoc
// @Summary      Crear usuario
// @Description  Crea un nuevo usuario
// @Tags         users
// @Accept       json
// @Produce      json
// @Param        request  body      userApp.CreateUserRequest  true  "Datos del usuario"
// @Success      201      {object}  response.Response{data=userApp.UserResponse}
// @Failure      400      {object}  response.Response
// @Failure      409      {object}  response.Response
// @Router       /users [post]
func (h *UserHandler) Create(c *gin.Context) {
    var req userApp.CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
        return
    }

    user, err := h.service.Create(c.Request.Context(), &req)
    if err != nil {
        if err == domain.ErrUserAlreadyExists {
            response.Error(c, http.StatusConflict, "ALREADY_EXISTS", err.Error())
            return
        }
        response.Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
        return
    }

    response.Success(c, http.StatusCreated, user)
}

// Update godoc
// @Summary      Actualizar usuario
// @Description  Actualiza un usuario existente
// @Tags         users
// @Accept       json
// @Produce      json
// @Param        id       path      int                        true  "User ID"
// @Param        request  body      userApp.UpdateUserRequest  true  "Datos a actualizar"
// @Success      200      {object}  response.Response{data=userApp.UserResponse}
// @Failure      400      {object}  response.Response
// @Failure      404      {object}  response.Response
// @Router       /users/{id} [put]
func (h *UserHandler) Update(c *gin.Context) {
    id, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        response.Error(c, http.StatusBadRequest, "INVALID_ID", "ID inválido")
        return
    }

    var req userApp.UpdateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
        return
    }

    user, err := h.service.Update(c.Request.Context(), id, &req)
    if err != nil {
        if err == domain.ErrUserNotFound {
            response.Error(c, http.StatusNotFound, "NOT_FOUND", err.Error())
            return
        }
        response.Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
        return
    }

    response.Success(c, http.StatusOK, user)
}

// Delete godoc
// @Summary      Eliminar usuario
// @Description  Elimina un usuario por su ID
// @Tags         users
// @Accept       json
// @Produce      json
// @Param        id   path      int  true  "User ID"
// @Success      204  {object}  response.Response
// @Failure      400  {object}  response.Response
// @Failure      404  {object}  response.Response
// @Router       /users/{id} [delete]
func (h *UserHandler) Delete(c *gin.Context) {
    id, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        response.Error(c, http.StatusBadRequest, "INVALID_ID", "ID inválido")
        return
    }

    if err := h.service.Delete(c.Request.Context(), id); err != nil {
        if err == domain.ErrUserNotFound {
            response.Error(c, http.StatusNotFound, "NOT_FOUND", err.Error())
            return
        }
        response.Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
        return
    }

    response.Success(c, http.StatusNoContent, nil)
}
EOF

    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/handler/user_handler.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/handler/user_handler.go

    print_success "Handlers HTTP creados"
}

create_http_response() {
    print_step "Creando response wrapper..."
    
    cat > internal/interfaces/http/response/response.go << 'EOF'
package response

import (
    "github.com/gin-gonic/gin"
)

// Response representa la estructura estándar de respuesta de la API
type Response struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Error   *ErrorInfo  `json:"error,omitempty"`
    Meta    *Meta       `json:"meta,omitempty"`
}

// ErrorInfo contiene información del error
type ErrorInfo struct {
    Code    string `json:"code"`
    Message string `json:"message"`
}

// Meta contiene información de paginación
type Meta struct {
    Page       int `json:"page,omitempty"`
    PerPage    int `json:"per_page,omitempty"`
    Total      int `json:"total,omitempty"`
    TotalPages int `json:"total_pages,omitempty"`
}

// Success envía una respuesta exitosa
func Success(c *gin.Context, status int, data interface{}) {
    c.JSON(status, Response{
        Success: true,
        Data:    data,
    })
}

// Error envía una respuesta de error
func Error(c *gin.Context, status int, code, message string) {
    c.JSON(status, Response{
        Success: false,
        Error: &ErrorInfo{
            Code:    code,
            Message: message,
        },
    })
}

// Paginated envía una respuesta paginada
func Paginated(c *gin.Context, data interface{}, page, perPage, total int) {
    totalPages := (total + perPage - 1) / perPage
    c.JSON(200, Response{
        Success: true,
        Data:    data,
        Meta: &Meta{
            Page:       page,
            PerPage:    perPage,
            Total:      total,
            TotalPages: totalPages,
        },
    })
}
EOF

    print_success "Response wrapper creado"
}

create_http_middleware_recovery() {
    print_step "Creando middleware de recovery..."
    
    cat > internal/interfaces/http/middleware/recovery.go << 'EOF'
package middleware

import (
    "log/slog"
    "net/http"
    "runtime/debug"

    "github.com/gin-gonic/gin"

    "MODULE_NAME/internal/interfaces/http/response"
)

// Recovery middleware que captura panics y retorna un error 500
func Recovery() gin.HandlerFunc {
    return func(c *gin.Context) {
        defer func() {
            if err := recover(); err != nil {
                slog.Error("Panic recuperado",
                    "error", err,
                    "stack", string(debug.Stack()),
                )
                response.Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error interno del servidor")
                c.Abort()
            }
        }()
        c.Next()
    }
}
EOF

    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/middleware/recovery.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/middleware/recovery.go

    print_success "Middleware de recovery creado"
}


# ============================================================
# SECCIÓN 9: GENERADORES DE FEATURES OPCIONALES
# ============================================================

create_feature_jwt() {
    if [[ $FEATURE_JWT -eq 0 ]]; then
        return
    fi
    
    print_step "Creando feature JWT..."
    
    mkdir -p pkg/jwt
    
    cat > pkg/jwt/jwt.go << 'EOF'
package jwt

import (
    "errors"
    "time"

    "github.com/golang-jwt/jwt/v5"
)

var (
    ErrInvalidToken = errors.New("token inválido")
    ErrExpiredToken = errors.New("token expirado")
)

// Claims representa los claims del token JWT
type Claims struct {
    UserID int64  `json:"user_id"`
    Email  string `json:"email"`
    jwt.RegisteredClaims
}

// GenerateToken genera un nuevo token JWT
func GenerateToken(userID int64, email, secret string, expirationHours int) (string, error) {
    claims := &Claims{
        UserID: userID,
        Email:  email,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(expirationHours) * time.Hour)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            NotBefore: jwt.NewNumericDate(time.Now()),
        },
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(secret))
}

// ValidateToken valida un token JWT y retorna los claims
func ValidateToken(tokenString, secret string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, ErrInvalidToken
        }
        return []byte(secret), nil
    })

    if err != nil {
        if errors.Is(err, jwt.ErrTokenExpired) {
            return nil, ErrExpiredToken
        }
        return nil, ErrInvalidToken
    }

    claims, ok := token.Claims.(*Claims)
    if !ok || !token.Valid {
        return nil, ErrInvalidToken
    }

    return claims, nil
}
EOF

    # Crear middleware de auth
    cat > internal/interfaces/http/middleware/auth.go << 'EOF'
package middleware

import (
    "net/http"
    "strings"

    "github.com/gin-gonic/gin"

    "MODULE_NAME/internal/interfaces/http/response"
    "MODULE_NAME/pkg/jwt"
)

// Auth middleware que valida el token JWT
func Auth(secret string) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Token no proporcionado")
            c.Abort()
            return
        }

        // Formato esperado: "Bearer <token>"
        parts := strings.SplitN(authHeader, " ", 2)
        if len(parts) != 2 || parts[0] != "Bearer" {
            response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Formato de token inválido")
            c.Abort()
            return
        }

        claims, err := jwt.ValidateToken(parts[1], secret)
        if err != nil {
            response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", err.Error())
            c.Abort()
            return
        }

        // Guardar claims en el contexto
        c.Set("user_id", claims.UserID)
        c.Set("email", claims.Email)
        c.Next()
    }
}

// GetUserID obtiene el ID del usuario del contexto
func GetUserID(c *gin.Context) (int64, bool) {
    userID, exists := c.Get("user_id")
    if !exists {
        return 0, false
    }
    return userID.(int64), true
}

// GetEmail obtiene el email del usuario del contexto
func GetEmail(c *gin.Context) (string, bool) {
    email, exists := c.Get("email")
    if !exists {
        return "", false
    }
    return email.(string), true
}
EOF

    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/middleware/auth.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/middleware/auth.go

    print_success "Feature JWT creada"
}

create_feature_cors() {
    if [[ $FEATURE_CORS -eq 0 ]]; then
        return
    fi
    
    print_step "Creando feature CORS..."
    
    cat > internal/interfaces/http/middleware/cors.go << 'EOF'
package middleware

import (
    "time"

    "github.com/gin-contrib/cors"
    "github.com/gin-gonic/gin"
)

// CORS configura el middleware de Cross-Origin Resource Sharing
func CORS(allowedOrigins []string) gin.HandlerFunc {
    return cors.New(cors.Config{
        AllowOrigins:     allowedOrigins,
        AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
        AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Request-ID"},
        ExposeHeaders:    []string{"Content-Length", "Content-Type"},
        AllowCredentials: true,
        MaxAge:           12 * time.Hour,
    })
}
EOF

    print_success "Feature CORS creada"
}

create_feature_ratelimit() {
    if [[ $FEATURE_RATELIMIT -eq 0 ]]; then
        return
    fi
    
    print_step "Creando feature Rate Limiting..."
    
    cat > internal/interfaces/http/middleware/ratelimit.go << 'EOF'
package middleware

import (
    "net/http"
    "sync"
    "time"

    "github.com/gin-gonic/gin"
    "golang.org/x/time/rate"

    "MODULE_NAME/internal/interfaces/http/response"
)

type visitor struct {
    limiter  *rate.Limiter
    lastSeen time.Time
}

type rateLimiter struct {
    visitors map[string]*visitor
    mu       sync.RWMutex
    rps      int
    burst    int
}

func newRateLimiter(rps, burst int) *rateLimiter {
    rl := &rateLimiter{
        visitors: make(map[string]*visitor),
        rps:      rps,
        burst:    burst,
    }

    // Limpiar visitantes inactivos cada minuto
    go rl.cleanupVisitors()

    return rl
}

func (rl *rateLimiter) getVisitor(ip string) *rate.Limiter {
    rl.mu.Lock()
    defer rl.mu.Unlock()

    v, exists := rl.visitors[ip]
    if !exists {
        limiter := rate.NewLimiter(rate.Limit(rl.rps), rl.burst)
        rl.visitors[ip] = &visitor{limiter, time.Now()}
        return limiter
    }

    v.lastSeen = time.Now()
    return v.limiter
}

func (rl *rateLimiter) cleanupVisitors() {
    for {
        time.Sleep(time.Minute)
        rl.mu.Lock()
        for ip, v := range rl.visitors {
            if time.Since(v.lastSeen) > 3*time.Minute {
                delete(rl.visitors, ip)
            }
        }
        rl.mu.Unlock()
    }
}

// RateLimit middleware que limita las requests por IP
func RateLimit(rps, burst int) gin.HandlerFunc {
    limiter := newRateLimiter(rps, burst)

    return func(c *gin.Context) {
        ip := c.ClientIP()
        if !limiter.getVisitor(ip).Allow() {
            response.Error(c, http.StatusTooManyRequests, "RATE_LIMIT_EXCEEDED", "Demasiadas solicitudes, intenta más tarde")
            c.Abort()
            return
        }
        c.Next()
    }
}
EOF

    sed -i "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/middleware/ratelimit.go 2>/dev/null || \
    sed -i '' "s|MODULE_NAME|${MODULE_NAME}|g" internal/interfaces/http/middleware/ratelimit.go

    print_success "Feature Rate Limiting creada"
}

create_feature_healthcheck() {
    if [[ $FEATURE_HEALTHCHECK -eq 0 ]]; then
        return
    fi
    
    print_step "Creando feature Health Checks..."
    
    cat > internal/interfaces/http/handler/health_handler.go << 'EOF'
package handler

import (
    "database/sql"
    "net/http"

    "github.com/gin-gonic/gin"
)

type HealthHandler struct {
    db *sql.DB
}

func NewHealthHandler(db *sql.DB) *HealthHandler {
    return &HealthHandler{db: db}
}

// HealthResponse representa la respuesta del health check
type HealthResponse struct {
    Status string `json:"status"`
}

// ReadyResponse representa la respuesta del readiness check
type ReadyResponse struct {
    Status   string            `json:"status"`
    Services map[string]string `json:"services"`
}

// Health godoc
// @Summary      Health check (liveness)
// @Description  Verifica que el servicio está vivo
// @Tags         health
// @Produce      json
// @Success      200  {object}  HealthResponse
// @Router       /health [get]
func (h *HealthHandler) Health(c *gin.Context) {
    c.JSON(http.StatusOK, HealthResponse{
        Status: "ok",
    })
}

// Ready godoc
// @Summary      Readiness check
// @Description  Verifica que el servicio está listo para recibir tráfico
// @Tags         health
// @Produce      json
// @Success      200  {object}  ReadyResponse
// @Failure      503  {object}  ReadyResponse
// @Router       /ready [get]
func (h *HealthHandler) Ready(c *gin.Context) {
    services := make(map[string]string)
    status := http.StatusOK

    // Verificar conexión a base de datos
    if err := h.db.Ping(); err != nil {
        services["database"] = "unhealthy: " + err.Error()
        status = http.StatusServiceUnavailable
    } else {
        services["database"] = "healthy"
    }

    statusText := "ok"
    if status != http.StatusOK {
        statusText = "degraded"
    }

    c.JSON(status, ReadyResponse{
        Status:   statusText,
        Services: services,
    })
}
EOF

    print_success "Feature Health Checks creada"
}

create_feature_logging() {
    if [[ $FEATURE_LOGGING -eq 0 ]]; then
        return
    fi
    
    print_step "Creando feature Logging estructurado..."
    
    mkdir -p pkg/logger
    
    # Logger setup
    cat > pkg/logger/logger.go << 'EOF'
package logger

import (
    "log/slog"
    "os"
)

// Setup configura el logger global según el entorno
func Setup(environment string) {
    var handler slog.Handler

    if environment == "production" {
        // JSON para producción (mejor para log aggregators)
        handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
            Level: slog.LevelInfo,
        })
    } else {
        // Texto colorizado para desarrollo
        handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
            Level: slog.LevelDebug,
        })
    }

    logger := slog.New(handler)
    slog.SetDefault(logger)
}
EOF

    # Logger middleware
    cat > internal/interfaces/http/middleware/logger.go << 'EOF'
package middleware

import (
    "log/slog"
    "time"

    "github.com/gin-gonic/gin"
)

// Logger middleware que registra información de cada request
func Logger() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        path := c.Request.URL.Path
        query := c.Request.URL.RawQuery

        // Procesar request
        c.Next()

        // Calcular latencia
        latency := time.Since(start)
        status := c.Writer.Status()

        // Log con información de la request
        slog.Info("HTTP Request",
            "status", status,
            "method", c.Request.Method,
            "path", path,
            "query", query,
            "ip", c.ClientIP(),
            "user-agent", c.Request.UserAgent(),
            "latency", latency.String(),
            "errors", c.Errors.ByType(gin.ErrorTypePrivate).String(),
        )
    }
}
EOF

    print_success "Feature Logging creada"
}

create_feature_docker() {
    if [[ $FEATURE_DOCKER -eq 0 ]]; then
        return
    fi
    
    print_step "Creando Dockerfile multi-stage..."
    
    cat > Dockerfile << EOF
# ============================================================
# Build stage
# ============================================================
FROM golang:1.23-alpine AS builder

# Instalar certificados y timezone data
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copiar archivos de dependencias primero (mejor cache)
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar binario optimizado
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \\
    -ldflags="-s -w" \\
    -o /app/api \\
    ./cmd/api

# ============================================================
# Run stage
# ============================================================
FROM alpine:3.19

# Instalar certificados para HTTPS
RUN apk --no-cache add ca-certificates tzdata

# Usuario no-root por seguridad
RUN addgroup -g 1000 appgroup && \\
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser

WORKDIR /app

# Copiar binario desde builder
COPY --from=builder /app/api .
COPY --from=builder /app/.env.example .env

# Cambiar a usuario no-root
USER appuser

# Puerto expuesto
EXPOSE ${SERVER_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD wget --no-verbose --tries=1 --spider http://localhost:${SERVER_PORT}/health || exit 1

# Comando por defecto
CMD ["./api"]
EOF

    # Crear .dockerignore
    cat > .dockerignore << 'EOF'
# Git
.git
.gitignore

# Binarios y temporales
bin/
tmp/
*.exe
*.test

# Configuración local
.env
*.log

# IDE
.idea/
.vscode/
*.swp

# Documentación
README.md
docs/

# Tests
*_test.go
coverage.*
EOF

    print_success "Dockerfile multi-stage creado"
}

create_feature_github_actions() {
    if [[ $FEATURE_GITHUB_ACTIONS -eq 0 ]]; then
        return
    fi
    
    print_step "Creando GitHub Actions CI workflow..."
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [main, master, develop]
  pull_request:
    branches: [main, master, develop]

env:
  GO_VERSION: '1.23'

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      
      - name: Install golangci-lint
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest
          args: --timeout=5m

  test:
    name: Test
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      
      - name: Install dependencies
        run: go mod download
      
      - name: Install sqlc
        run: go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
      
      - name: Install migrate
        run: |
          curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz | tar xvz
          sudo mv migrate /usr/local/bin/migrate
      
      - name: Generate sqlc
        run: sqlc generate
      
      - name: Run migrations
        run: |
          migrate -path sql/migrations -database "postgres://postgres:postgres@localhost:5432/test_db?sslmode=disable" up
        env:
          PGPASSWORD: postgres
      
      - name: Run tests
        run: go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_USER: postgres
          DB_PASS: postgres
          DB_NAME: test_db
          SERVER_PORT: 8080
      
      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage.out
          fail_ci_if_error: false

  build:
    name: Build
    runs-on: ubuntu-latest
    needs: [lint, test]
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      
      - name: Install sqlc
        run: go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
      
      - name: Generate sqlc
        run: sqlc generate
      
      - name: Build
        run: |
          CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o bin/api ./cmd/api
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: api-binary
          path: bin/api
          retention-days: 7

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run Gosec Security Scanner
        uses: securego/gosec@master
        with:
          args: '-no-fail -fmt sarif -out results.sarif ./...'
      
      - name: Upload SARIF file
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
        if: always()
EOF

    # Crear workflow de release (opcional, solo si tiene Docker)
    if [[ $FEATURE_DOCKER -eq 1 ]]; then
        cat > .github/workflows/release.yml << 'EOF'
name: Release

on:
  push:
    tags:
      - 'v*'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  release:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=
      
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
EOF
    fi

    # Crear archivo de dependabot
    cat > .github/dependabot.yml << 'EOF'
version: 2
updates:
  - package-ecosystem: "gomod"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    commit-message:
      prefix: "deps"
    labels:
      - "dependencies"
      - "go"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    commit-message:
      prefix: "ci"
    labels:
      - "dependencies"
      - "ci"
EOF

    print_success "GitHub Actions CI creado"
    print_info "Workflows: .github/workflows/ci.yml"
    [[ $FEATURE_DOCKER -eq 1 ]] && print_info "Workflows: .github/workflows/release.yml"
    print_info "Dependabot: .github/dependabot.yml"
}


# ============================================================
# SECCIÓN 10: GENERADORES SQL
# ============================================================

create_sql_schema() {
    print_step "Creando schema SQL..."
    
    cat > sql/schema/user.sql << 'EOF'
-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
EOF

    print_success "Schema SQL creado"
}

create_sql_queries() {
    print_step "Creando queries SQL..."
    
    cat > sql/queries/user.sql << 'EOF'
-- name: ListUsers :many
SELECT id, name, email, created_at, updated_at
FROM users
ORDER BY created_at DESC;

-- name: GetUserByID :one
SELECT id, name, email, created_at, updated_at
FROM users
WHERE id = $1;

-- name: GetUserByEmail :one
SELECT id, name, email, created_at, updated_at
FROM users
WHERE email = $1;

-- name: CreateUser :one
INSERT INTO users (name, email, created_at, updated_at)
VALUES ($1, $2, $3, $4)
RETURNING id, name, email, created_at, updated_at;

-- name: UpdateUser :exec
UPDATE users
SET name = $2, email = $3, updated_at = $4
WHERE id = $1;

-- name: DeleteUser :exec
DELETE FROM users
WHERE id = $1;

-- name: CountUsers :one
SELECT COUNT(*) FROM users;
EOF

    print_success "Queries SQL creadas"
}

create_sql_migrations() {
    print_step "Creando migraciones SQL..."
    
    # Migration UP
    cat > sql/migrations/000001_create_users_table.up.sql << 'EOF'
-- Crear tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear índices
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
EOF

    # Migration DOWN
    cat > sql/migrations/000001_create_users_table.down.sql << 'EOF'
-- Eliminar índices
DROP INDEX IF EXISTS idx_users_created_at;
DROP INDEX IF EXISTS idx_users_email;

-- Eliminar tabla
DROP TABLE IF EXISTS users;
EOF

    print_success "Migraciones SQL creadas"
}

# ============================================================
# SECCIÓN 11: GENERADOR DE ERRORES PERSONALIZADOS
# ============================================================

create_pkg_errors() {
    print_step "Creando package de errores..."
    
    cat > pkg/errors/errors.go << 'EOF'
package errors

import (
    "fmt"
    "net/http"
)

// AppError representa un error de la aplicación
type AppError struct {
    Code       string `json:"code"`
    Message    string `json:"message"`
    StatusCode int    `json:"-"`
    Err        error  `json:"-"`
}

func (e *AppError) Error() string {
    if e.Err != nil {
        return fmt.Sprintf("%s: %v", e.Message, e.Err)
    }
    return e.Message
}

func (e *AppError) Unwrap() error {
    return e.Err
}

// Errores predefinidos
var (
    ErrNotFound = &AppError{
        Code:       "NOT_FOUND",
        Message:    "Recurso no encontrado",
        StatusCode: http.StatusNotFound,
    }

    ErrBadRequest = &AppError{
        Code:       "BAD_REQUEST",
        Message:    "Solicitud inválida",
        StatusCode: http.StatusBadRequest,
    }

    ErrUnauthorized = &AppError{
        Code:       "UNAUTHORIZED",
        Message:    "No autorizado",
        StatusCode: http.StatusUnauthorized,
    }

    ErrForbidden = &AppError{
        Code:       "FORBIDDEN",
        Message:    "Acceso denegado",
        StatusCode: http.StatusForbidden,
    }

    ErrConflict = &AppError{
        Code:       "CONFLICT",
        Message:    "El recurso ya existe",
        StatusCode: http.StatusConflict,
    }

    ErrInternal = &AppError{
        Code:       "INTERNAL_ERROR",
        Message:    "Error interno del servidor",
        StatusCode: http.StatusInternalServerError,
    }
)

// NewAppError crea un nuevo error de aplicación
func NewAppError(code, message string, statusCode int, err error) *AppError {
    return &AppError{
        Code:       code,
        Message:    message,
        StatusCode: statusCode,
        Err:        err,
    }
}

// Wrap envuelve un error existente
func Wrap(err error, message string) *AppError {
    return &AppError{
        Code:       "INTERNAL_ERROR",
        Message:    message,
        StatusCode: http.StatusInternalServerError,
        Err:        err,
    }
}
EOF

    print_success "Package de errores creado"
}

# ============================================================
# SECCIÓN 12: GENERADOR DE README
# ============================================================

create_readme() {
    print_step "Creando README.md..."
    
    local features_list=""
    [[ $FEATURE_JWT -eq 1 ]] && features_list="${features_list}\n- JWT Authentication"
    [[ $FEATURE_SWAGGER -eq 1 ]] && features_list="${features_list}\n- Swagger/OpenAPI"
    [[ $FEATURE_CORS -eq 1 ]] && features_list="${features_list}\n- CORS configurado"
    [[ $FEATURE_RATELIMIT -eq 1 ]] && features_list="${features_list}\n- Rate Limiting"
    [[ $FEATURE_HEALTHCHECK -eq 1 ]] && features_list="${features_list}\n- Health Checks"
    [[ $FEATURE_LOGGING -eq 1 ]] && features_list="${features_list}\n- Logging estructurado"
    [[ $FEATURE_DOCKER -eq 1 ]] && features_list="${features_list}\n- Docker multi-stage"
    [[ $FEATURE_GITHUB_ACTIONS -eq 1 ]] && features_list="${features_list}\n- GitHub Actions CI/CD"
    
    cat > README.md << EOF
# ${PROJECT_NAME}

API REST generada con [Gin API Generator](https://github.com/eondev-inc/gin-generator).

## Tecnologías

- **Go** ${GO_VERSION:-1.21+}
- **Gin** - Framework HTTP
- **sqlc** - Generación de código SQL type-safe
- **PostgreSQL** - Base de datos
- **golang-migrate** - Migraciones de BD

## Features
$(echo -e "$features_list")

## Requisitos

- Go 1.21+
- PostgreSQL 13+
- Make

## Inicio Rápido

\`\`\`bash
# 1. Configurar variables de entorno
cp .env.example .env
# Editar .env con tus credenciales

# 2. Setup completo (herramientas + BD + migraciones)
make setup

# 3. Iniciar servidor con hot-reload
make dev
\`\`\`

El servidor estará disponible en: http://localhost:${SERVER_PORT}

## Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | /api/v1/users | Listar usuarios |
| GET | /api/v1/users/:id | Obtener usuario por ID |
| POST | /api/v1/users | Crear usuario |
| PUT | /api/v1/users/:id | Actualizar usuario |
| DELETE | /api/v1/users/:id | Eliminar usuario |
EOF

    if [[ $FEATURE_HEALTHCHECK -eq 1 ]]; then
        cat >> README.md << 'EOF'
| GET | /health | Health check (liveness) |
| GET | /ready | Readiness check |
EOF
    fi

    if [[ $FEATURE_SWAGGER -eq 1 ]]; then
        cat >> README.md << 'EOF'
| GET | /swagger/* | Documentación Swagger |
EOF
    fi

    cat >> README.md << 'EOF'

## Comandos Disponibles

```bash
make help              # Ver todos los comandos

# Desarrollo
make dev               # Servidor con hot-reload
make run               # Ejecutar servidor
make build             # Compilar binario
make test              # Ejecutar tests
make fmt               # Formatear código

# Base de datos
make db-create         # Crear base de datos
make db-reset          # Resetear base de datos

# Migraciones
make migrate-create name=<nombre>  # Crear migración
make migrate-up                    # Aplicar migraciones
make migrate-down                  # Revertir última migración

# SQLc
make sqlc-generate     # Generar código desde SQL

# Docker
make docker-up         # Iniciar PostgreSQL
make docker-down       # Detener contenedores
```

## Estructura del Proyecto

```
.
├── cmd/api/                    # Entry point
├── internal/
│   ├── domain/                 # Entidades y reglas de negocio
│   │   └── user/
│   ├── application/            # Casos de uso / Servicios
│   │   └── user/
│   ├── infrastructure/         # Implementaciones externas
│   │   ├── config/
│   │   └── persistence/
│   └── interfaces/             # Adaptadores de entrada
│       └── http/
│           ├── handler/
│           ├── middleware/
│           └── response/
├── pkg/                        # Código reutilizable
├── sql/
│   ├── migrations/
│   ├── queries/
│   └── schema/
└── sqldb/                      # Código generado por sqlc
```

## Agregar Nuevo Módulo

```bash
# Usando el generador
./gen-init.sh module product

# Luego regenerar sqlc y aplicar migraciones
make sqlc-generate
make migrate-up
```

## Licencia

MIT
EOF

    print_success "README.md creado"
}


# ============================================================
# SECCIÓN 13: COMANDO MODULE - Agregar nuevos módulos
# ============================================================

create_module() {
    local MOD_NAME="$1"
    local MOD_PASCAL=$(to_pascal_case "$MOD_NAME")
    local MOD_CAMEL=$(to_camel_case "$MOD_NAME")
    
    # Obtener module name desde go.mod
    MODULE_NAME=$(get_module_name_from_gomod)
    if [ -z "$MODULE_NAME" ]; then
        print_error "No se encontró go.mod. Ejecuta este comando desde el directorio del proyecto."
        exit 1
    fi
    
    print_section "Creando módulo: ${MOD_NAME}"
    
    # Crear directorios
    mkdir -p "internal/domain/${MOD_NAME}"
    mkdir -p "internal/application/${MOD_NAME}"
    mkdir -p "internal/infrastructure/persistence/postgres"
    mkdir -p "internal/interfaces/http/handler"
    mkdir -p "sql/schema"
    mkdir -p "sql/queries"
    
    # Domain Entity
    print_step "Creando entidad de dominio..."
    cat > "internal/domain/${MOD_NAME}/entity.go" << EOF
package ${MOD_NAME}

import "time"

// ${MOD_PASCAL} representa la entidad de ${MOD_NAME} en el dominio
type ${MOD_PASCAL} struct {
    ID        int64     \`json:"id"\`
    Name      string    \`json:"name"\`
    CreatedAt time.Time \`json:"created_at"\`
    UpdatedAt time.Time \`json:"updated_at"\`
}

// New${MOD_PASCAL} crea una nueva instancia de ${MOD_PASCAL}
func New${MOD_PASCAL}(name string) *${MOD_PASCAL} {
    now := time.Now()
    return &${MOD_PASCAL}{
        Name:      name,
        CreatedAt: now,
        UpdatedAt: now,
    }
}
EOF

    # Domain Repository Interface
    cat > "internal/domain/${MOD_NAME}/repository.go" << EOF
package ${MOD_NAME}

import "context"

// Repository define las operaciones de persistencia para ${MOD_PASCAL}
type Repository interface {
    FindAll(ctx context.Context) ([]*${MOD_PASCAL}, error)
    FindByID(ctx context.Context, id int64) (*${MOD_PASCAL}, error)
    Create(ctx context.Context, entity *${MOD_PASCAL}) error
    Update(ctx context.Context, entity *${MOD_PASCAL}) error
    Delete(ctx context.Context, id int64) error
}
EOF

    # Domain Errors
    cat > "internal/domain/${MOD_NAME}/errors.go" << EOF
package ${MOD_NAME}

import "errors"

var (
    Err${MOD_PASCAL}NotFound      = errors.New("${MOD_NAME} no encontrado")
    Err${MOD_PASCAL}AlreadyExists = errors.New("${MOD_NAME} ya existe")
)
EOF

    # Application DTO
    print_step "Creando capa de aplicación..."
    cat > "internal/application/${MOD_NAME}/dto.go" << EOF
package ${MOD_NAME}

import (
    "time"

    domain "${MODULE_NAME}/internal/domain/${MOD_NAME}"
)

// Create${MOD_PASCAL}Request representa la solicitud para crear un ${MOD_NAME}
type Create${MOD_PASCAL}Request struct {
    Name string \`json:"name" binding:"required"\`
}

// Update${MOD_PASCAL}Request representa la solicitud para actualizar un ${MOD_NAME}
type Update${MOD_PASCAL}Request struct {
    Name *string \`json:"name,omitempty"\`
}

// ${MOD_PASCAL}Response representa la respuesta de un ${MOD_NAME}
type ${MOD_PASCAL}Response struct {
    ID        int64     \`json:"id"\`
    Name      string    \`json:"name"\`
    CreatedAt time.Time \`json:"created_at"\`
    UpdatedAt time.Time \`json:"updated_at"\`
}

// ToResponse convierte un ${MOD_PASCAL} del dominio a ${MOD_PASCAL}Response
func ToResponse(e *domain.${MOD_PASCAL}) *${MOD_PASCAL}Response {
    return &${MOD_PASCAL}Response{
        ID:        e.ID,
        Name:      e.Name,
        CreatedAt: e.CreatedAt,
        UpdatedAt: e.UpdatedAt,
    }
}

// ToResponseList convierte una lista de ${MOD_PASCAL} a ${MOD_PASCAL}Responses
func ToResponseList(entities []*domain.${MOD_PASCAL}) []*${MOD_PASCAL}Response {
    result := make([]*${MOD_PASCAL}Response, len(entities))
    for i, e := range entities {
        result[i] = ToResponse(e)
    }
    return result
}
EOF

    # Application Service
    cat > "internal/application/${MOD_NAME}/service.go" << EOF
package ${MOD_NAME}

import (
    "context"

    domain "${MODULE_NAME}/internal/domain/${MOD_NAME}"
)

// Service define las operaciones de negocio para ${MOD_NAME}
type Service interface {
    GetAll(ctx context.Context) ([]*${MOD_PASCAL}Response, error)
    GetByID(ctx context.Context, id int64) (*${MOD_PASCAL}Response, error)
    Create(ctx context.Context, req *Create${MOD_PASCAL}Request) (*${MOD_PASCAL}Response, error)
    Update(ctx context.Context, id int64, req *Update${MOD_PASCAL}Request) (*${MOD_PASCAL}Response, error)
    Delete(ctx context.Context, id int64) error
}

type service struct {
    repo domain.Repository
}

// NewService crea una nueva instancia del servicio de ${MOD_NAME}
func NewService(repo domain.Repository) Service {
    return &service{repo: repo}
}

func (s *service) GetAll(ctx context.Context) ([]*${MOD_PASCAL}Response, error) {
    entities, err := s.repo.FindAll(ctx)
    if err != nil {
        return nil, err
    }
    return ToResponseList(entities), nil
}

func (s *service) GetByID(ctx context.Context, id int64) (*${MOD_PASCAL}Response, error) {
    entity, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, err
    }
    return ToResponse(entity), nil
}

func (s *service) Create(ctx context.Context, req *Create${MOD_PASCAL}Request) (*${MOD_PASCAL}Response, error) {
    entity := domain.New${MOD_PASCAL}(req.Name)
    if err := s.repo.Create(ctx, entity); err != nil {
        return nil, err
    }
    return ToResponse(entity), nil
}

func (s *service) Update(ctx context.Context, id int64, req *Update${MOD_PASCAL}Request) (*${MOD_PASCAL}Response, error) {
    entity, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, err
    }

    if req.Name != nil {
        entity.Name = *req.Name
    }
    entity.UpdatedAt = time.Now()

    if err := s.repo.Update(ctx, entity); err != nil {
        return nil, err
    }
    return ToResponse(entity), nil
}

func (s *service) Delete(ctx context.Context, id int64) error {
    if _, err := s.repo.FindByID(ctx, id); err != nil {
        return err
    }
    return s.repo.Delete(ctx, id)
}
EOF

    # Agregar import de time
    sed -i '5a\    "time"' "internal/application/${MOD_NAME}/service.go" 2>/dev/null || \
    sed -i '' '5a\
    "time"
' "internal/application/${MOD_NAME}/service.go"

    # SQL Schema
    print_step "Creando schema y queries SQL..."
    cat > "sql/schema/${MOD_NAME}.sql" << EOF
-- Tabla de ${MOD_NAME}s
CREATE TABLE IF NOT EXISTS ${MOD_NAME}s (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_${MOD_NAME}s_name ON ${MOD_NAME}s(name);
CREATE INDEX IF NOT EXISTS idx_${MOD_NAME}s_created_at ON ${MOD_NAME}s(created_at);
EOF

    # SQL Queries
    cat > "sql/queries/${MOD_NAME}.sql" << EOF
-- name: List${MOD_PASCAL}s :many
SELECT id, name, created_at, updated_at
FROM ${MOD_NAME}s
ORDER BY created_at DESC;

-- name: Get${MOD_PASCAL}ByID :one
SELECT id, name, created_at, updated_at
FROM ${MOD_NAME}s
WHERE id = \$1;

-- name: Create${MOD_PASCAL} :one
INSERT INTO ${MOD_NAME}s (name, created_at, updated_at)
VALUES (\$1, \$2, \$3)
RETURNING id, name, created_at, updated_at;

-- name: Update${MOD_PASCAL} :exec
UPDATE ${MOD_NAME}s
SET name = \$2, updated_at = \$3
WHERE id = \$1;

-- name: Delete${MOD_PASCAL} :exec
DELETE FROM ${MOD_NAME}s
WHERE id = \$1;
EOF

    # Crear migración
    print_step "Creando migración..."
    local NEXT_NUM="000001"
    if [ -d "sql/migrations" ]; then
        local LAST_FILE=$(ls sql/migrations/*.up.sql 2>/dev/null | sort | tail -1)
        if [ -n "$LAST_FILE" ]; then
            local LAST_NUM=$(basename "$LAST_FILE" | cut -d'_' -f1)
            NEXT_NUM=$(printf "%06d" $((10#$LAST_NUM + 1)))
        fi
    fi
    
    cat > "sql/migrations/${NEXT_NUM}_create_${MOD_NAME}s_table.up.sql" << EOF
-- Crear tabla de ${MOD_NAME}s
CREATE TABLE IF NOT EXISTS ${MOD_NAME}s (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_${MOD_NAME}s_name ON ${MOD_NAME}s(name);
CREATE INDEX IF NOT EXISTS idx_${MOD_NAME}s_created_at ON ${MOD_NAME}s(created_at);
EOF

    cat > "sql/migrations/${NEXT_NUM}_create_${MOD_NAME}s_table.down.sql" << EOF
DROP INDEX IF EXISTS idx_${MOD_NAME}s_created_at;
DROP INDEX IF EXISTS idx_${MOD_NAME}s_name;
DROP TABLE IF EXISTS ${MOD_NAME}s;
EOF

    # Infrastructure Repository Implementation
    print_step "Creando implementación del repositorio..."
    cat > "internal/infrastructure/persistence/postgres/${MOD_NAME}_repository.go" << EOF
package postgres

import (
    "context"
    "database/sql"
    "time"

    domain "${MODULE_NAME}/internal/domain/${MOD_NAME}"
    "${MODULE_NAME}/sqldb"
)

type ${MOD_CAMEL}Repository struct {
    db      *sql.DB
    queries *sqldb.Queries
}

// New${MOD_PASCAL}Repository crea una nueva instancia del repositorio de ${MOD_NAME}
func New${MOD_PASCAL}Repository(db *sql.DB) domain.Repository {
    return &${MOD_CAMEL}Repository{
        db:      db,
        queries: sqldb.New(db),
    }
}

func (r *${MOD_CAMEL}Repository) FindAll(ctx context.Context) ([]*domain.${MOD_PASCAL}, error) {
    rows, err := r.queries.List${MOD_PASCAL}s(ctx)
    if err != nil {
        return nil, err
    }

    result := make([]*domain.${MOD_PASCAL}, len(rows))
    for i, row := range rows {
        result[i] = &domain.${MOD_PASCAL}{
            ID:        row.ID,
            Name:      row.Name,
            CreatedAt: row.CreatedAt.Time,
            UpdatedAt: row.UpdatedAt.Time,
        }
    }
    return result, nil
}

func (r *${MOD_CAMEL}Repository) FindByID(ctx context.Context, id int64) (*domain.${MOD_PASCAL}, error) {
    row, err := r.queries.Get${MOD_PASCAL}ByID(ctx, id)
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, domain.Err${MOD_PASCAL}NotFound
        }
        return nil, err
    }

    return &domain.${MOD_PASCAL}{
        ID:        row.ID,
        Name:      row.Name,
        CreatedAt: row.CreatedAt.Time,
        UpdatedAt: row.UpdatedAt.Time,
    }, nil
}

func (r *${MOD_CAMEL}Repository) Create(ctx context.Context, entity *domain.${MOD_PASCAL}) error {
    row, err := r.queries.Create${MOD_PASCAL}(ctx, sqldb.Create${MOD_PASCAL}Params{
        Name:      entity.Name,
        CreatedAt: sql.NullTime{Time: entity.CreatedAt, Valid: true},
        UpdatedAt: sql.NullTime{Time: entity.UpdatedAt, Valid: true},
    })
    if err != nil {
        return err
    }
    entity.ID = row.ID
    return nil
}

func (r *${MOD_CAMEL}Repository) Update(ctx context.Context, entity *domain.${MOD_PASCAL}) error {
    return r.queries.Update${MOD_PASCAL}(ctx, sqldb.Update${MOD_PASCAL}Params{
        ID:        entity.ID,
        Name:      entity.Name,
        UpdatedAt: sql.NullTime{Time: time.Now(), Valid: true},
    })
}

func (r *${MOD_CAMEL}Repository) Delete(ctx context.Context, id int64) error {
    return r.queries.Delete${MOD_PASCAL}(ctx, id)
}
EOF

    # HTTP Handler
    print_step "Creando handler HTTP..."
    cat > "internal/interfaces/http/handler/${MOD_NAME}_handler.go" << EOF
package handler

import (
    "net/http"
    "strconv"

    "github.com/gin-gonic/gin"

    app "${MODULE_NAME}/internal/application/${MOD_NAME}"
    domain "${MODULE_NAME}/internal/domain/${MOD_NAME}"
    "${MODULE_NAME}/internal/interfaces/http/response"
)

type ${MOD_PASCAL}Handler struct {
    service app.Service
}

// New${MOD_PASCAL}Handler crea una nueva instancia del handler de ${MOD_NAME}
func New${MOD_PASCAL}Handler(service app.Service) *${MOD_PASCAL}Handler {
    return &${MOD_PASCAL}Handler{service: service}
}

// GetAll obtiene todos los ${MOD_NAME}s
// @Summary Lista todos los ${MOD_NAME}s
// @Tags ${MOD_NAME}s
// @Accept json
// @Produce json
// @Success 200 {object} response.Response{data=[]app.${MOD_PASCAL}Response}
// @Router /${MOD_NAME}s [get]
func (h *${MOD_PASCAL}Handler) GetAll(c *gin.Context) {
    ${MOD_CAMEL}s, err := h.service.GetAll(c.Request.Context())
    if err != nil {
        response.Error(c, http.StatusInternalServerError, "Error al obtener ${MOD_NAME}s", err.Error())
        return
    }
    response.Success(c, http.StatusOK, "${MOD_PASCAL}s obtenidos exitosamente", ${MOD_CAMEL}s)
}

// GetByID obtiene un ${MOD_NAME} por ID
// @Summary Obtiene un ${MOD_NAME} por ID
// @Tags ${MOD_NAME}s
// @Accept json
// @Produce json
// @Param id path int true "${MOD_PASCAL} ID"
// @Success 200 {object} response.Response{data=app.${MOD_PASCAL}Response}
// @Failure 404 {object} response.Response
// @Router /${MOD_NAME}s/{id} [get]
func (h *${MOD_PASCAL}Handler) GetByID(c *gin.Context) {
    id, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        response.Error(c, http.StatusBadRequest, "ID inválido", err.Error())
        return
    }

    ${MOD_CAMEL}, err := h.service.GetByID(c.Request.Context(), id)
    if err != nil {
        if err == domain.Err${MOD_PASCAL}NotFound {
            response.Error(c, http.StatusNotFound, "${MOD_PASCAL} no encontrado", "")
            return
        }
        response.Error(c, http.StatusInternalServerError, "Error al obtener ${MOD_NAME}", err.Error())
        return
    }
    response.Success(c, http.StatusOK, "${MOD_PASCAL} obtenido exitosamente", ${MOD_CAMEL})
}

// Create crea un nuevo ${MOD_NAME}
// @Summary Crea un nuevo ${MOD_NAME}
// @Tags ${MOD_NAME}s
// @Accept json
// @Produce json
// @Param ${MOD_NAME} body app.Create${MOD_PASCAL}Request true "Datos del ${MOD_NAME}"
// @Success 201 {object} response.Response{data=app.${MOD_PASCAL}Response}
// @Failure 400 {object} response.Response
// @Router /${MOD_NAME}s [post]
func (h *${MOD_PASCAL}Handler) Create(c *gin.Context) {
    var req app.Create${MOD_PASCAL}Request
    if err := c.ShouldBindJSON(&req); err != nil {
        response.Error(c, http.StatusBadRequest, "Datos inválidos", err.Error())
        return
    }

    ${MOD_CAMEL}, err := h.service.Create(c.Request.Context(), &req)
    if err != nil {
        response.Error(c, http.StatusInternalServerError, "Error al crear ${MOD_NAME}", err.Error())
        return
    }
    response.Success(c, http.StatusCreated, "${MOD_PASCAL} creado exitosamente", ${MOD_CAMEL})
}

// Update actualiza un ${MOD_NAME}
// @Summary Actualiza un ${MOD_NAME}
// @Tags ${MOD_NAME}s
// @Accept json
// @Produce json
// @Param id path int true "${MOD_PASCAL} ID"
// @Param ${MOD_NAME} body app.Update${MOD_PASCAL}Request true "Datos a actualizar"
// @Success 200 {object} response.Response{data=app.${MOD_PASCAL}Response}
// @Failure 404 {object} response.Response
// @Router /${MOD_NAME}s/{id} [put]
func (h *${MOD_PASCAL}Handler) Update(c *gin.Context) {
    id, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        response.Error(c, http.StatusBadRequest, "ID inválido", err.Error())
        return
    }

    var req app.Update${MOD_PASCAL}Request
    if err := c.ShouldBindJSON(&req); err != nil {
        response.Error(c, http.StatusBadRequest, "Datos inválidos", err.Error())
        return
    }

    ${MOD_CAMEL}, err := h.service.Update(c.Request.Context(), id, &req)
    if err != nil {
        if err == domain.Err${MOD_PASCAL}NotFound {
            response.Error(c, http.StatusNotFound, "${MOD_PASCAL} no encontrado", "")
            return
        }
        response.Error(c, http.StatusInternalServerError, "Error al actualizar ${MOD_NAME}", err.Error())
        return
    }
    response.Success(c, http.StatusOK, "${MOD_PASCAL} actualizado exitosamente", ${MOD_CAMEL})
}

// Delete elimina un ${MOD_NAME}
// @Summary Elimina un ${MOD_NAME}
// @Tags ${MOD_NAME}s
// @Accept json
// @Produce json
// @Param id path int true "${MOD_PASCAL} ID"
// @Success 200 {object} response.Response
// @Failure 404 {object} response.Response
// @Router /${MOD_NAME}s/{id} [delete]
func (h *${MOD_PASCAL}Handler) Delete(c *gin.Context) {
    id, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        response.Error(c, http.StatusBadRequest, "ID inválido", err.Error())
        return
    }

    if err := h.service.Delete(c.Request.Context(), id); err != nil {
        if err == domain.Err${MOD_PASCAL}NotFound {
            response.Error(c, http.StatusNotFound, "${MOD_PASCAL} no encontrado", "")
            return
        }
        response.Error(c, http.StatusInternalServerError, "Error al eliminar ${MOD_NAME}", err.Error())
        return
    }
    response.Success(c, http.StatusOK, "${MOD_PASCAL} eliminado exitosamente", nil)
}
EOF

    echo ""
    print_success "Módulo '${MOD_NAME}' creado exitosamente"
    echo ""
    echo -e "${WHITE}Archivos generados:${RESET}"
    echo ""
    echo -e "  ${GREEN}Domain:${RESET}"
    echo -e "    internal/domain/${MOD_NAME}/entity.go"
    echo -e "    internal/domain/${MOD_NAME}/repository.go"
    echo -e "    internal/domain/${MOD_NAME}/errors.go"
    echo ""
    echo -e "  ${GREEN}Application:${RESET}"
    echo -e "    internal/application/${MOD_NAME}/dto.go"
    echo -e "    internal/application/${MOD_NAME}/service.go"
    echo ""
    echo -e "  ${GREEN}Infrastructure:${RESET}"
    echo -e "    internal/infrastructure/persistence/postgres/${MOD_NAME}_repository.go"
    echo ""
    echo -e "  ${GREEN}Interfaces:${RESET}"
    echo -e "    internal/interfaces/http/handler/${MOD_NAME}_handler.go"
    echo ""
    echo -e "  ${GREEN}SQL:${RESET}"
    echo -e "    sql/schema/${MOD_NAME}.sql"
    echo -e "    sql/queries/${MOD_NAME}.sql"
    echo -e "    sql/migrations/${NEXT_NUM}_create_${MOD_NAME}s_table.up.sql"
    echo -e "    sql/migrations/${NEXT_NUM}_create_${MOD_NAME}s_table.down.sql"
    echo ""
    echo -e "${YELLOW}Próximos pasos:${RESET}"
    echo ""
    echo -e "  1. Regenerar código sqlc:"
    echo -e "     ${CYAN}make sqlc-generate${RESET}"
    echo ""
    echo -e "  2. Registrar las rutas en el router:"
    echo -e "     ${CYAN}internal/interfaces/http/router/router.go${RESET}"
    echo ""
    echo -e "     Ejemplo de código a agregar:"
    echo -e "     ${CYAN}// ${MOD_PASCAL}s"
    echo -e "     ${MOD_NAME}Repo := postgres.New${MOD_PASCAL}Repository(db)"
    echo -e "     ${MOD_NAME}Svc := ${MOD_NAME}App.NewService(${MOD_NAME}Repo)"
    echo -e "     ${MOD_NAME}Handler := handler.New${MOD_PASCAL}Handler(${MOD_NAME}Svc)"
    echo -e "     "
    echo -e "     ${MOD_NAME}s := api.Group(\"/${MOD_NAME}s\")"
    echo -e "     {"
    echo -e "         ${MOD_NAME}s.GET(\"\", ${MOD_NAME}Handler.GetAll)"
    echo -e "         ${MOD_NAME}s.GET(\"/:id\", ${MOD_NAME}Handler.GetByID)"
    echo -e "         ${MOD_NAME}s.POST(\"\", ${MOD_NAME}Handler.Create)"
    echo -e "         ${MOD_NAME}s.PUT(\"/:id\", ${MOD_NAME}Handler.Update)"
    echo -e "         ${MOD_NAME}s.DELETE(\"/:id\", ${MOD_NAME}Handler.Delete)"
    echo -e "     }${RESET}"
    echo ""
    echo -e "  3. Aplicar migraciones:"
    echo -e "     ${CYAN}make migrate-up${RESET}"
    echo ""
}


# ============================================================
# SECCIÓN 14: FUNCIÓN PRINCIPAL DE GENERACIÓN
# ============================================================

generate_project() {
    echo ""
    print_section "Generando proyecto..."
    
    create_directory_structure
    create_go_mod
    create_env_example
    create_gitignore
    create_docker_compose
    create_air_config
    create_sqlc_config
    create_makefile
    create_config
    
    # Capas DDD
    create_domain_user
    create_application_user
    create_infrastructure_postgres
    create_infrastructure_repository
    
    # HTTP Layer
    create_http_server
    create_http_router
    create_http_handlers
    create_http_response
    create_http_middleware_recovery
    
    # Features opcionales
    create_feature_jwt
    create_feature_cors
    create_feature_ratelimit
    create_feature_healthcheck
    create_feature_logging
    create_feature_docker
    create_feature_github_actions
    
    # SQL
    create_sql_schema
    create_sql_queries
    create_sql_migrations
    
    # Extras
    create_pkg_errors
    create_main_go
    create_readme
    
    # Generar sqlc
    print_step "Generando código sqlc..."
    if command -v sqlc &> /dev/null; then
        sqlc generate 2>/dev/null || print_warning "sqlc no pudo generar código. Ejecuta 'make sqlc-generate' después de instalar sqlc"
    else
        print_warning "sqlc no está instalado. Ejecuta 'make install-tools' para instalarlo"
    fi
    
    # Formatear código
    print_step "Formateando código..."
    go fmt ./... 2>/dev/null || true
    
    # Tidy
    print_step "Organizando dependencias..."
    go mod tidy 2>/dev/null || true
    
    echo ""
    print_success "¡Proyecto generado exitosamente!"
    echo ""
}

show_post_generation_message() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║              ✨ ¡Proyecto creado con éxito! ✨             ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    echo -e "${WHITE}Próximos pasos:${RESET}"
    echo ""
    echo -e "  ${CYAN}cd ${PROJECT_NAME}${RESET}"
    echo ""
    echo -e "  ${WHITE}1.${RESET} Revisar configuración:"
    echo -e "     ${CYAN}nano .env${RESET}"
    echo ""
    echo -e "  ${WHITE}2.${RESET} Iniciar PostgreSQL (si usas Docker):"
    echo -e "     ${CYAN}make docker-up${RESET}"
    echo ""
    echo -e "  ${WHITE}3.${RESET} Setup completo:"
    echo -e "     ${CYAN}make setup${RESET}"
    echo ""
    echo -e "  ${WHITE}4.${RESET} Iniciar desarrollo:"
    echo -e "     ${CYAN}make dev${RESET}"
    echo ""
    echo -e "${WHITE}El servidor estará disponible en:${RESET}"
    echo -e "  ${GREEN}http://localhost:${SERVER_PORT}${RESET}"
    echo ""
    
    if [[ $FEATURE_SWAGGER -eq 1 ]]; then
        echo -e "${WHITE}Documentación Swagger:${RESET}"
        echo -e "  ${GREEN}http://localhost:${SERVER_PORT}/swagger/index.html${RESET}"
        echo ""
    fi
    
    echo -e "${WHITE}Comandos útiles:${RESET}"
    echo -e "  ${CYAN}make help${RESET}          - Ver todos los comandos"
    echo -e "  ${CYAN}make dev${RESET}           - Servidor con hot-reload"
    echo -e "  ${CYAN}make test${RESET}          - Ejecutar tests"
    echo -e "  ${CYAN}make sqlc-generate${RESET} - Regenerar código SQL"
    echo ""
}

# ============================================================
# SECCIÓN 15: COMANDOS Y ENTRY POINT
# ============================================================

cmd_init() {
    # Verificar herramientas (a menos que se use --skip-check)
    if ! skip_tool_check "$@"; then
        check_required_tools
    fi
    
    run_wizard
    generate_project
    show_post_generation_message
}

cmd_module() {
    local MOD_NAME="$1"
    if [ -z "$MOD_NAME" ]; then
        print_error "Debes especificar el nombre del módulo"
        echo ""
        echo "Uso: $0 module <nombre_modulo>"
        echo "Ejemplo: $0 module product"
        exit 1
    fi
    
    # Validar nombre
    if [[ ! "$MOD_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
        print_error "Nombre de módulo inválido. Usa solo letras minúsculas, números y guiones bajos."
        exit 1
    fi
    
    create_module "$MOD_NAME"
}

cmd_generate() {
    print_step "Regenerando código sqlc..."
    
    if ! command -v sqlc &> /dev/null; then
        print_error "sqlc no está instalado"
        echo "Instálalo con: go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest"
        exit 1
    fi
    
    if [ ! -f "sqlc.yaml" ]; then
        print_error "No se encontró sqlc.yaml"
        echo "Ejecuta este comando desde el directorio del proyecto"
        exit 1
    fi
    
    sqlc generate
    print_success "Código regenerado en sqldb/"
    echo "Ejecuta: go mod tidy"
}

cmd_help() {
    print_banner
    
    echo -e "${WHITE}Uso:${RESET}"
    echo "  $0 [comando] [opciones]"
    echo ""
    echo -e "${WHITE}Comandos:${RESET}"
    echo -e "  ${GREEN}init${RESET}                      Inicia el wizard interactivo para crear un proyecto"
    echo -e "  ${GREEN}quick${RESET} <nombre> [modulo]   Crea un proyecto rápidamente (no interactivo)"
    echo -e "  ${GREEN}module${RESET} <nombre>           Agrega un nuevo módulo al proyecto existente"
    echo -e "  ${GREEN}generate${RESET}                  Regenera el código sqlc"
    echo -e "  ${GREEN}help${RESET}                      Muestra esta ayuda"
    echo ""
    echo -e "${WHITE}Opciones globales:${RESET}"
    echo -e "  ${GREEN}--skip-check${RESET}, ${GREEN}-s${RESET}           Omite la verificación de herramientas instaladas"
    echo ""
    echo -e "${WHITE}Ejemplos:${RESET}"
    echo "  $0 init                              # Wizard interactivo"
    echo "  $0 init --skip-check                 # Sin verificación de herramientas"
    echo "  $0 quick mi-api                      # Crear proyecto rápido"
    echo "  $0 quick mi-api github.com/user/api  # Con módulo específico"
    echo "  $0 module product                    # Agregar módulo 'product'"
    echo "  $0 generate                          # Regenerar código sqlc"
    echo ""
    echo -e "${WHITE}Herramientas requeridas:${RESET}"
    echo "  - bash 4.0+       Para ejecutar el generador"
    echo "  - git             Para control de versiones"
    echo "  - go 1.21+        Para compilar proyectos generados"
    echo "  - make            Para comandos de desarrollo"
    echo ""
    echo -e "${WHITE}Herramientas opcionales:${RESET}"
    echo "  - docker          Para PostgreSQL en contenedor"
    echo "  - psql            Cliente PostgreSQL"
    echo "  - sqlc, migrate, air se instalan con 'make install-tools'"
    echo ""
    echo -e "${WHITE}Más información:${RESET}"
    echo "  https://github.com/eondev-inc/gin-generator"
    echo ""
}

# ============================================================
# COMANDO QUICK - Generación no interactiva
# ============================================================

cmd_quick() {
    local name="$1"
    local module="$2"
    
    if [ -z "$name" ]; then
        print_error "Uso: $0 quick <nombre> [modulo]"
        exit 1
    fi
    
    PROJECT_NAME="$name"
    MODULE_NAME="${module:-github.com/user/$name}"
    DB_NAME="${name//-/_}_db"
    
    print_banner
    
    # Verificar herramientas
    check_required_tools
    
    print_info "Modo rápido (no interactivo)"
    echo ""
    echo -e "  Proyecto: ${GREEN}$PROJECT_NAME${RESET}"
    echo -e "  Módulo:   ${GREEN}$MODULE_NAME${RESET}"
    echo -e "  Puerto:   ${GREEN}$SERVER_PORT${RESET}"
    echo -e "  BD:       ${GREEN}$DB_NAME${RESET}"
    echo -e "  Features: ${GREEN}Todas habilitadas${RESET}"
    echo ""
    
    generate_project
    show_post_generation_message
}

# ============================================================
# MAIN
# ============================================================

main() {
    local COMMAND="${1:-}"
    
    case "$COMMAND" in
        init|"")
            shift 2>/dev/null || true  # Remover 'init' de los argumentos
            cmd_init "$@"
            ;;
        quick)
            cmd_quick "$2" "$3"
            ;;
        module)
            cmd_module "$2"
            ;;
        generate)
            cmd_generate
            ;;
        help|--help|-h)
            cmd_help
            ;;
        version|--version|-v)
            echo "Gin API Generator v${VERSION}"
            ;;
        --skip-check|-s)
            # Si pasan --skip-check primero, ejecutar init con el flag
            shift
            cmd_init "--skip-check" "$@"
            ;;
        *)
            print_error "Comando no reconocido: $COMMAND"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

# Ejecutar
main "$@"
