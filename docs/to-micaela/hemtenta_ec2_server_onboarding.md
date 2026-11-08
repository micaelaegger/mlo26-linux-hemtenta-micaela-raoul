# Hemtenta EC2 server - teammate onboarding

**Status:** 8 November 2026 | **Purpose:** Record what we have actually set up and tested on the **group EC2 server**, not the earlier standalone practice Book API server.

## 1. The setup at a glance

```text
GitHub (shared main branch)
         |
         | git fetch / pull
         v
EC2: Ubuntu 26.04.1 LTS (x86_64)
  |-- ubuntu: administer the host (sudo)
  |-- raoul, micaela: SSH development accounts
  |-- book-api: owns the deployed repository; Docker access
  |
  |-- NGINX :80                 [running; default site only]
  |-- Docker Engine             [running]
      |-- Compose: api          [FastAPI, host 127.0.0.1:8000]
      |-- Compose: db           [PostgreSQL 17, internal :5432]
      `-- db_data named volume   [persistent database storage]
```

The API and database now run in **two containers** on EC2. The NGINX reverse proxy has **not yet** been connected to FastAPI. A successful request to `localhost:8000` currently bypasses NGINX.

## 2. Host preparation completed

| Item | What we did / observed |
| --- | --- |
| EC2 | Ubuntu 26.04.1 LTS (Resolute Raccoon), x86_64; about 1.9 GiB RAM and a 30 GiB root filesystem. |
| Updates | Updated/upgraded OS packages through APT. |
| Swap | Created an approximately **2 GiB `/swapfile`**, set restrictive permissions and configured `/etc/fstab` for persistence. `free -h` confirmed 2 GiB swap available. |
| Git | Installed and verified (`git --version`: 2.53.0). |
| NGINX | Installed and enabled (1.28.3). Listens on port 80; default welcome page responds. |
| Docker | Installed Docker Engine, CLI, containerd, Buildx and the **Compose plugin**. Verified Engine 29.9.3 and Compose v5.7.0; `hello-world` ran successfully. |
| Services | `docker`, `nginx` and `ssh` reported active. |

### Why the Docker installation was a little different

We used **Docker's official Ubuntu APT repository**, rather than assuming Ubuntu's `docker.io` package or a standalone `docker-compose` executable was the right route. On Ubuntu **26.04 (`resolute`)**, we installed Docker's signing key in `/etc/apt/keyrings/docker.asc` and added `/etc/apt/sources.list.d/docker.sources` for `https://download.docker.com/linux/ubuntu` (suite `resolute`, `amd64`, signed by that key). We then installed:

```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

The Compose command is **`docker compose`** (space), not the older standalone `docker-compose`. The above summarizes the method; it is **not a verbatim transcript** of every installation command. Docker's logging driver was configured as `local`.

## 3. Accounts, SSH and permissions

| Account / group | Current purpose and access |
| --- | --- |
| `ubuntu` | Existing EC2 administrator account; use `sudo` for system changes such as `/etc/nginx`. |
| `raoul` | Personal developer account. In groups `raoul`, `sudo`, `bookdev`; SSH public-key login works. **Cannot currently use Docker's socket**, and `sudo` asks for a password that was not set for this account. |
| `micaela` | Personal developer account with SSH public-key login; added to `sudo` and `bookdev` during setup. |
| `bookdev` | Shared developer group. Git remains the normal way to exchange code; no shared server editing directory is required. |
| `book-api` | Dedicated deployment account; owns `/home/book-api/` and the repository; member of `docker` and can run Docker commands. **Docker group access is effectively root-level access**, so restrict use. |

SSH uses public-key authentication; password and keyboard-interactive SSH authentication were disabled. Root SSH login uses `PermitRootLogin prohibit-password`. Public keys were configured in the appropriate users' `authorized_keys` files (`.ssh` directories generally `700`, `authorized_keys` `600`). The `ubuntu` account was intended to accept both developers' keys for the course demonstration.

The `book-api` account has an SSH key at `~book-api/.ssh/github` and a Git SSH configuration for retrieving the shared repository. **Private SSH keys and database passwords must never go in Git.** The deployment account's home directory is restricted (`750`); regular `ubuntu` cannot list it without `sudo`. The Git SSH setup is working: `git fetch origin` succeeded.

**AWS security group:** SSH/22 was initially allowed from `0.0.0.0/0` as a temporary learning setup; tighten this to the developers' IPs when practical. Do **not** assume port 80/443 is externally reachable until the security group has been checked. Port 8000 is intentionally bound to loopback; PostgreSQL's 5432 is not published on the host.

## 4. Repository and first successful deployment

Repository on EC2:

```text
/home/book-api/mlo26-linux-hemtenta-micaela-raoul/
  |-- docker-compose.yml
  |-- api/
  |    |-- Dockerfile
  |    |-- app.py, db.py, init_db.py, ...
  |    `-- .env          [server-only; never commit]
  `-- scripts/server_health.sh
