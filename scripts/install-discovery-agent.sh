#!/bin/bash
# ==============================================================================
# AWS Application Discovery Agent Installer for Linux
# ==============================================================================
set -e

if [ "$#" -lt 3 ]; then
    echo "Usage: sudo bash install-discovery-agent.sh <REGION> <AWS_ACCESS_KEY_ID> <AWS_SECRET_ACCESS_KEY>"
    echo "Example: sudo bash install-discovery-agent.sh us-east-1 AKIAIOSFODNN7EXAMPLE wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    exit 1
fi

REGION="$1"
AWS_ACCESS_KEY_ID="$2"
AWS_SECRET_ACCESS_KEY="$3"

echo "=========================================================="
echo "  Installing AWS Application Discovery Agent (Linux)      "
echo "=========================================================="

WORK_DIR="/tmp/aws-discovery"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "[1/3] Downloading AWS Discovery Agent tarball..."
curl -s -O https://s3-us-west-2.amazonaws.com/aws-discovery-agent.us-west-2/linux/latest/aws-discovery-agent.tar.gz

echo "[2/3] Extracting and running installer..."
tar -xzf aws-discovery-agent.tar.gz
sudo bash install -r "$REGION" -k "$AWS_ACCESS_KEY_ID" -s "$AWS_SECRET_ACCESS_KEY"

echo "[3/3] Checking discovery daemon status..."
sudo systemctl status aws-discovery-daemon --no-pager || true

echo "AWS Application Discovery Agent successfully installed and registered!"
