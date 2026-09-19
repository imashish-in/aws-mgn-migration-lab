#!/bin/bash
# ==============================================================================
# Setup NGINX Web Server and Clustered Web Application on Amazon Linux 2023
# ==============================================================================
set -e

echo "=== [1/4] Installing and Enabling NGINX ==="
dnf update -y
dnf install -y nginx

systemctl enable nginx
systemctl start nginx

echo "=== [2/4] Creating Directory Structure & Health Endpoint ==="
mkdir -p /usr/share/nginx/html
echo "OK - Node-02 (Linux) - $(hostname)" > /usr/share/nginx/html/health.html

echo "=== [3/4] Generating Sample Clustered Web App (Linux Node) ==="
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

cat << 'EOF' > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enterprise Web Group - Node 02 (Linux)</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background: #0b0f19;
            color: #f1f5f9;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }
        .container {
            background: linear-gradient(145deg, #1e293b, #0f172a);
            border: 1px solid #334155;
            border-radius: 16px;
            max-width: 680px;
            width: 100%;
            padding: 36px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.6);
        }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
        .badge {
            background: #10b981;
            color: #ffffff;
            font-size: 0.8rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: 6px 14px;
            border-radius: 9999px;
        }
        h1 { font-size: 1.85rem; color: #34d399; margin-bottom: 8px; font-weight: 700; }
        p.subtitle { color: #94a3b8; font-size: 1rem; line-height: 1.5; margin-bottom: 24px; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .card {
            background: rgba(15, 23, 42, 0.7);
            border: 1px solid #334155;
            border-radius: 10px;
            padding: 16px;
        }
        .card-label { font-size: 0.75rem; color: #64748b; font-weight: 700; text-transform: uppercase; }
        .card-value { font-size: 1.1rem; color: #f8fafc; font-weight: 600; margin-top: 6px; word-break: break-all; }
        .status-pill { display: inline-flex; align-items: center; color: #22c55e; font-weight: 600; }
        .status-pill::before {
            content: '';
            width: 8px;
            height: 8px;
            background: #22c55e;
            border-radius: 50%;
            margin-right: 8px;
            box-shadow: 0 0 8px #22c55e;
        }
        .footer {
            border-top: 1px solid #334155;
            padding-top: 16px;
            display: flex;
            justify-content: space-between;
            font-size: 0.85rem;
            color: #64748b;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="badge">Simulated Source Environment</div>
            <div class="status-pill">NGINX Online</div>
        </div>
        <h1>Enterprise Web Group</h1>
        <p class="subtitle">Linux Cluster node ready for discovery and live block-level replication with AWS Application Migration Service (MGN).</p>
        
        <div class="grid">
            <div class="card">
                <div class="card-label">Assigned Node ID</div>
                <div class="card-value" style="color: #34d399;">Node-02 (Linux Secondary)</div>
            </div>
            <div class="card">
                <div class="card-label">Computer Hostname</div>
                <div class="card-value" id="hostname-placeholder">Loading...</div>
            </div>
            <div class="card">
                <div class="card-label">Operating System</div>
                <div class="card-value">Amazon Linux 2023</div>
            </div>
            <div class="card">
                <div class="card-label">Replication Readiness</div>
                <div class="card-value" style="color: #38bdf8;">Ready for AWS MGN Agent</div>
            </div>
        </div>

        <div class="footer">
            <span>Health Endpoint: <a href="/health.html" style="color: #34d399;">/health.html</a></span>
            <span id="timestamp-placeholder"></span>
        </div>
    </div>
    <script>
        document.getElementById('hostname-placeholder').innerText = window.location.hostname || 'Linux-Node-02';
        document.getElementById('timestamp-placeholder').innerText = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

echo "=== [4/4] Restarting NGINX ==="
systemctl restart nginx
echo "Linux Web Group Node configured successfully!"
