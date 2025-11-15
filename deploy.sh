#!/bin/bash

##############################################################################
# Database Services Deployment Script
# Deploys MySQL, PostgreSQL, and Redis using Docker Compose
# Version: 1.0 (Production)
##############################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Safer Internal Field Separator

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and log file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/deployment-$(date +%Y%m%d-%H%M%S).log"

# Deployment mode
CLEAN_DEPLOY=false
UPDATE_DEPLOY=false

##############################################################################
# Logging Functions
##############################################################################

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "\n${BLUE}===================================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}===================================================${NC}\n" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}" | tee -a "$LOG_FILE"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    --clean         Clean deployment (removes all data and starts fresh)
    --update        Update deployment (keeps existing data)
    --help          Show this help message

EXAMPLES:
    $0 --clean      # Fresh deployment with clean data directories
    $0 --update     # Update/restart services keeping existing data
    $0              # Interactive mode (will prompt for deployment type)

EOF
    exit 0
}

##############################################################################
# Pre-flight Checks
##############################################################################

check_prerequisites() {
    print_header "Pre-flight Checks"

    # Check if Docker is installed
    print_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed!"
        exit 1
    fi
    print_success "Docker is installed: $(docker --version)"

    # Check if Docker Compose is available
    print_info "Checking Docker Compose..."
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available!"
        exit 1
    fi
    print_success "Docker Compose is available: $(docker compose version)"

    # Check if Docker daemon is running
    print_info "Checking Docker daemon..."
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running!"
        exit 1
    fi
    print_success "Docker daemon is running"

    # Check if .env file exists
    print_info "Checking environment configuration..."
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        print_error ".env file not found!"
        print_warning "Please create .env file from .env.example"
        exit 1
    fi
    print_success ".env file found"

    # Load environment variables
    source "$SCRIPT_DIR/.env"

    # Check if docker-compose.yml exists
    print_info "Checking docker-compose.yml..."
    if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found!"
        exit 1
    fi
    print_success "docker-compose.yml found"

    # Check disk space
    print_info "Checking disk space..."
    local available_space=$(df -BG "$DATA_DIR" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ -z "$available_space" ]; then
        print_warning "Could not check disk space"
    elif [ "$available_space" -lt 5 ]; then
        print_warning "Low disk space: ${available_space}GB available (recommend at least 5GB)"
    else
        print_success "Sufficient disk space: ${available_space}GB available"
    fi

    # Check if data directory exists
    print_info "Checking data directory..."
    if [ ! -d "$DATA_DIR" ]; then
        print_warning "Data directory does not exist, will create: $DATA_DIR"
        sudo mkdir -p "$DATA_DIR"
    fi
    print_success "Data directory: $DATA_DIR"

    print_success "All pre-flight checks passed"
}

##############################################################################
# Deployment Steps
##############################################################################

step_cleanup() {
    print_header "Cleaning Up Existing Deployment"

    print_info "Stopping and removing containers..."
    docker compose down -v 2>/dev/null || true
    print_success "Containers stopped and removed"

    if [ "$CLEAN_DEPLOY" = true ]; then
        print_warning "CLEAN DEPLOY: Removing all data directories..."
        print_warning "This will delete all existing database data!"

        # Backup existing data before deletion
        if [ -d "$DATA_DIR/mysql" ] || [ -d "$DATA_DIR/postgres" ] || [ -d "$DATA_DIR/redis" ]; then
            local backup_dir="$DATA_DIR/backup-$(date +%Y%m%d-%H%M%S)"
            print_info "Creating backup at: $backup_dir"
            sudo mkdir -p "$backup_dir"
            [ -d "$DATA_DIR/mysql" ] && sudo mv "$DATA_DIR/mysql" "$backup_dir/" || true
            [ -d "$DATA_DIR/postgres" ] && sudo mv "$DATA_DIR/postgres" "$backup_dir/" || true
            [ -d "$DATA_DIR/redis" ] && sudo mv "$DATA_DIR/redis" "$backup_dir/" || true
            print_success "Backup created at: $backup_dir"
        fi

        sudo mkdir -p "$DATA_DIR"/{mysql,postgres,redis}
        print_success "Data directories cleaned and recreated"
    else
        print_info "UPDATE MODE: Keeping existing data directories"
        sudo mkdir -p "$DATA_DIR"/{mysql,postgres,redis}
        print_success "Data directories verified"
    fi

    print_info "Verifying clean state..."
    ls -la "$DATA_DIR/" >> "$LOG_FILE" 2>&1
    print_success "Cleanup completed"
}

step_deploy() {
    print_header "Deploying Services"

    print_info "Pulling latest images..."
    docker compose pull 2>&1 | tee -a "$LOG_FILE"

    print_info "Starting Docker Compose services..."
    docker compose up -d 2>&1 | tee -a "$LOG_FILE"
    print_success "Services started"
}

step_wait_healthy() {
    print_header "Waiting for Services to be Healthy"

    local services=("mysql_db" "postgres_db" "redis_db")
    local max_wait=120  # Increased for production
    local waited=0

    for service in "${services[@]}"; do
        print_info "Waiting for $service to be healthy..."
        waited=0

        while [ $waited -lt $max_wait ]; do
            health_status=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "starting")

            if [ "$health_status" = "healthy" ]; then
                print_success "$service is healthy (${waited}s)"
                break
            elif [ "$health_status" = "unhealthy" ]; then
                print_error "$service is unhealthy!"
                print_info "Checking logs..."
                docker compose logs --tail 50 "$service" | tee -a "$LOG_FILE"
                return 1
            fi

            echo -n "."
            sleep 2
            waited=$((waited + 2))
        done

        if [ $waited -ge $max_wait ]; then
            print_error "$service failed to become healthy within ${max_wait}s"
            print_info "Checking logs..."
            docker compose logs --tail 50 "$service" | tee -a "$LOG_FILE"
            return 1
        fi
    done

    print_success "All services are healthy"

    # Grace period for services to complete initialization
    print_info "Waiting for services to complete initialization..."
    sleep 10
    print_success "Initialization grace period completed"
}