```

Remote: `git@github.com:micaelaegger/mlo26-linux-hemtenta-micaela-raoul.git`.

As `book-api`, we fetched GitHub, checked incoming commits, and fast-forwarded `main` to **`a5ac428`** (merged pull request #1, server health script). Then we validated Compose with `docker compose config --quiet` and confirmed services `db` and `api`.

We copied `.env.example` to **`api/.env`**, setting matching nonempty `DB_PASSWORD` and `POSTGRES_PASSWORD`. Keep `api/.env` private (`chmod 600 api/.env`) and check it is excluded by `.gitignore` and `.dockerignore`. The Compose file supplies it through `env_file: ./api/.env`.

**Deployment commands** (run as `book-api` inside the repository):

```bash
git status -sb
git fetch origin
git log --oneline HEAD..origin/main
git pull --ff-only origin main
docker compose config --quiet
docker compose up -d --build
docker compose ps
```

`up -d --build` built the API image on **EC2** (no image upload from Windows), pulled `postgres:17-alpine`, created the network and named volume, and started both containers. PostgreSQL became **healthy**. On this fresh database, we then ran:

```bash
docker compose exec api python init_db.py
```

This created the `books` table and seeded five demonstration books. Tested from the server as `raoul`:

```bash
curl -i http://127.0.0.1:8000/status  # HTTP 200, {"status":"ok"}
curl -i http://127.0.0.1:8000/books   # HTTP 200, five books
curl -i http://127.0.0.1:8000/docs    # HTTP 200, Swagger HTML
```

The named PostgreSQL volume preserves data across normal container recreations, but **is not a backup**. Avoid `docker compose down -v` unless intentionally deleting database volumes.

## 5. Monitoring and NGINX: current state

- `scripts/server_health.sh` was developed in VS Code, copied with `scp` to `raoul`, syntax-checked and run successfully. It reports timestamp, uptime/load, memory/swap, disk, service state and listening ports. It was merged via GitHub PR #1. It is **not yet installed as a scheduled cron job**; run with `bash scripts/server_health.sh` if needed (Git shows mode `100644`).
- NGINX currently serves its **default** site from `/etc/nginx/sites-enabled/default`. `/` returned HTTP 200, but `/docs` through port 80 returned NGINX's 404. We have **not** switched to the planned `book-api` reverse proxy or configured HTTPS yet.
- The planned proxy target is `http://127.0.0.1:8000`, with NGINX listening on 80 (later 443 with TLS). Keep the default site enabled until the new configuration is installed, tested with `sudo nginx -t`, and reloaded.

## 6. Quick verification and next work

```bash
# Ordinary account: host checks (no Docker privileges needed)
systemctl is-active docker nginx ssh
ss -ltn
curl -i http://127.0.0.1:8000/status

# From ubuntu: switch to the deployment account
sudo -iu book-api
cd ~/mlo26-linux-hemtenta-micaela-raoul
git status -sb
docker compose ps
docker compose logs --tail=30 api
```

**Next agreed work:** connect NGINX to the working API, verify the request path through port 80, then document and automate the NGINX configuration; afterward handle HTTPS, cron-based health monitoring/alerts, and backups. The final course demonstration must be reproducible from a fresh EC2 instance. Keep infrastructure scripts and configurations in Git rather than only editing them on the server.

> **Scope note:** This summarizes observed commands/results and earlier server-setup decisions. Some security-group and SSH settings have not been re-audited after the initial setup. It does not claim that pending NGINX, HTTPS, cron or backup tasks are complete.
