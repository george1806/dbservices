# Docker Services Setup

This Docker Compose configuration sets up three database services: MySQL 8, PostgreSQL 15, and Redis 7.

## Prerequisites

-   Docker installed and running
-   Docker Compose installed
-   The directory `/home/george/devs/dockerDevs/Data` should exist or will be created automatically

## Services

### 1. MySQL 8

-   **Container Name**: mysql_db
-   **Port**: 3306
-   **Data Directory**: `/home/george/devs/dockerDevs/Data/mysql`
-   **Root Password**: Configured via `.env` file
-   **Default User**: Configured via `.env` file

### 2. PostgreSQL 15

-   **Container Name**: postgres_db
-   **Port**: 5432
-   **Data Directory**: `/home/george/devs/dockerDevs/Data/postgres`
-   **Default User**: Configured via `.env` file
-   **Default Database**: Configured via `.env` file

### 3. Redis 7

-   **Container Name**: redis_db
-   **Port**: 6379
-   **Data Directory**: `/home/george/devs/dockerDevs/Data/redis`
-   **Password**: Configured via `.env` file

## Configuration

### Environment Variables

All sensitive credentials are managed through the `.env` file. You can customize the following variables:

-   `MYSQL_ROOT_PASSWORD` - MySQL root password
-   `MYSQL_USER` - MySQL custom user
-   `MYSQL_PASSWORD` - MySQL custom user password
-   `MYSQL_DATABASE` - MySQL default database name
-   `POSTGRES_ROOT_USER` - PostgreSQL root user (usually 'postgres')
-   `POSTGRES_ROOT_PASSWORD` - PostgreSQL root password
-   `POSTGRES_USER` - PostgreSQL custom user
-   `POSTGRES_PASSWORD` - PostgreSQL custom user password
-   `POSTGRES_DB` - PostgreSQL default database name
-   `REDIS_PASSWORD` - Redis password
-   `DATA_DIR` - Base data directory for all volumes

## Quick Start

1. **Navigate to the project directory**:

    ```bash
    cd /home/george/devs/dockerDevs/dbservices
    ```

2. **(Optional) Customize credentials** in the `.env` file:

    ```bash
    nano .env
    ```

3. **Create the data directory** (if it doesn't exist):

    ```bash
    mkdir -p /home/george/devs/dockerDevs/Data/{mysql,postgres,redis}
    ```

4. **Start all services**:

    ```bash
    docker-compose up -d
    ```

5. **Verify services are running**:
    ```bash
    docker-compose ps
    ```

## Connecting to Services

### MySQL

```bash
mysql -h localhost -u mysql_user -p
# or use root
mysql -h localhost -u root -p
```

### PostgreSQL

```bash
psql -h localhost -U postgres_user -d postgres_db
# or use root
psql -h localhost -U postgres -d postgres_db
```

### Redis

```bash
redis-cli -h localhost -p 6379 -a <REDIS_PASSWORD>
# or use docker exec
docker exec -it redis_db redis-cli -a <REDIS_PASSWORD>
```

## Useful Commands

### View logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f mysql
docker-compose logs -f postgres
docker-compose logs -f redis
```

### Stop all services

```bash
docker-compose down
```

### Stop services and remove volumes

```bash
docker-compose down -v
```

### Restart services

```bash
docker-compose restart
```

### Access service shell

```bash
docker exec -it mysql_db bash
docker exec -it postgres_db bash
docker exec -it redis_db sh
```

## Health Checks

All services have health checks configured:

-   **MySQL**: Health check every 20 seconds with 10 retries
-   **PostgreSQL**: Health check every 10 seconds with 5 retries
-   **Redis**: Health check every 10 seconds with 5 retries

View health status:

```bash
docker-compose ps
```

## Networking

All services are connected via a custom bridge network called `db_network`, allowing them to communicate with each other using service names as hostnames.

## Data Persistence

All data is persisted in the `/home/george/devs/dockerDevs/Data` directory, organized by service:

-   MySQL data: `./Data/mysql/`
-   PostgreSQL data: `./Data/postgres/`
-   Redis data: `./Data/redis/`

Even if containers are stopped or removed, the data will be retained.

## Security Notes

⚠️ **Important**: The `.env` file contains sensitive credentials.

-   Never commit the `.env` file to version control
-   Change default passwords in production
-   Consider using Docker secrets for production deployments
-   Add `.env` to `.gitignore`

## Troubleshooting

### Containers not starting

-   Check logs: `docker-compose logs`
-   Ensure ports are not in use: `netstat -tulpn | grep -E '3306|5432|6379'`

### Permission denied for data directory

-   Ensure the `/home/george/devs/dockerDevs/Data` directory has proper permissions
-   Set ownership: `sudo chown -R 1000:1000 /home/george/devs/dockerDevs/Data`

### Connection refused

-   Wait a few seconds for services to fully start
-   Check health status: `docker-compose ps`
-   Verify ports are correctly mapped: `docker-compose ps`
