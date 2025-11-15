#!/bin/bash

##############################################################################
# Database Services Backup Script
# Creates backups of MySQL, PostgreSQL, and Redis data
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

# Backup configuration
BACKUP_BASE_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$TIMESTAMP"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

##############################################################################
# Backup Functions
##############################################################################

check_services() {
    print_header "Checking Services Status"

    local services=("mysql_db" "postgres_db" "redis_db")
    local all_running=true

    for service in "${services[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
            print_success "$service is running"
        else
            print_error "$service is not running"
            all_running=false
        fi
    done

    if [ "$all_running" = false ]; then
        print_error "Not all services are running. Cannot perform backup."
        exit 1
    fi

    print_success "All services are running"
}

backup_mysql() {
    print_header "Backing Up MySQL"

    local mysql_backup_dir="$BACKUP_DIR/mysql"
    mkdir -p "$mysql_backup_dir"

    print_info "Creating MySQL dump..."
    docker exec mysql_db mysqldump \
        -u root \
        -p"$MYSQL_ROOT_PASSWORD" \
        --all-databases \
        --single-transaction \
        --quick \
        --lock-tables=false \
        > "$mysql_backup_dir/all_databases.sql"

    print_success "MySQL dump created: all_databases.sql"

    # Compress the dump
    print_info "Compressing MySQL backup..."
    gzip "$mysql_backup_dir/all_databases.sql"
    print_success "MySQL backup compressed"

    local size=$(du -h "$mysql_backup_dir/all_databases.sql.gz" | cut -f1)
    print_success "MySQL backup completed ($size)"
}

backup_postgres() {
    print_header "Backing Up PostgreSQL"

    local pg_backup_dir="$BACKUP_DIR/postgres"
    mkdir -p "$pg_backup_dir"

    print_info "Creating PostgreSQL dump..."
    docker exec postgres_db pg_dumpall \
        -U "$POSTGRES_ROOT_USER" \
        > "$pg_backup_dir/all_databases.sql"

    print_success "PostgreSQL dump created: all_databases.sql"

    # Compress the dump
    print_info "Compressing PostgreSQL backup..."
    gzip "$pg_backup_dir/all_databases.sql"
    print_success "PostgreSQL backup compressed"

    local size=$(du -h "$pg_backup_dir/all_databases.sql.gz" | cut -f1)
    print_success "PostgreSQL backup completed ($size)"
}

backup_redis() {
    print_header "Backing Up Redis"

    local redis_backup_dir="$BACKUP_DIR/redis"
    mkdir -p "$redis_backup_dir"

    # Trigger Redis to save current state
    print_info "Triggering Redis SAVE..."
    docker exec redis_db redis-cli -a "$REDIS_PASSWORD" --no-auth-warning SAVE > /dev/null

    print_info "Copying Redis data files..."
    # Copy RDB file
    if docker exec redis_db test -f /data/dump.rdb; then
        docker cp redis_db:/data/dump.rdb "$redis_backup_dir/"
        print_success "RDB file copied"
    fi

    # Copy AOF file if it exists
    if docker exec redis_db test -f /data/appendonly.aof; then
        docker cp redis_db:/data/appendonly.aof "$redis_backup_dir/"
        print_success "AOF file copied"
    fi

    # Compress Redis backup
    print_info "Compressing Redis backup..."
    tar -czf "$redis_backup_dir/redis_data.tar.gz" -C "$redis_backup_dir" . \
        --exclude='redis_data.tar.gz' 2>/dev/null || true
    rm -f "$redis_backup_dir/dump.rdb" "$redis_backup_dir/appendonly.aof" 2>/dev/null || true

    local size=$(du -h "$redis_backup_dir/redis_data.tar.gz" | cut -f1)
    print_success "Redis backup completed ($size)"
}

create_backup_metadata() {
    print_header "Creating Backup Metadata"

    cat > "$BACKUP_DIR/backup_info.txt" << EOF
Backup Information
==================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)
User: $(whoami)

Services:
---------
MySQL Version: $(docker exec mysql_db mysql -V 2>/dev/null || echo "N/A")
PostgreSQL Version: $(docker exec postgres_db psql --version 2>/dev/null || echo "N/A")
Redis Version: $(docker exec redis_db redis-server --version 2>/dev/null || echo "N/A")

Backup Contents:
----------------
$(du -sh "$BACKUP_DIR"/* 2>/dev/null || echo "No files")

Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

    print_success "Metadata created"
}

cleanup_old_backups() {
    print_header "Cleaning Up Old Backups"

    print_info "Retention policy: $RETENTION_DAYS days"

    local deleted_count=0
    while IFS= read -r -d '' backup; do
        print_info "Removing old backup: $(basename "$backup")"
        rm -rf "$backup"
        ((deleted_count++))
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -print0 2>/dev/null)

    if [ $deleted_count -gt 0 ]; then
        print_success "Removed $deleted_count old backup(s)"
    else
        print_info "No old backups to remove"
    fi
}

display_summary() {
    print_header "Backup Summary"

    echo -e "${GREEN}Backup completed successfully!${NC}\n"
    echo -e "${BLUE}Backup Details:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Backup Location: $BACKUP_DIR"
    echo -e "Timestamp: $TIMESTAMP"
    echo ""

    if [ -f "$BACKUP_DIR/mysql/all_databases.sql.gz" ]; then
        local mysql_size=$(du -h "$BACKUP_DIR/mysql/all_databases.sql.gz" | cut -f1)
        echo -e "${GREEN}MySQL:${NC} $mysql_size"
    fi

    if [ -f "$BACKUP_DIR/postgres/all_databases.sql.gz" ]; then
        local pg_size=$(du -h "$BACKUP_DIR/postgres/all_databases.sql.gz" | cut -f1)
        echo -e "${GREEN}PostgreSQL:${NC} $pg_size"
    fi

    if [ -f "$BACKUP_DIR/redis/redis_data.tar.gz" ]; then
        local redis_size=$(du -h "$BACKUP_DIR/redis/redis_data.tar.gz" | cut -f1)
        echo -e "${GREEN}Redis:${NC} $redis_size"
    fi

    echo ""
    local total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    echo -e "${BLUE}Total Size:${NC} $total_size"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # List recent backups
    echo -e "\n${BLUE}Recent Backups:${NC}"
    ls -lht "$BACKUP_BASE_DIR" | head -n 6

    echo -e "\n${GREEN}✓ Backup process completed successfully!${NC}\n"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    print_header "Database Services Backup"

    print_info "Starting backup process..."
    print_info "Backup directory: $BACKUP_DIR"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Execute backup steps
    check_services
    backup_mysql
    backup_postgres
    backup_redis
    create_backup_metadata
    cleanup_old_backups
    display_summary

    exit 0
}

# Error handling
trap 'print_error "Backup failed! Check errors above."' ERR

# Run main function
main
