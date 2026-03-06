#!/bin/bash
# Container Service Exposer
# Quickly expose a local service to the internet using tunnel services

set -e

# Default values
PORT=""
TUNNEL="localtunnel"
SUBDOMAIN=""
SERVICE_CMD=""
VERBOSE=false

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Expose a local service to the internet using tunnel services.

OPTIONS:
    -p, --port PORT         Port number to expose (required)
    -t, --tunnel TYPE       Tunnel service: localtunnel (default), ngrok, serveo
    -s, --subdomain NAME    Custom subdomain (if supported by tunnel service)
    -c, --command CMD       Command to start the service (optional)
    -v, --verbose           Verbose output
    -h, --help              Show this help message

EXAMPLES:
    # Expose existing service on port 8888
    $0 -p 8888

    # Start Python HTTP server and expose
    $0 -p 8000 -c "python3 -m http.server 8000 --bind 0.0.0.0"

    # Use ngrok with custom subdomain
    $0 -p 3000 -t ngrok -s myapp

    # Use serveo (SSH-based tunnel)
    $0 -p 8080 -t serveo

TUNNEL SERVICES:
    localtunnel - Simple, no signup required (default)
                  First access requires IP verification
                  
    ngrok       - More stable, requires account for custom subdomains
                  Install: npm install -g ngrok
                  
    serveo      - SSH-based, no installation needed
                  May require public key in ~/.ssh/

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -t|--tunnel)
            TUNNEL="$2"
            shift 2
            ;;
        -s|--subdomain)
            SUBDOMAIN="$2"
            shift 2
            ;;
        -c|--command)
            SERVICE_CMD="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate port
if [ -z "$PORT" ]; then
    echo "Error: Port is required"
    usage
fi

log() {
    if [ "$VERBOSE" = true ]; then
        echo "[$(date +'%H:%M:%S')] $*"
    fi
}

# Start service if command provided
if [ -n "$SERVICE_CMD" ]; then
    log "Starting service: $SERVICE_CMD"
    eval "$SERVICE_CMD" > /tmp/service-$PORT.log 2>&1 &
    SERVICE_PID=$!
    log "Service started with PID: $SERVICE_PID"
    sleep 2
    
    # Verify service is running
    if ! ps -p $SERVICE_PID > /dev/null; then
        echo "Error: Service failed to start"
        cat /tmp/service-$PORT.log
        exit 1
    fi
fi

# Setup cleanup trap
cleanup() {
    log "Cleaning up..."
    if [ -n "$SERVICE_PID" ]; then
        log "Stopping service (PID: $SERVICE_PID)"
        kill $SERVICE_PID 2>/dev/null || true
    fi
    if [ -n "$TUNNEL_PID" ]; then
        log "Stopping tunnel (PID: $TUNNEL_PID)"
        kill $TUNNEL_PID 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

# Start tunnel
case $TUNNEL in
    localtunnel)
        log "Starting localtunnel..."
        if [ -n "$SUBDOMAIN" ]; then
            npx -y localtunnel --port $PORT --subdomain $SUBDOMAIN &
        else
            npx -y localtunnel --port $PORT &
        fi
        TUNNEL_PID=$!
        sleep 5
        echo ""
        echo "🎉 Service exposed via localtunnel!"
        echo "📍 Check the URL above (or in /tmp/tunnel-$PORT.log)"
        echo "⚠️  First access requires IP verification"
        echo ""
        ;;
        
    ngrok)
        log "Starting ngrok..."
        if ! command -v ngrok &> /dev/null; then
            echo "Error: ngrok not found. Install with: npm install -g ngrok"
            exit 1
        fi
        
        if [ -n "$SUBDOMAIN" ]; then
            ngrok http $PORT --subdomain=$SUBDOMAIN > /tmp/tunnel-$PORT.log 2>&1 &
        else
            ngrok http $PORT > /tmp/tunnel-$PORT.log 2>&1 &
        fi
        TUNNEL_PID=$!
        sleep 3
        
        # Extract URL from ngrok API
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | grep -o 'https://.*' | head -1)
        echo ""
        echo "🎉 Service exposed via ngrok!"
        echo "📍 URL: $NGROK_URL"
        echo ""
        ;;
        
    serveo)
        log "Starting serveo..."
        if [ -n "$SUBDOMAIN" ]; then
            ssh -o StrictHostKeyChecking=no -R $SUBDOMAIN:80:localhost:$PORT serveo.net 2>&1 | tee /tmp/tunnel-$PORT.log &
        else
            ssh -o StrictHostKeyChecking=no -R 80:localhost:$PORT serveo.net 2>&1 | tee /tmp/tunnel-$PORT.log &
        fi
        TUNNEL_PID=$!
        sleep 3
        echo ""
        echo "🎉 Service exposed via serveo!"
        echo "📍 Check the URL above"
        echo ""
        ;;
        
    *)
        echo "Error: Unknown tunnel service: $TUNNEL"
        echo "Supported: localtunnel, ngrok, serveo"
        exit 1
        ;;
esac

# Keep running
echo "Press Ctrl+C to stop the tunnel and service"
wait $TUNNEL_PID
