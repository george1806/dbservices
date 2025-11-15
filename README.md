# Database Services - Production Deployment

Complete production-ready deployment of MySQL, PostgreSQL, and Redis using Docker Compose with automated backup, health monitoring, and management scripts.

## Table of Contents

-   [Overview](#overview)
-   [Features](#features)
-   [Prerequisites](#prerequisites)
-   [Quick Start](#quick-start)
-   [Available Commands](#available-commands)
-   [Configuration](#configuration)
-   [Scripts](#scripts)
-   [Maintenance](#maintenance)
-   [Monitoring](#monitoring)
-   [Backup & Restore](#backup--restore)
-   [Troubleshooting](#troubleshooting)
-   [Security](#security)

## Overview

This deployment provides three database services:

-   **MySQL 8.0** - Relational database with InnoDB storage
-   **PostgreSQL 15** - Advanced relational database
-   **Redis 7** - In-memory data structure store

All services are containerized, production-optimized, and include comprehensive management tooling.

## Features

### Production Optimizations

-   ✓ Resource limits (CPU & Memory)
-   ✓ Logging configuration (size limits & rotation)
-   ✓ Security hardening (no-new-privileges)
-   ✓ Health checks with auto-restart
-   ✓ Performance tuning for each database
-   ✓ Network isolation
-   ✓ Persistent data storage

### Management Tools

-   ✓ Automated deployment script
-   ✓ Backup script with retention policy
-   ✓ Health monitoring script
-   ✓ Comprehensive logging

## Prerequisites

-   Docker Engine 20.10+
-   Docker Compose V2
-   5GB+ free disk space
-   sudo/root access for data directory management

## Quick Start

### 1. Initial Setup

```bash
# Clone or copy this directory
cd /home/deployusr/apps/dockerDevs/dbservices

# Copy environment template
cp .env.example .env

# Edit configuration (IMPORTANT: Change all passwords!)
nano .env
```

### 2. Deploy Services

```bash
# Clean deployment (fresh start)
./deploy.sh --clean

# Update deployment (keeps existing data)
./deploy.sh --update

# Interactive mode
./deploy.sh
```

### 3. Verify Deployment

```bash
# Check service status
docker compose ps

# Run health check
./health-check.sh

# View logs
docker compose logs -f
```

## Available Commands

### Deployment Summary

After a successful deployment, you should see:

```
✓ Pre-flight checks: PASSED
✓ Clean deployment: SUCCESS
✓ Service health: ALL HEALTHY
✓ Connectivity: ALL VERIFIED
✓ Resource usage: OPTIMAL
```

### Services Status

| Service        | Status    | Version | Memory      | CPU    | Database    |
| -------------- | --------- | ------- | ----------- | ------ | ----------- |
| **MySQL**      | ✓ Healthy | 8.0.44  | 370MB / 1GB | ~1%    | carpointsdb |
| **PostgreSQL** | ✓ Healthy | 15.15   | 32MB / 1GB  | ~0.05% | postgres_db |
| **Redis**      | ✓ Healthy | 7.4.7   | 3MB / 512MB | ~0.4%  | In-memory   |

### Command Reference

#### Deployment Commands

```bash
# Fresh deployment (removes all data, creates backup first)
./deploy.sh --clean

# Update deployment (keeps existing data, restarts services)
./deploy.sh --update

# Interactive mode (prompts for deployment type)
./deploy.sh

# View deployment help
./deploy.sh --help
```

**What deploy.sh does:**

-   ✓ Runs pre-flight system checks
-   ✓ Validates Docker, disk space, and configuration
-   ✓ Creates automatic backup (on clean deploy)
-   ✓ Pulls latest images
-   ✓ Starts all services
-   ✓ Waits for health checks
-   ✓ Verifies database connectivity
-   ✓ Generates deployment log

#### Backup Commands

```bash
# Create manual backup of all databases
./backup.sh

# View backups
ls -lh backups/

# View specific backup contents
ls -lh backups/20251115-230507/
```

**What backup.sh does:**

-   ✓ Creates compressed MySQL dump (all databases)
-   ✓ Creates compressed PostgreSQL dump (all databases)
-   ✓ Creates compressed Redis data snapshot
-   ✓ Generates backup metadata
-   ✓ Cleans old backups (retention: 7 days default)

**Schedule automatic backups (cron):**

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /home/deployusr/apps/dockerDevs/dbservices/backup.sh >> /var/log/db-backup.log 2>&1
```

#### Health Check Commands

```bash
# Run comprehensive health check
./health-check.sh

# Run with verbose output
./health-check.sh --verbose

# View health check help
./health-check.sh --help
```

**What health-check.sh verifies:**

-   ✓ Container status (running/stopped)
-   ✓ Health check status
-   ✓ Database connectivity
-   ✓ Database sizes
-   ✓ Active connections
-   ✓ Memory and CPU usage
-   ✓ Disk space availability

**Schedule automatic health checks (cron):**

```bash
# Edit crontab
crontab -e

# Add health check every 5 minutes
*/5 * * * * /home/deployusr/apps/dockerDevs/dbservices/health-check.sh >> /var/log/db-health.log 2>&1
```

#### Service Management

```bash
# Start all services
docker compose up -d

# Stop all services (keeps data)
docker compose down

# Stop all services and remove volumes (DELETES DATA!)
docker compose down -v

# Restart all services
docker compose restart

# Restart specific service
docker compose restart mysql
docker compose restart postgres
docker compose restart redis

# View service status
docker compose ps

# View resource usage
docker stats mysql_db postgres_db redis_db
```

#### Log Commands

```bash
# View all service logs (follow mode)
docker compose logs -f

# View specific service logs
docker compose logs -f mysql
docker compose logs -f postgres
docker compose logs -f redis

# View last 100 lines
docker compose logs --tail 100 mysql

# View logs since timestamp
docker compose logs --since 2h mysql

# View deployment logs
cat deployment-*.log
tail -f deployment-*.log

# View health check logs
cat health-check.log
tail -f health-check.log
```

#### Database Access

**MySQL:**

```bash
# Connect via Docker
docker exec -it mysql_db mysql -uroot -p

# Connect via host (requires MySQL client)
mysql -h localhost -P 3306 -u root -p

# Run single query
docker exec mysql_db mysql -uroot -pr00t@12 -e "SHOW DATABASES;"

# Import SQL file
docker exec -i mysql_db mysql -uroot -p < backup.sql

# Export database
docker exec mysql_db mysqldump -uroot -p carpointsdb > backup.sql
```

**PostgreSQL:**

```bash
# Connect via Docker
docker exec -it postgres_db psql -U root -d postgres_db

# Connect via host (requires psql client)
psql -h localhost -p 5432 -U root -d postgres_db

# Run single query
docker exec postgres_db psql -U root -d postgres_db -c "SELECT version();"

# Import SQL file
docker exec -i postgres_db psql -U root -d postgres_db < backup.sql

# Export database
docker exec postgres_db pg_dump -U root postgres_db > backup.sql
```

**Redis:**

```bash
# Connect via Docker
docker exec -it redis_db redis-cli -a rdsp@ssw0rd

# Connect via host (requires redis-cli)
redis-cli -h localhost -p 6379 -a rdsp@ssw0rd

# Run single command
docker exec redis_db redis-cli -a rdsp@ssw0rd --no-auth-warning PING
docker exec redis_db redis-cli -a rdsp@ssw0rd --no-auth-warning INFO
docker exec redis_db redis-cli -a rdsp@ssw0rd --no-auth-warning DBSIZE

# Monitor Redis commands in real-time
docker exec -it redis_db redis-cli -a rdsp@ssw0rd MONITOR
```

#### Monitoring Commands

```bash
# Check container health status
docker inspect mysql_db --format='{{.State.Health.Status}}'
docker inspect postgres_db --format='{{.State.Health.Status}}'
docker inspect redis_db --format='{{.State.Health.Status}}'

# Check disk usage
du -sh /Data/*
df -h /Data

# Check network
docker network inspect dbservices_db_network

# View container details
docker inspect mysql_db
docker inspect postgres_db
docker inspect redis_db

# Check running processes in container
docker exec mysql_db ps aux
docker exec postgres_db ps aux
docker exec redis_db ps aux
```

#### Troubleshooting Commands

```bash
# View recent errors in logs
docker compose logs --tail 50 mysql | grep -i error
docker compose logs --tail 50 postgres | grep -i error
docker compose logs --tail 50 redis | grep -i error

# Check container status and restart count
docker inspect mysql_db --format='Status: {{.State.Status}}, Restarts: {{.RestartCount}}'

# View container resource limits
docker inspect mysql_db --format='CPU: {{.HostConfig.NanoCpus}}, Memory: {{.HostConfig.Memory}}'

# Test connectivity from host
nc -zv localhost 3306  # MySQL
nc -zv localhost 5432  # PostgreSQL
nc -zv localhost 6379  # Redis

# View active connections (MySQL)
docker exec mysql_db mysql -uroot -pr00t@12 -e "SHOW PROCESSLIST;"

# View active connections (PostgreSQL)
docker exec postgres_db psql -U root -d postgres_db -c "SELECT * FROM pg_stat_activity;"

# Check Redis info
docker exec redis_db redis-cli -a rdsp@ssw0rd --no-auth-warning INFO stats
docker exec redis_db redis-cli -a rdsp@ssw0rd --no-auth-warning INFO memory
```

#### Emergency Commands

```bash
# Force stop all services
docker compose kill

# Remove all containers (keeps data)
docker compose rm -f

# Clean restart (keeps data)
docker compose down && docker compose up -d

# Complete reset (DELETES ALL DATA!)
docker compose down -v
sudo rm -rf /Data/mysql /Data/postgres /Data/redis
./deploy.sh --clean

# View Docker system info
docker info
docker system df

# Clean Docker system (removes unused data)
docker system prune -a
```

### Log Files Reference

All operations create timestamped log files for auditing and troubleshooting:

```bash
# Deployment logs
deployment-YYYYMMDD-HHMMSS.log    # Each deployment creates a new log

# Health check logs
health-check.log                   # Appends to single log file

# Docker logs (managed by Docker)
# - Max size: 10MB per service
# - Max files: 3 rotated files
# - Access via: docker compose logs
```

### Quick Reference Card

```bash
# DAILY OPERATIONS
./deploy.sh --update              # Update/restart services
./health-check.sh                 # Check system health
docker compose ps                 # View status
docker compose logs -f            # Monitor logs

# BACKUP & RESTORE
./backup.sh                       # Create backup
ls -lh backups/                   # List backups

# EMERGENCY
docker compose restart <service>  # Restart single service
docker compose down && docker compose up -d  # Full restart
./deploy.sh --clean               # Nuclear option (clean slate)
```

## Configuration

### Environment Variables (.env)

#### MySQL Configuration

```bash
MYSQL_ROOT_PASSWORD=<strong-password>    # Root password
MYSQL_USER=app_user                      # Application user
MYSQL_PASSWORD=<strong-password>         # App user password
MYSQL_DATABASE=myapp_db                  # Database name
MYSQL_PORT=3306                          # External port
```

#### PostgreSQL Configuration

```bash
POSTGRES_ROOT_USER=postgres              # Superuser name
POSTGRES_ROOT_PASSWORD=<strong-password> # Root password
POSTGRES_USER=app_user                   # Application user
POSTGRES_PASSWORD=<strong-password>      # App user password
POSTGRES_DB=myapp_db                     # Database name
POSTGRES_PORT=5432                       # External port
```

#### Redis Configuration

```bash
REDIS_PASSWORD=<strong-password>         # Auth password
REDIS_PORT=6379                          # External port
```

#### System Configuration

```bash
DATA_DIR=/Data                           # Data storage path
BACKUP_DIR=./backups                     # Backup storage path
BACKUP_RETENTION_DAYS=7                  # Backup retention
```

### Resource Limits

Configured in `docker-compose.yml`:

| Service    | CPU Limit | Memory Limit | CPU Reserved | Memory Reserved |
| ---------- | --------- | ------------ | ------------ | --------------- |
| MySQL      | 1.0       | 1GB          | 0.5          | 512MB           |
| PostgreSQL | 1.0       | 1GB          | 0.5          | 512MB           |
| Redis      | 0.5       | 512MB        | 0.25         | 256MB           |

## Scripts

### deploy.sh - Deployment Script

Production-grade deployment with pre-flight checks and validation.

```bash
# Usage
./deploy.sh [OPTIONS]

# Options
--clean    # Clean deployment (removes all data)
--update   # Update deployment (keeps existing data)
--help     # Show help message

# Examples
./deploy.sh --clean             # Fresh installation
./deploy.sh --update            # Update/restart services
```

**Features:**

-   Pre-flight system checks
-   Automatic backup before clean deployment
-   Health check validation
-   Comprehensive logging
-   Error handling with rollback capability

### backup.sh - Backup Script

Automated backup of all database services.

```bash
# Usage
./backup.sh

# What it does:
# - Creates compressed backups of all databases
# - Saves to timestamped directory
# - Cleans up old backups per retention policy
# - Generates backup metadata
```

**Backup Locations:**

-   MySQL: `backups/<timestamp>/mysql/all_databases.sql.gz`
-   PostgreSQL: `backups/<timestamp>/postgres/all_databases.sql.gz`
-   Redis: `backups/<timestamp>/redis/redis_data.tar.gz`

**Schedule Backups (Cron):**

```bash
# Daily backup at 2 AM
0 2 * * * /home/deployusr/apps/dockerDevs/dbservices/backup.sh >> /var/log/db-backup.log 2>&1
```

### health-check.sh - Health Monitoring

Comprehensive health checks for all services.

```bash
# Usage
./health-check.sh [OPTIONS]

# Options
-v, --verbose    # Enable verbose output
-h, --help       # Show help message

# Examples
./health-check.sh              # Run health checks
./health-check.sh --verbose    # Verbose output
```

**Checks Performed:**

-   Container status (running/stopped)
-   Health check status
-   Database connectivity
-   Database sizes
-   Active connections
-   Disk space usage
-   Resource usage (CPU/Memory)

**Schedule Health Checks (Cron):**

```bash
# Every 5 minutes
*/5 * * * * /home/deployusr/apps/dockerDevs/dbservices/health-check.sh >> /var/log/db-health.log 2>&1
```

## Maintenance

### Starting Services

```bash
docker compose up -d
```

### Stopping Services

```bash
docker compose down
```

### Restarting a Service

```bash
docker compose restart mysql    # MySQL
docker compose restart postgres # PostgreSQL
docker compose restart redis    # Redis
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f mysql
docker compose logs -f postgres
docker compose logs -f redis

# Last 100 lines
docker compose logs --tail 100 mysql
```

### Accessing Databases

#### MySQL

```bash
# Via Docker
docker exec -it mysql_db mysql -uroot -p

# Via host
mysql -h localhost -P 3306 -u root -p
```

#### PostgreSQL

```bash
# Via Docker
docker exec -it postgres_db psql -U root -d postgres_db

# Via host
psql -h localhost -p 5432 -U root -d postgres_db
```

#### Redis

```bash
# Via Docker
docker exec -it redis_db redis-cli -a <password>

# Via host
redis-cli -h localhost -p 6379 -a <password>
```

## Monitoring

### Container Status

```bash
docker compose ps
```

### Resource Usage

```bash
docker stats mysql_db postgres_db redis_db
```

### Disk Usage

```bash
# Data directory
du -sh /Data/*

# Logs
docker compose logs --tail 0 --timestamps
```

## Backup & Restore

### Manual Backup

```bash
./backup.sh
```

### Restore from Backup

#### MySQL

```bash
# Extract backup
gunzip backups/<timestamp>/mysql/all_databases.sql.gz

# Restore
docker exec -i mysql_db mysql -uroot -p<password> < backups/<timestamp>/mysql/all_databases.sql
```

#### PostgreSQL

```bash
# Extract backup
gunzip backups/<timestamp>/postgres/all_databases.sql.gz

# Restore
docker exec -i postgres_db psql -U root -d postgres_db < backups/<timestamp>/postgres/all_databases.sql
```

#### Redis

```bash
# Extract backup
tar -xzf backups/<timestamp>/redis/redis_data.tar.gz -C /tmp/redis_restore/

# Stop Redis
docker compose stop redis

# Replace data files
sudo cp /tmp/redis_restore/dump.rdb /Data/redis/
sudo cp /tmp/redis_restore/appendonly.aof /Data/redis/

# Start Redis
docker compose start redis
```

## Troubleshooting

### Container Won't Start

1. Check logs:

```bash
docker compose logs <service>
```

2. Check disk space:

```bash
df -h /Data
```

3. Check Docker daemon:

```bash
docker info
```

### Database Connection Refused

1. Verify container is running:

```bash
docker compose ps
```

2. Check health status:

```bash
docker inspect <container_name> --format='{{.State.Health.Status}}'
```

3. Check network:

```bash
docker network inspect dbservices_db_network
```

### Performance Issues

1. Check resource usage:

```bash
docker stats
```

2. Review database-specific slow logs:
    - MySQL: `/Data/mysql/mysql-slow.log`
    - PostgreSQL: `/Data/postgres/log/`
    - Redis: Use `SLOWLOG GET` command

### Clean Reinstall

```bash
# Stop and remove everything
docker compose down -v

# Remove data (CAUTION: This deletes all data!)
sudo rm -rf /Data/mysql /Data/postgres /Data/redis

# Fresh deployment
./deploy.sh --clean
```

## Security

### Best Practices

1. **Change Default Passwords**

    - Update all passwords in `.env` before deployment
    - Use strong, unique passwords (20+ characters)

2. **Network Security**

    - Services are isolated in a dedicated Docker network
    - Only exposed ports are accessible from host

3. **File Permissions**

    - `.env` file should be readable only by owner

    ```bash
    chmod 600 .env
    ```

4. **Regular Updates**

    - Keep Docker images updated

    ```bash
    docker compose pull
    docker compose up -d
    ```

5. **Backup Encryption**

    - Consider encrypting backups for sensitive data

6. **Access Control**
    - Use firewall rules to restrict port access
    - Consider using reverse proxy for additional security

### Port Exposure

By default, services are exposed on:

-   MySQL: `0.0.0.0:3306`
-   PostgreSQL: `0.0.0.0:5432`
-   Redis: `0.0.0.0:6379`

To restrict to localhost only, modify `docker-compose.yml`:

```yaml
ports:
    - '127.0.0.1:3306:3306' # Only localhost access
```

## Support & Maintenance

### Log Files

-   Deployment: `deployment-<timestamp>.log`
-   Health Checks: `health-check.log`
-   Docker logs: Accessible via `docker compose logs`

### Monitoring Integration

Health check script returns proper exit codes for monitoring:

-   `0` = All services healthy
-   `1` = One or more services unhealthy

Integrate with monitoring systems (Nagios, Prometheus, etc.):

```bash
/path/to/health-check.sh && echo "OK" || echo "CRITICAL"
```

---

**Version:** 2.0 (Production)
**Last Updated:** 2025-11-15
