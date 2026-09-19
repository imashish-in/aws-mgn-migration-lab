<#
.SYNOPSIS
    Configures IIS Web Server and deploys a sample Clustered Web Application on Windows Server.
.DESCRIPTION
    This script is intended to run locally on each Windows cluster node.
    It installs IIS, ASP.NET 4.5 features, creates a health check endpoint,
    and sets up an informational clustered homepage.
.PARAMETER NodeName
    Identifier for the node (e.g., "Node-01" or "Node-02").
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$NodeName = "Node-01"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Configuring Windows Web Group / IIS Cluster - $NodeName " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Ensure TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Install IIS Features
Write-Host "[1/4] Installing IIS features and management tools..." -ForegroundColor Yellow
$features = @(
    "Web-Server", "Web-Common-Http", "Web-Default-Doc", "Web-Dir-Browsing",
    "Web-Http-Errors", "Web-Static-Content", "Web-Http-Redirect", "Web-Health",
    "Web-Http-Logging", "Web-Log-Libraries", "Web-Request-Monitor", "Web-Http-Tracing",
    "Web-Security", "Web-Filtering", "Web-Basic-Auth", "Web-Windows-Auth",
    "Web-App-Dev", "Web-Net-Ext45", "Web-Asp-Net45", "Web-ISAPI-Ext", "Web-ISAPI-Filter",
    "Web-Mgmt-Tools", "Web-Mgmt-Console"
)

Install-WindowsFeature -Name $features -IncludeManagementTools

# 3. Create Website Directories
Write-Host "[2/4] Setting up web root directories..." -ForegroundColor Yellow
$webRoot = "C:\inetpub\wwwroot"
if (!(Test-Path -Path "$webRoot\images")) {
    New-Item -Path "$webRoot\images" -ItemType Directory -Force | Out-Null
}

# 4. Create Health Check Endpoint
Write-Host "[3/4] Generating health check endpoint (/health.html)..." -ForegroundColor Yellow
Set-Content -Path "$webRoot\health.html" -Value "OK - $NodeName - $($env:COMPUTERNAME)" -Force

# 5. Create Sample Landing Page
Write-Host "[4/4] Generating clustered sample landing page (/index.html)..." -ForegroundColor Yellow
$accentColor = if ($NodeName -match "01") { "#38bdf8" } else { "#a78bfa" }
$badgeColor = if ($NodeName -match "01") { "#0284c7" } else { "#7c3aed" }

$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enterprise Web Group - $NodeName</title>
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
            background: $badgeColor;
            color: #ffffff;
            font-size: 0.8rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: 6px 14px;
            border-radius: 9999px;
        }
        h1 { font-size: 1.85rem; color: $accentColor; margin-bottom: 8px; font-weight: 700; }
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
            <div class="status-pill">IIS 10.0 Online</div>
        </div>
        <h1>Enterprise Web Group</h1>
        <p class="subtitle">Windows Cluster node ready for discovery and live block-level replication with AWS Application Migration Service (MGN).</p>
        
        <div class="grid">
            <div class="card">
                <div class="card-label">Assigned Node ID</div>
                <div class="card-value" style="color: $accentColor;">$NodeName</div>
            </div>
            <div class="card">
                <div class="card-label">Computer Hostname</div>
                <div class="card-value">$($env:COMPUTERNAME)</div>
            </div>
            <div class="card">
                <div class="card-label">Operating System</div>
                <div class="card-value">Windows Server 2022 Datacenter</div>
            </div>
            <div class="card">
                <div class="card-label">Replication Readiness</div>
                <div class="card-value" style="color: #38bdf8;">Ready for AWS MGN Agent</div>
            </div>
        </div>

        <div class="footer">
            <span>Health Endpoint: <a href="/health.html" style="color: $accentColor;">/health.html</a></span>
            <span>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</span>
        </div>
    </div>
</body>
</html>
"@

Set-Content -Path "$webRoot\index.html" -Value $htmlContent -Force

# 6. Restart IIS
Write-Host "Restarting IIS Web Server..." -ForegroundColor Yellow
iisreset /noforce | Out-Null

Write-Host "`nIIS Web Group setup completed successfully on $NodeName!" -ForegroundColor Green
Write-Host "Test locally via: http://localhost or http://localhost/health.html" -ForegroundColor Cyan
