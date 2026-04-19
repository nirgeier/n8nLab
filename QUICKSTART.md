# 🚀 Quick Start: n8n Local Setup

## One-Command Setup

```bash
./scripts/setup.sh
```

That's it! n8n will be running at **http://localhost:5678**

---

## What Gets Set Up

| Component      | Purpose                       | Access                     |
| -------------- | ----------------------------- | -------------------------- |
| **n8n**        | Workflow automation engine    | http://localhost:5678      |
| **PostgreSQL** | Workflow & execution database | `postgres:5432` (internal) |
| **pgAdmin**    | Database management UI        | http://localhost:5050      |

---

## Available Scripts

### Setup (First Time)

```bash
./scripts/setup.sh
```

- Checks prerequisites
- Creates configuration
- Starts all services
- Displays connection URLs

### Status Check

```bash
./scripts/status.sh
```

- Shows running services
- Health checks
- Resource usage
- Helpful commands

### Cleanup

```bash
./scripts/cleanup.sh
```

- Stops all services
- Removes containers
- Optionally removes volumes
- Cleanup configuration

---

## Manual Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose stop

# View logs
docker-compose logs -f n8n

# Check status
docker-compose ps

# Access container shell
docker-compose exec n8n /bin/sh

# Database shell
docker-compose exec postgres psql -U n8n -d n8n
```

---

## Environment Variables

Edit `.env` file before starting:

```bash
# Database
DB_USER=n8n
DB_PASSWORD=n8n_password
DB_NAME=n8n

# n8n
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http

# Timezone
TZ=UTC
```

Copy from template:

```bash
cp .env.example .env
```

---

## First Steps

1. **Open n8n**

   ```
   http://localhost:5678
   ```

2. **Set Admin Credentials**
   - Email
   - Password

3. **Create First Workflow**
   - Click "New"
   - Add Manual Trigger
   - Add action node
   - Test and save

4. **Explore Labs**
   - Check [Labs 001-013](Labs/index.md) for guided workflows

---

## Storage & Backups

- **Workflows**: Stored in PostgreSQL
- **Credentials**: Encrypted in database
- **Executions**: Logged in database
- **Local directory**: `./workflows/` for exports

### Backup Database

```bash
docker-compose exec postgres pg_dump -U n8n -d n8n > backup.sql
```

### Restore Database

```bash
docker-compose exec -T postgres psql -U n8n -d n8n < backup.sql
```

---

## Troubleshooting

**"Port 5678 in use"?**

```bash
# Change port in docker-compose.yml or .env
# Then restart:
docker-compose restart
```

**"Cannot connect to Docker daemon"?**

```bash
# Check if Docker is running
docker ps

# Start Docker if needed
# macOS: open -a Docker
# Linux: sudo systemctl start docker
```

**"n8n not responding"?**

```bash
# Check logs
./scripts/status.sh

# Restart
docker-compose restart n8n
```

---

## Learn More

- **[Lab 013: Local Setup Guide](Labs/013-LocalSetup/README.md)** - Comprehensive guide
- **[Labs 001-012](Labs/index.md)** - Full workflow tutorials
- **[n8n Docs](https://docs.n8n.io)** - Official documentation

---

## System Requirements

- **RAM**: 2GB minimum (4GB recommended)
- **Disk**: 1GB free space
- **Docker**: Community edition (free)
- **Network**: Docker network access

---

**Ready to go?** Run `./scripts/setup.sh` now! 🎉
