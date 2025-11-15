#!/bin/bash

##############################################################################
# Database Services Health Check Script
# Monitors MySQL, PostgreSQL, and Redis health status
# Version: 1.0 (Production)
##############################################################################

set -euo pipefail
IFS=$'\n\t'

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo -e "${RED}Error: .env file not found!${NC}"
    exit 1
fi

# Health check configuration
ALERT_EMAIL="${ALERT_EMAIL:-}"
LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/health-check.log}"
VERBOSE="${VERBOSE:-false}"

##############################################################################
# Helper Functions
##############################################################################

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    if [ "$VERBOSE" = true ]; then
        echo "$*"
    fi
}

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log_message "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log_message "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log_message "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log_message "INFO: $1"
}

##############################################################################
# Health Check Functions
##############################################################################

check_container_status() {
    local container=$1
    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")

    if [ "$status" = "running" ]; then
        return 0
    else
        return 1
    fi
}

check_container_health() {
    local container=$1
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")

    if [ "$health" = "healthy" ]; then
        return 0
    else
        return 1
    fi
}

check_mysql() {
    print_header "MySQL Health Check"

    # Check if container is running
    if ! check_container_status "mysql_db"; then
        print_error "MySQL container is not running"
        return 1
    fi
    print_success "MySQL container is running"

    # Check health status
    if ! check_container_health "mysql_db"; then
        print_error "MySQL health check failed"
        return 1
    fi
    print_success "MySQL health check passed"

    # Test database connectivity
    if docker exec mysql_db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        print_success "MySQL database connectivity OK"
    else
        print_error "MySQL database connectivity failed"
        return 1
    fi

    # Check database size
    local db_size=$(docker exec mysql_db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
        SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
        FROM information_schema.tables
        WHERE table_schema = '$MYSQL_DATABASE';" 2>/dev/null | tail -n1)

    print_info "MySQL database size: ${db_size} MB"

    # Check connections
    local connections=$(docker exec mysql_db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW STATUS WHERE variable_name = 'Threads_connected';" 2>/dev/null | tail -n1 | awk '{print $2}')
    print_info "MySQL active connections: ${connections}"

    print_success "MySQL: All checks passed"
    return 0
}

check_postgres() {
    print_header "PostgreSQL Health Check"

    # Check if container is running
    if ! check_container_status "postgres_db"; then
        print_error "PostgreSQL container is not running"
        return 1
    fi
    print_success "PostgreSQL container is running"

    # Check health status
    if ! check_container_health "postgres_db"; then
        print_error "PostgreSQL health check failed"
        return 1
    fi
    print_success "PostgreSQL health check passed"

    # Test database connectivity
    if docker exec postgres_db psql -U "$POSTGRES_ROOT_USER" -d "$POSTGRES_DB" -c "SELECT 1;" &>/dev/null; then
        print_success "PostgreSQL database connectivity OK"
    else
        print_error "PostgreSQL database connectivity failed"
        return 1
    fi

    # Check database size
    local db_size=$(docker exec postgres_db psql -U "$POSTGRES_ROOT_USER" -d "$POSTGRES_DB" -t -c "
        SELECT pg_size_pretty(pg_database_size('$POSTGRES_DB'));" 2>/dev/null | xargs)

    print_info "PostgreSQL database size: ${db_size}"

    # Check connections
    local connections=$(docker exec postgres_db psql -U "$POSTGRES_ROOT_USER" -d "$POSTGRES_DB" -t -c "
        SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs)
    print_info "PostgreSQL active connections: ${connections}"

    print_success "PostgreSQL: All checks passed"
    return 0
}

check_redis() {
    print_header "Redis Health Check"

    # Check if container is running
    if ! check_container_status "redis_db"; then
        print_error "Redis container is not running"
        return 1
    fi
    print_success "Redis container is running"

    # Check health status
    if ! check_container_health "redis_db"; then
        print_error "Redis health check failed"
        return 1
    fi
    print_success "Redis health check passed"

    # Test Redis connectivity
    if docker exec redis_db redis-cli -a "$REDIS_PASSWORD" --no-auth-warning PING 2>/dev/null | grep -q "PONG"; then
        print_success "Redis connectivity OK"
    else
        print_error "Redis connectivity failed"
        return 1
    fi

    # Get Redis info
    local redis_info=$(docker exec redis_db redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO 2>/dev/null)

    # Check memory usage
    local used_memory=$(echo "$redis_info" | grep "^used_memory_human:" | cut -d: -f2 | tr -d '\r')
    print_info "Redis memory usage: ${used_memory}"

    # Check connected clients
    local connected_clients=$(echo "$redis_info" | grep "^connected_clients:" | cut -d: -f2 | tr -d '\r')
    print_info "Redis connected clients: ${connected_clients}"

    # Check keys count
    local keys_count=$(docker exec redis_db redis-cli -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE 2>/dev/null | tr -d '\r')
    print_info "Redis keys count: ${keys_count}"

    # Check last save time
    local last_save=$(docker exec redis_db redis-cli -a "$REDIS_PASSWORD" --no-auth-warning LASTSAVE 2>/dev/null | tr -d '\r')
    local last_save_time=$(date -d @$last_save 2>/dev/null || echo "Unknown")
    print_info "Redis last save: ${last_save_time}"

    print_success "Redis: All checks passed"
    return 0
}

check_disk_space() {
    print_header "Disk Space Check"

    local data_dir_usage=$(df -h "$DATA_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ -z "$data_dir_usage" ]; then
        print_warning "Could not check disk space for $DATA_DIR"
        return 0
    fi

    print_info "Data directory usage: ${data_dir_usage}%"

    if [ "$data_dir_usage" -gt 90 ]; then
        print_error "Disk space critical: ${data_dir_usage}% used"
        return 1
    elif [ "$data_dir_usage" -gt 80 ]; then
        print_warning "Disk space warning: ${data_dir_usage}% used"
    else
        print_success "Disk space OK: ${data_dir_usage}% used"
    fi

    return 0
}

check_docker_resources() {
    print_header "Docker Resources Check"

    # Get MySQL stats
    local mysql_stats=$(docker stats mysql_db --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" 2>/dev/null || echo "N/A,N/A")
    local mysql_cpu=$(echo $mysql_stats | cut -d, -f1)
    local mysql_mem=$(echo $mysql_stats | cut -d, -f2)
    print_info "MySQL - CPU: $mysql_cpu, Memory: $mysql_mem"

    # Get PostgreSQL stats
    local pg_stats=$(docker stats postgres_db --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" 2>/dev/null || echo "N/A,N/A")
    local pg_cpu=$(echo $pg_stats | cut -d, -f1)
    local pg_mem=$(echo $pg_stats | cut -d, -f2)
    print_info "PostgreSQL - CPU: $pg_cpu, Memory: $pg_mem"

    # Get Redis stats
    local redis_stats=$(docker stats redis_db --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" 2>/dev/null || echo "N/A,N/A")
    local redis_cpu=$(echo $redis_stats | cut -d, -f1)
    local redis_mem=$(echo $redis_stats | cut -d, -f2)
    print_info "Redis - CPU: $redis_cpu, Memory: $redis_mem"

    print_success "Resource check completed"
}

generate_summary() {
    print_header "Health Check Summary"

    local all_healthy=true

    # Check all services
    local services=("mysql_db" "postgres_db" "redis_db")
    for service in "${services[@]}"; do
        if check_container_status "$service" && check_container_health "$service"; then
            echo -e "${GREEN}✓${NC} $service: Healthy"
        else
            echo -e "${RED}✗${NC} $service: Unhealthy"
            all_healthy=false
        fi
    done

    echo ""

    if [ "$all_healthy" = true ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ All services are healthy${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 0
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}✗ Some services are unhealthy${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 1
    fi
}

##############################################################################
# Main Execution
##############################################################################

main() {
    local exit_code=0

    print_header "Database Services Health Check"
    log_message "=== Health Check Started ==="

    # Run all health checks
    check_mysql || exit_code=1
    check_postgres || exit_code=1
    check_redis || exit_code=1
    check_disk_space || exit_code=1
    check_docker_resources

    # Generate summary
    generate_summary || exit_code=1

    log_message "=== Health Check Completed (Exit Code: $exit_code) ==="

    echo -e "\n${BLUE}ℹ Log file: $LOG_FILE${NC}\n"

    exit $exit_code
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

DESCRIPTION:
    Performs comprehensive health checks on all database services.
    Checks container status, health, connectivity, and resource usage.

EXIT CODES:
    0    All checks passed
    1    One or more checks failed

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main
