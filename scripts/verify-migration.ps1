<#
.SYNOPSIS
    Validates and tests the Source and Target Windows Web Groups before and after migration.
.DESCRIPTION
    Sends test HTTP requests to source/target load balancers and individual node endpoints,
    checking HTTP status codes, response times, and cluster node payload health.
.PARAMETER SourceEndpoint
    Source ALB DNS name or Node IP/URL (e.g. "http://mgn-lab-source-alb-1234.us-east-1.elb.amazonaws.com").
.PARAMETER TargetEndpoint
    Target ALB DNS name or Migrated Node IP/URL.
.PARAMETER Iterations
    Number of requests to test load balancing distribution (default: 5).
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$SourceEndpoint,

    [Parameter(Mandatory=$false)]
    [string]$TargetEndpoint,

    [Parameter(Mandatory=$false)]
    [int]$Iterations = 5
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  AWS MGN Web Group Migration Verification Test Suite    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Test-WebEndpoint {
    param (
        [string]$Url,
        [string]$EnvironmentLabel
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return
    }

    if (!$Url.StartsWith("http://") -and !$Url.StartsWith("https://")) {
        $Url = "http://$Url"
    }

    Write-Host "`n>> Testing $EnvironmentLabel: $Url" -ForegroundColor Yellow

    # Test Base URL
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        $sw.Stop()

        Write-Host "  [+] HTTP Status    : $($resp.StatusCode) $($resp.StatusDescription)" -ForegroundColor Green
        Write-Host "  [+] Latency        : $($sw.ElapsedMilliseconds) ms" -ForegroundColor Gray

        if ($resp.Content -match "Node-01") {
            Write-Host "  [+] Responding Node: Node-01 (Windows Server 2022 - IIS 10)" -ForegroundColor Cyan
        } elseif ($resp.Content -match "Node-02") {
            Write-Host "  [+] Responding Node: Node-02 (Amazon Linux 2023 - NGINX)" -ForegroundColor Green
        } else {
            Write-Host "  [+] Response Body  : (Received valid content)" -ForegroundColor White
        }
    }
    catch {
        Write-Host "  [-] Failed to reach $Url: $_" -ForegroundColor Red
    }

    # Test Health Endpoint
    $healthUrl = "$($Url.TrimEnd('/'))/health.html"
    try {
        $healthResp = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5
        Write-Host "  [+] Health Check   : $($healthResp.Content.Trim()) (Status: $($healthResp.StatusCode))" -ForegroundColor Green
    }
    catch {
        Write-Host "  [-] Health Check Failed ($healthUrl): $_" -ForegroundColor Red
    }
}

# 1. Test Source if provided
if (![string]::IsNullOrEmpty($SourceEndpoint)) {
    Test-WebEndpoint -Url $SourceEndpoint -EnvironmentLabel "Source Environment (Simulated On-Prem)"
}

# 2. Test Target if provided
if (![string]::IsNullOrEmpty($TargetEndpoint)) {
    Test-WebEndpoint -Url $TargetEndpoint -EnvironmentLabel "Target Cloud Environment (Migrated)"
}

# 3. Test Cluster Distribution
if (![string]::IsNullOrEmpty($SourceEndpoint) -or ![string]::IsNullOrEmpty($TargetEndpoint)) {
    $activeUrl = if (![string]::IsNullOrEmpty($TargetEndpoint)) { $TargetEndpoint } else { $SourceEndpoint }
    if (!$activeUrl.StartsWith("http://") -and !$activeUrl.StartsWith("https://")) {
        $activeUrl = "http://$activeUrl"
    }

    Write-Host "`n>> Running Cluster Load Balancing Distribution Test ($Iterations requests)..." -ForegroundColor Yellow
    $node1Count = 0
    $node2Count = 0

    for ($i = 1; $i -le $Iterations; $i++) {
        try {
            $r = Invoke-WebRequest -Uri $activeUrl -UseBasicParsing -TimeoutSec 5
            if ($r.Content -match "Node-01") { $node1Count++ }
            elseif ($r.Content -match "Node-02") { $node2Count++ }
        }
        catch {
            Write-Warning "Request $i failed"
        }
        Start-Sleep -Milliseconds 300
    }

    Write-Host "  [Distribution Results]" -ForegroundColor Cyan
    Write-Host "  - Node-01 Hits: $node1Count" -ForegroundColor White
    Write-Host "  - Node-02 Hits: $node2Count" -ForegroundColor White
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  Verification Completed                                  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
