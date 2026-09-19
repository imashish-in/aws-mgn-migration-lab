#!/bin/bash
# ==============================================================================
# AWS Application Migration Service (MGN) Replication Agent Installer for Linux
# ==============================================================================
set -e

if [ "$#" -lt 3 ]; then
    echo "Usage: sudo bash install-mgn-agent.sh <REGION> <AWS_ACCESS_KEY_ID> <AWS_SECRET_ACCESS_KEY> [AWS_SESSION_TOKEN]"
    echo "Example: sudo bash install-mgn-agent.sh us-east-1 AKIAIOSFODNN7EXAMPLE wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    exit 1
fi

REGION="$1"
AWS_ACCESS_KEY_ID="$2"
AWS_SECRET_ACCESS_KEY="$3"
AWS_SESSION_TOKEN="$4"

echo "=========================================================="
echo "  Installing AWS Application Migration Service (MGN) Agent"
echo "=========================================================="

WORK_DIR="/tmp/aws-mgn"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "[1/3] Downloading AWS Replication installer script for region: $REGION..."
INSTALLER_URL="https://aws-application-migration-service-${REGION}.s3.${REGION}.amazonaws.com/latest/linux/aws-replication-installer-init.py"
curl -s -O "$INSTALLER_URL"

echo "[2/3] Executing AWS MGN Replication Agent installation..."
EXTRA_ARGS=""
if [ -n "$AWS_SESSION_TOKEN" ]; then
    EXTRA_ARGS="--aws-session-token $AWS_SESSION_TOKEN"
fi

sudo python3 aws-replication-installer-init.py \
    --region "$REGION" \
    --aws-access-key-id "$AWS_ACCESS_KEY_ID" \
    --aws-secret-access-key "$AWS_SECRET_ACCESS_KEY" \
    --no-prompt \
    $EXTRA_ARGS

echo "[3/3] Checking replication service..."
sudo systemctl status aws-replication-service --no-pager || true

echo "AWS MGN Replication Agent installation finished successfully!"
echo "Server will appear in AWS MGN Console -> 'Source servers' for continuous block sync."
