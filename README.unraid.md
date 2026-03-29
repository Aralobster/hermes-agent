# Hermes Agent — Unraid Template

Custom Docker image + Unraid template for running Hermes Agent on Unraid.

## What's in the custom image

The official `nousresearch/hermes-agent:latest` is missing some dependencies that are needed for full functionality on Unraid:

- `markdown` — for Matrix HTML rendering in the gateway
- `uv` — for MCP `uvx` command
- `playwright` — for browser automation (dogfood skill)

These are built into `ghcr.io/aralobster/hermes-agent:latest` (branch: `fix/docker-matrix-update`).

## Quick start

### 1. (One-time) Build and push the custom image

You'll need Docker Hub or GHCR credentials configured. Using GHCR (free):

```bash
# Authenticate
docker login ghcr.io -u YOUR_GITHUB_USERNAME

# Build from your fork (this directory)
docker build -t ghcr.io/aralobster/hermes-agent:latest -f Dockerfile.unraid .

# Push
docker push ghcr.io/aralobster/hermes-agent:latest
```

If you prefer Docker Hub, replace `ghcr.io/aralobster/hermes-agent:latest` with
`yourdockerhubusername/hermes-agent:latest` in the template XML.

### 2. Install the template

**Option A — Manual (quick):**
```bash
# On your Unraid server, download the template:
curl -o /boot/config/docker.d/hermes-agent.xml \
  https://raw.githubusercontent.com/Aralobster/Aralobster/main/hermes-agent.xml
```

**Option B — Community Apps:**
Submit `hermes-agent.xml` to the [Unraid Community Apps](https://forums.unraid.net/forum/83/community-apps/)
forum with a brief description. Follow the [CA template guidelines](https://forums.unraid.net/topic/89926-community-applications-repository-requirements/).

### 3. First run

1. Pull the **Hermes Agent** container from the Docker UI
2. Set the following **Config** fields:
   - **Post Arguments**: `--gateway`
   - **Add another Path**: `/opt/data` → map to a host path (e.g. `/mnt/user/appdata/hermes`)
3. Start the container — it will output setup instructions in the logs
4. Follow the logs: `docker logs hermes-agent` or the Unraid Docker UI log viewer

### 4. Configure chat platform

After the container is running, edit `/opt/data/.env` (on the host at your mapped path)
to add your API keys and platform credentials. Restart the container to apply.

For Matrix (your setup):
```
MINIMAX_API_KEY=your_key_here
MATRIX_HOMESERVER=https://matrix.home.lan
MATRIX_ACCESS_TOKEN=your_matrix_token
MATRIX_USER_ID=@youruser:matrix.home.lan
```

## Updating

When a new Hermes Agent version is released:
```bash
# Pull the latest official image
docker pull nousresearch/hermes-agent:latest

# Rebuild your custom image
docker build -t ghcr.io/aralobster/hermes-agent:latest -f Dockerfile.unraid .

# Push
docker push ghcr.io/aralobster/hermes-agent:latest
```

Then in Unraid Docker UI, set the container to pull the latest image.

## Files

- `Dockerfile.unraid` — builds the custom image extending `nousresearch/hermes-agent:latest`
- `hermes-agent.xml` — Unraid Docker template
- `README.unraid.md` — this file
