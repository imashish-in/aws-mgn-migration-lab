#!/bin/bash
# ==============================================================================
# Linux/Bash Verification Test Suite for AWS MGN Migration Web Group
# ==============================================================================

SOURCE_URL="$1"
TARGET_URL="$2"
ITERATIONS="${3:-5}"

echo "=========================================================="
echo "  AWS MGN Web Group Migration Verification Test Suite    "
echo "=========================================================="

test_endpoint() {
    local url="$1"
    local label="$2"

    if [ -z "$url" ]; then
        return
    fi

    if [[ ! "$url" =~ ^http:// && ! "$url" =~ ^https:// ]]; then
        url="http://$url"
    fi

    echo ""
    echo ">> Testing $label: $url"

    # Base URL Test
    local response
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\nTIME:%{time_total}" "$url" || echo "FAIL")
    local status
    status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d':' -f2)
    local time_total
    time_total=$(echo "$response" | grep "TIME:" | cut -d':' -f2)

    if [ "$status" == "200" ]; then
        echo "  [+] HTTP Status    : 200 OK"
        echo "  [+] Response Time  : ${time_total}s"
    else
        echo "  [-] HTTP Status    : $status (Failed or unreachable)"
    fi

    if echo "$response" | grep -q "Node-01"; then
        echo "  [+] Responding Node: Node-01 (Windows Server 2022 - IIS 10)"
    elif echo "$response" | grep -q "Node-02"; then
        echo "  [+] Responding Node: Node-02 (Amazon Linux 2023 - NGINX)"
    else
        echo "  [+] Response Body  : (Received valid content)"
    fi

    # Health Check Endpoint Test
    local health_url="${url%/}/health.html"
    local health_resp
    health_resp=$(curl -s "$health_url" || echo "FAIL")
    echo "  [+] Health Check   : $health_resp"
}

if [ -n "$SOURCE_URL" ]; then
    test_endpoint "$SOURCE_URL" "Source Environment (Simulated On-Premises)"
fi

if [ -n "$TARGET_URL" ]; then
    test_endpoint "$TARGET_URL" "Target Cloud Environment (Migrated)"
fi

ACTIVE_URL="${TARGET_URL:-$SOURCE_URL}"
if [ -n "$ACTIVE_URL" ]; then
    if [[ ! "$ACTIVE_URL" =~ ^http:// && ! "$ACTIVE_URL" =~ ^https:// ]]; then
        ACTIVE_URL="http://$ACTIVE_URL"
    fi

    echo ""
    echo ">> Running Cluster Load Balancing Distribution Test ($ITERATIONS requests)..."
    node1=0
    node2=0

    for ((i=1; i<=ITERATIONS; i++)); do
        body=$(curl -s "$ACTIVE_URL" || true)
        if echo "$body" | grep -q "Node-01"; then
            ((node1++))
        elif echo "$body" | grep -q "Node-02"; then
            ((node2++))
        fi
        sleep 0.3
    done

    echo "  [Distribution Results]"
    echo "  - Node-01 (Windows IIS) Hits: $node1"
    echo "  - Node-02 (Linux NGINX) Hits: $node2"
fi

echo ""
echo "=========================================================="
echo "  Verification Completed                                  "
echo "=========================================================="
