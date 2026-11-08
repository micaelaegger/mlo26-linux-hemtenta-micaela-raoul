# Book API — EC2 server quickstart

**For:** Micaela (developer account) and the project team · **Prepared:** 5–6 November 2026  
**Scope:** Ubuntu host preparation and SSH access. **The Book API and database are not deployed yet.**

## 1. Connect and check your account

Run **from your own laptop** (replace the placeholders; keep private keys on your laptop):

```bash
# Your personal development account
ssh -i /path/to/micaela_dev_private_key micaela@<EC2_PUBLIC_IP>

# Shared ubuntu administration account (required for the course)
ssh -i /path/to/micaela_admin_private_key ubuntu@<EC2_PUBLIC_IP>
```

Once connected, try:

```bash
whoami        # Which Linux account am I using?
id            # UID, primary group and supplementary groups
pwd           # Current directory
sudo whoami   # Verify sudo privileges; should print 'root' if configured
exit          # Disconnect
```

Your **developer** public key is authorized in `/home/micaela/.ssh/authorized_keys`. Our separate **admin** public keys are both authorized in `/home/ubuntu/.ssh/authorized_keys`. Never share a *private* key.

## 2. What's installed, and why?

| Component | Version / location | Why we use it |
|---|---|---|
| Ubuntu Linux | **26.04.1 LTS**, `x86_64` | EC2 operating system |
| Git | **2.53.0**; already present | Version control / GitHub deployment later |
| Python | **3.14.4**; already present | Scripts and exercises (container Python can differ) |
| Docker Engine | **29.9.3** | Run isolated application containers |
| Docker Compose | **5.7.0** | Start the future API + database together from `compose.yaml` |
| Docker Buildx | **0.38.1** | Build container images |
| NGINX | **1.28.3** | Web server now; reverse proxy for API later |
| logrotate | **3.22.0** | Rotate ordinary file logs (such as NGINX logs) |
| `curl`, `jq` | Installed via APT | Test HTTP endpoints; format/filter JSON |
| `tree`, `htop` | Installed via APT | View directories; watch CPU/RAM/processes |
| `acl` | Installed via APT | Inspect/set extended file permissions |
| `zip`, `unzip` | Installed via APT | Archive/extract files |
| `ca-certificates` | Installed via APT | Verify HTTPS certificates for outgoing connections |

**Resources:** ~2 GiB physical RAM, **2 GiB swap** (`/swapfile`), **32 GB EBS disk** (~25 GB free at last check). The root filesystem is `ext4`.

## 3. How the host was prepared (reference, not commands to rerun blindly)

**Ubuntu packages:** `apt update` refreshes the package list; `apt upgrade` applies available upgrades; `apt install` installs software.

```bash
sudo apt update
sudo apt upgrade
sudo apt install -y ca-certificates curl jq tree htop acl zip unzip
sudo apt install nginx
```

**Docker:** Installed via **Docker's official Ubuntu APT repository**, rather than Ubuntu's `docker.io` package. We registered Docker's signing key at `/etc/apt/keyrings/docker.asc` and its repository in `/etc/apt/sources.list.d/docker.sources`, then installed:

```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

Docker's `/etc/docker/daemon.json` uses `{"log-driver": "local"}`: Docker automatically rotates container output logs. `sudo docker ...` is intentional; neither developer needs membership in the effectively root-privileged `docker` group.

**NGINX:** Installed from Ubuntu's APT packages and enabled on startup. Configuration lives in `/etc/nginx/`; logs live in `/var/log/nginx/`. NGINX currently serves the **default page** locally—not our API.

**Swap:** Created a 2 GiB `/swapfile` (`fallocate`, `chmod 600`, `mkswap`, `swapon`), then added `/swapfile none swap sw 0 0` to `/etc/fstab` so it activates after reboot. A backup of `fstab` was saved first.

**SSH/users:** Micaela has an individual developer account; the `ubuntu` account is shared for the course requirement. Verify any other developer account separately. SSH public-key login is enabled; SSH password and keyboard-interactive authentication are disabled. The `bookdev` group is intended for shared project access; check group memberships with `id`. SSH keys are one full public key per line in each account's `authorized_keys` (directory `700`, file `600`).

## 4. Fast confidence tests

```bash
# Versions / services
sudo docker version
sudo docker compose version
nginx -v
systemctl is-active docker containerd nginx  # Each should report active
sudo nginx -t                              # NGINX syntax check

# NGINX is working locally (should return HTTP 200)
curl -I http://127.0.0.1/

# Docker can fetch and execute a container
sudo docker run --rm hello-world
```

**What `docker run --rm hello-world` does:**

```text
Look for 'hello-world' image on this server
    |-- missing? --> download from Docker Hub
    v
Create a temporary container from the image
    v
Execute it --> print "Hello from Docker!"
    v
--rm removes the stopped CONTAINER
    v
The IMAGE stays stored locally for reuse
```

Verify that distinction:

```bash
sudo docker ps -a    # No hello-world container remains
sudo docker images   # hello-world image remains
```

## 5. Quick diagnostics / where to look

| Question | Command |
|---|---|
| Available RAM and swap? | `free -h` / `swapon --show` |
| Available disk space? | `df -h /` |
| Docker disk usage? | `sudo docker system df` |
| Which TCP ports are listening? | `sudo ss -lntp` |
| Any failed services? | `sudo systemctl --failed` |
| Docker daemon errors? | `sudo journalctl -u docker -n 30 --no-pager` |
| NGINX service errors? | `sudo journalctl -u nginx -n 30 --no-pager` |
| NGINX error log? | `sudo tail -n 30 /var/log/nginx/error.log` |
| NGINX log rotation rules? | `cat /etc/logrotate.d/nginx` |
| Log rotation scheduler? | `systemctl status logrotate.timer` |
| Which groups do I belong to? | `id` |
| SSH login settings? | `sudo sshd -T` (check the authentication entries) |

**Logging rule of thumb:** Docker's `local` driver rotates *container output*; `logrotate` rotates conventional log files; `journalctl` reads service logs managed by systemd. A systemd timer already runs `logrotate`.

## 6. Important boundaries and next steps

- **AWS inbound rules currently allow only TCP 22 (SSH)**; the SSH source is currently `0.0.0.0/0` because we work from changing networks. Key-only authentication reduces risk but does **not** eliminate internet exposure. Restrict access or use Session Manager later if practical.
- NGINX listens on port **80** on Ubuntu, but AWS does **not yet** allow inbound port 80. Port **443** is not configured. PostgreSQL (**5432**) and the API (**8000**) should not be published publicly.
- Sharing `ubuntu` is a **deliberate coursework exception**; it weakens individual command attribution. Always use your own development account for normal work.
- **Not yet created/deployed:** `/srv/book-api/`, the application containers, PostgreSQL, GitHub deploy key, HTTPS/Certbot, and project-specific permissions. Do not assume those are ready.
- Avoid `sudo docker system prune --volumes`: later it could delete database volumes.

**Next milestone:** Finish both developers' SSH/sudo tests, set up group ownership and shared-directory permissions (setgid/ACLs), then connect GitHub and deploy the Book API using Docker Compose.