step_verify() {
    print_header "Verifying Connectivity"

    # Test MySQL
    print_info "Testing MySQL connection..."
    if docker exec mysql_db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION(); SHOW DATABASES;" 2>&1 | grep -q "$MYSQL_DATABASE"; then
        print_success "MySQL: Connected successfully (database: $MYSQL_DATABASE)"
    else
        print_error "MySQL: Connection failed"
        docker compose logs --tail 30 mysql | tee -a "$LOG_FILE"
        return 1
    fi

    # Test PostgreSQL
    print_info "Testing PostgreSQL connection..."
    if docker exec postgres_db psql -U "$POSTGRES_ROOT_USER" -d "$POSTGRES_DB" -c "SELECT version();" 2>&1 | grep -q "PostgreSQL"; then
        print_success "PostgreSQL: Connected successfully"
    else
        print_error "PostgreSQL: Connection failed"
        docker compose logs --tail 30 postgres | tee -a "$LOG_FILE"
        return 1
    fi

    # Test Redis
    print_info "Testing Redis connection..."
    if docker exec redis_db redis-cli -a "$REDIS_PASSWORD" --no-auth-warning PING 2>&1 | grep -q "PONG"; then
        print_success "Redis: Connected successfully"
    else
        print_error "Redis: Connection failed"
        docker compose logs --tail 30 redis | tee -a "$LOG_FILE"
        return 1
    fi

    print_success "All connectivity tests passed"
}

step_summary() {
    print_header "Deployment Summary"

    echo -e "${GREEN}All services deployed successfully!${NC}\n" | tee -a "$LOG_FILE"

    # Get container status
    docker compose ps | tee -a "$LOG_FILE"

    echo -e "\n${BLUE}Service Details:${NC}" | tee -a "$LOG_FILE"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"

    # MySQL info
    mysql_version=$(docker exec mysql_db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" 2>/dev/null | tail -n1)
    echo -e "${GREEN}MySQL${NC}" | tee -a "$LOG_FILE"
    echo -e "  Version: $mysql_version" | tee -a "$LOG_FILE"
    echo -e "  Port: ${MYSQL_PORT}" | tee -a "$LOG_FILE"
    echo -e "  Database: $MYSQL_DATABASE" | tee -a "$LOG_FILE"
    echo -e "  User: $MYSQL_USER" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # PostgreSQL info
    postgres_version=$(docker exec postgres_db psql -U "$POSTGRES_ROOT_USER" -d "$POSTGRES_DB" -t -c "SELECT version();" 2>/dev/null | head -n1 | xargs)
    echo -e "${GREEN}PostgreSQL${NC}" | tee -a "$LOG_FILE"
    echo -e "  Version: $postgres_version" | tee -a "$LOG_FILE"
    echo -e "  Port: ${POSTGRES_PORT}" | tee -a "$LOG_FILE"
    echo -e "  Database: $POSTGRES_DB" | tee -a "$LOG_FILE"
    echo -e "  User: $POSTGRES_ROOT_USER" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Redis info
    redis_version=$(docker exec redis_db redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO SERVER 2>/dev/null | grep "redis_version" | cut -d: -f2 | tr -d '\r')
    echo -e "${GREEN}Redis${NC}" | tee -a "$LOG_FILE"
    echo -e "  Version: $redis_version" | tee -a "$LOG_FILE"
    echo -e "  Port: ${REDIS_PORT}" | tee -a "$LOG_FILE"
    echo -e "  Auth: Enabled" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
    echo -e "\n${GREEN}✓ Deployment completed successfully!${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}ℹ Log file: $LOG_FILE${NC}\n" | tee -a "$LOG_FILE"
}

##############################################################################
# Error Handling
##############################################################################

cleanup_on_error() {
    print_error "Deployment failed! Check log file: $LOG_FILE"
    print_info "Container status:"
    docker compose ps 2>&1 | tee -a "$LOG_FILE"
    exit 1
}

trap cleanup_on_error ERR

##############################################################################
# Main Execution
##############################################################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN_DEPLOY=true
                shift
                ;;
            --update)
                UPDATE_DEPLOY=true
                shift
                ;;
            --help)
                show_usage
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                ;;
        esac
    done

    # If no mode specified, ask user
    if [ "$CLEAN_DEPLOY" = false ] && [ "$UPDATE_DEPLOY" = false ]; then
        print_warning "No deployment mode specified"
        echo -e "${YELLOW}Select deployment mode:${NC}"
        echo "  1) Clean deployment (removes all existing data)"
        echo "  2) Update deployment (keeps existing data)"
        read -p "Enter choice [1-2]: " choice
        case $choice in
            1)
                CLEAN_DEPLOY=true
                ;;
            2)
                UPDATE_DEPLOY=true
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
    fi

    print_header "Database Services Deployment - Production Mode"

    log "Starting deployment process..."
    log "Working directory: $SCRIPT_DIR"
    log "Deployment mode: $([ "$CLEAN_DEPLOY" = true ] && echo "CLEAN" || echo "UPDATE")"

    # Execute deployment steps
    check_prerequisites
    step_cleanup
    step_deploy
    step_wait_healthy
    step_verify
    step_summary

    exit 0
}

# Run main function
main "$@"
