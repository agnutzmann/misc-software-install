# **Complete Guide: Installation, Backup, Restoration, and Update of Ghostfolio with Docker Compose**

This guide covers **installing Ghostfolio**, **correctly configuring `.env` and `docker-compose.yml`**, **backup and restoration of the PostgreSQL database**, **updating Ghostfolio**, and **solutions for common issues**.

---

## **1. Installing Ghostfolio with Docker Compose**

### **1.1. Install Dependencies**
Before installing Ghostfolio, ensure you have **Docker** and **Docker Compose** installed on your system.

- **Linux (Ubuntu/Debian)**:
  ```bash
  sudo apt update && sudo apt install -y docker docker-compose
  sudo systemctl enable docker --now
  ```

- **Windows (using WSL)**:
  1. Install **WSL 2** and **Docker Desktop** ([Download Docker](https://www.docker.com/products/docker-desktop/)).
  2. Enable WSL support in Docker Desktop.

- **MacOS**:
  Download and install **Docker Desktop** ([Download Docker](https://www.docker.com/products/docker-desktop/)).

---

### **1.2. Create Ghostfolio Directory**
```bash
mkdir -p ~/ghostfolio && cd ~/ghostfolio
```

---

### **1.3. Create the `.env` File**
Inside the `~/ghostfolio` directory, create a file named `.env`:

```bash
nano .env
```

Copy and paste the following content, replacing the passwords as necessary:

```ini
COMPOSE_PROJECT_NAME=ghostfolio-development

# CACHE (Redis)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=my_redis_password

# POSTGRES
POSTGRES_DB=ghostfolio-db
POSTGRES_USER=user
POSTGRES_PASSWORD=my_postgres_password

# DATABASE URL
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?connect_timeout=300&sslmode=prefer

# JWT
ACCESS_TOKEN_SALT=my_random_string_12345
JWT_SECRET_KEY=my_random_string_12345

# DEVELOPMENT
NX_ADD_PLUGINS=false
NX_NATIVE_COMMAND_RUNNER=false
```

> **⚠ Important:** `REDIS_HOST=redis` and `DATABASE_URL=postgres://postgres` are critical to avoid connection errors.

---

### **1.4. Create the `docker-compose.yml` File**
Inside the same directory, create the file `docker-compose.yml`:

```bash
nano docker-compose.yml
```

Copy and paste:

```yaml
version: "3.8"
services:
  ghostfolio:
    image: docker.io/ghostfolio/ghostfolio:latest
    container_name: ghostfolio
    restart: unless-stopped
    init: true
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    env_file:
      - .env
    ports:
      - 3333:3333
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:3333/api/v1/health']
      interval: 10s
      timeout: 5s
      retries: 5

  postgres:
    image: docker.io/library/postgres:15-alpine
    container_name: gf-postgres
    restart: unless-stopped
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_READ_SEARCH
      - FOWNER
      - SETGID
      - SETUID
    security_opt:
      - no-new-privileges:true
    env_file:
      - .env
    healthcheck:
      test:
        ['CMD-SHELL', 'pg_isready -d "$${POSTGRES_DB}" -U $${POSTGRES_USER}']
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - postgres:/var/lib/postgresql/data

  redis:
    image: docker.io/library/redis:alpine
    container_name: gf-redis
    restart: unless-stopped
    user: '999:1000'
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    env_file:
      - .env
    command:
      - /bin/sh
      - -c
      - redis-server --requirepass "$${REDIS_PASSWORD:?REDIS_PASSWORD variable is not set}"
    healthcheck:
      test:
        ['CMD-SHELL', 'redis-cli --pass "$${REDIS_PASSWORD}" ping | grep PONG']
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres:
```

---

### **1.5. Start the Containers**
```bash
docker compose up -d
```

Check running containers:
```bash
docker ps
```
Access **Ghostfolio** in your browser:
```
http://localhost:3333
```

---

## **2. Database Backup**

### **2.1. Manual Backup**
```bash
docker exec -t gf-postgres pg_dump -U user -d ghostfolio-db > backup_ghostfolio.sql
```

### **2.2. Automatic Daily Backup**
Create a script to generate daily backups and keep only the last 7:

```bash
mkdir -p ~/ghostfolio/backup
nano ~/ghostfolio/backup/backup_ghostfolio.sh
```

Add the following content to the script:

```bash
#!/bin/bash
BACKUP_DIR=~/ghostfolio/backup
BACKUP_FILE="$BACKUP_DIR/backup_ghostfolio_$(date +%Y-%m-%d).sql"

docker exec -t gf-postgres pg_dump -U user -d ghostfolio-db > "$BACKUP_FILE"

find "$BACKUP_DIR" -type f -name "backup_ghostfolio_*.sql" -mtime +7 -delete
```

Save the file and make it executable:
```bash
chmod +x ~/ghostfolio/backup/backup_ghostfolio.sh
```

Schedule the script to run daily at 2 AM:
```bash
crontab -e
```
Add this line:
```bash
0 2 * * * ~/ghostfolio/backup/backup_ghostfolio.sh
```

---

## **3. Restoring the Database**
```bash
docker exec -it gf-postgres psql -U user -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = 'ghostfolio-db' AND pid <> pg_backend_pid();" && \
docker exec -it gf-postgres psql -U user -d postgres -c "DROP DATABASE \"ghostfolio-db\";" && \
docker exec -it gf-postgres psql -U user -d postgres -c "CREATE DATABASE \"ghostfolio-db\" WITH OWNER \"user\" ENCODING 'UTF8';" && \
docker exec -i gf-postgres psql -U user -d ghostfolio-db < backup_ghostfolio.sql
```

---

## **4. Updating Ghostfolio Without Losing Data**

1. **Pull the latest Ghostfolio version:**
   ```bash
   docker compose pull
   ```
2. **Restart containers with the new version:**
   ```bash
   docker compose down && docker compose up -d
   ```
3. **Check logs to ensure everything is working:**
   ```bash
   docker logs ghostfolio --tail=50
   ```



