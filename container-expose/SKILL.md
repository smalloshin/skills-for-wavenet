---
name: container-expose
description: Expose local services from Docker containers (or any environment) to the internet using tunnel services. Use when running a service in a container/local environment and need to share it externally without port mapping or reverse proxy configuration. Supports HTTP servers, web apps, APIs, development servers, or any TCP service. Triggers on requests like "expose this service", "make this accessible from outside", "share this publicly", "create a public URL for", or "I need external access to my container service".
---

# Container Service Exposer

Quickly expose local services to the internet using zero-configuration tunnel services.

## When to Use

- Running a service in a Docker container without port mapping
- Sharing a development server with teammates or clients
- Testing webhooks that require public URLs
- Demoing a local application
- Bypassing firewall restrictions for temporary access

## Quick Start

**Scenario 1: Expose an existing service**

```bash
# Service already running on port 8888
scripts/expose.sh -p 8888
```

**Scenario 2: Start service and expose it**

```bash
# Start Python HTTP server and expose
scripts/expose.sh -p 8000 -c "python3 -m http.server 8000 --bind 0.0.0.0"

# Start a Node.js app and expose
scripts/expose.sh -p 3000 -c "cd ~/myapp && npm start"
```

## Tunnel Services

### localtunnel (Default)

**Best for:** Quick tests, no setup required

```bash
scripts/expose.sh -p 8888
```

**Features:**
- No signup required
- Instant public HTTPS URL
- First access requires IP verification (tunnel password = your public IP)
- Free, but URLs are temporary

**Limitations:**
- Requires IP verification on first access
- Cannot choose subdomain (free tier)
- URLs change on restart

### ngrok

**Best for:** Professional demos, stable URLs

```bash
# Install first (if not present)
npm install -g ngrok

# Basic usage
scripts/expose.sh -p 8888 -t ngrok

# Custom subdomain (requires paid account)
scripts/expose.sh -p 8888 -t ngrok -s myapp
```

**Features:**
- More stable and reliable
- Custom subdomains (paid plans)
- Traffic inspection dashboard
- Better performance

**Requirements:**
- Account registration (free tier available)
- Install: `npm install -g ngrok`

### serveo

**Best for:** SSH-based, minimal dependencies

```bash
scripts/expose.sh -p 8888 -t serveo
```

**Features:**
- SSH-based (no installation)
- Works behind most firewalls
- Free and simple

**Requirements:**
- SSH access (usually available)
- May require public key in `~/.ssh/`

## Common Scenarios

### Web Development Server

```bash
# React/Vue/Next.js dev server
scripts/expose.sh -p 3000 -c "cd ~/myproject && npm run dev"
```

### Python HTTP Server

```bash
# Serve current directory
scripts/expose.sh -p 8080 -c "python3 -m http.server 8080 --bind 0.0.0.0"
```

### API Testing

```bash
# Expose Flask/FastAPI for webhook testing
scripts/expose.sh -p 5000 -c "cd ~/api && python app.py"
```

### Static Site Preview

```bash
# Build and serve
scripts/expose.sh -p 4000 -c "cd ~/site && jekyll serve --host 0.0.0.0"
```

## Important Notes

### Binding to 0.0.0.0

Services must bind to `0.0.0.0` (not `127.0.0.1`) to be accessible from tunnel services:

```bash
# ✅ Good
python3 -m http.server 8000 --bind 0.0.0.0

# ❌ Bad (only accessible from localhost)
python3 -m http.server 8000
```

### Verification and Security

**localtunnel IP verification:**
- First access shows verification page
- Enter your public IP as the tunnel password
- Get public IP: `curl ifconfig.me` or check verification page instructions

**Security considerations:**
- Tunnels expose services to the internet - use for development/testing only
- Don't expose sensitive data or production services
- Consider adding authentication to your service
- Tunnels are temporary - URLs expire when closed

### Troubleshooting

**Service won't start:**
```bash
# Check if port is already in use
lsof -i :8888
netstat -tlnp | grep 8888

# Kill existing process
kill <PID>
```

**Tunnel connection fails:**
```bash
# Verify service is accessible locally first
curl http://localhost:8888

# Check tunnel logs
cat /tmp/tunnel-8888.log
```

**"Cannot find module" or "command not found":**
```bash
# For localtunnel (auto-installs via npx)
npx -y localtunnel --version

# For ngrok
npm install -g ngrok
```

## Script Reference

### expose.sh

Main script for exposing services via tunnels.

**Usage:**
```bash
scripts/expose.sh [OPTIONS]
```

**Options:**
- `-p, --port PORT` - Port number to expose (required)
- `-t, --tunnel TYPE` - Tunnel service: localtunnel (default), ngrok, serveo
- `-s, --subdomain NAME` - Custom subdomain (if supported)
- `-c, --command CMD` - Command to start the service
- `-v, --verbose` - Verbose output
- `-h, --help` - Show help message

**Examples:**
```bash
# Basic expose
scripts/expose.sh -p 8888

# With custom command
scripts/expose.sh -p 3000 -c "npm start"

# Use ngrok with subdomain
scripts/expose.sh -p 8080 -t ngrok -s demo

# Verbose mode
scripts/expose.sh -p 8888 -v
```

**Output:**
- Public URL for accessing the service
- Tunnel logs in `/tmp/tunnel-<PORT>.log`
- Service logs in `/tmp/service-<PORT>.log` (if `-c` used)
- Press Ctrl+C to stop tunnel and service

## Docker-Specific Considerations

When running in Docker containers:

1. **Network mode:** Container must be able to reach the internet
2. **Port binding:** Service binds to `0.0.0.0` inside container
3. **No port mapping needed:** Tunnel bypasses Docker networking
4. **Container IP:** Tunnel connects to localhost from container's perspective

This skill is especially useful when:
- Container lacks `-p` port mapping
- Running in restricted environments
- Need temporary external access without reconfiguring Docker
- Testing across different environments quickly
