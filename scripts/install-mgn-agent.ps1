<#
.SYNOPSIS
    Downloads and installs the AWS Application Migration Service (MGN) Replication Agent on Windows Server.
.DESCRIPTION
    Automates downloading the region-specific AWS Replication Agent installer and registering
    the Windows machine with AWS MGN to begin continuous block-level data replication.
.PARAMETER Region
    AWS Region where AWS Application Migration Service is initialized (e.g., us-east-1).
.PARAMETER AwsAccessKeyId
    AWS Access Key ID with AWSApplicationMigrationAgentInstallationPolicy.
.PARAMETER AwsSecretAccessKey
    AWS Secret Access Key.
.PARAMETER AwsSessionToken
    (Optional) AWS Session Token if using temporary IAM STS credentials.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage="Enter your target AWS Region (e.g., us-east-1)")]
    [string]$Region,

    [Parameter(Mandatory=$true, HelpMessage="Enter your AWS Access Key ID")]
    [string]$AwsAccessKeyId,

    [Parameter(Mandatory=$true, HelpMessage="Enter your AWS Secret Access Key")]
    [string]$AwsSecretAccessKey,

    [Parameter(Mandatory=$false)]
    [string]$AwsSessionToken = ""
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  AWS Application Migration Service (MGN) Agent Installer " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Ensure TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Setup download directory
$workDir = "C:\lab-scripts\mgn"
if (!(Test-Path -Path $workDir)) {
    New-Item -Path $workDir -ItemType Directory -Force | Out-Null
}

$installerPath = "$workDir\AwsReplicationWindowsInstaller.exe"
$installerUrl = "https://aws-application-migration-service-$Region.s3.$Region.amazonaws.com/latest/windows/AwsReplicationWindowsInstaller.exe"

# 3. Download Installer
Write-Host "[1/3] Downloading AWS Replication Agent installer for region $Region..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "Download completed: $installerPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download AWS Replication Agent installer. Please verify region '$Region' and network/proxy settings. Error: $_"
    exit 1
}

# 4. Build Arguments & Run Installer
Write-Host "[2/3] Installing AWS MGN Replication Agent..." -ForegroundColor Yellow

$argList = @(
    "--region", $Region,
    "--aws-access-key-id", $AwsAccessKeyId,
    "--aws-secret-access-key", $AwsSecretAccessKey,
    "--no-prompt"
)

if (![string]::IsNullOrEmpty($AwsSessionToken)) {
    $argList += @("--aws-session-token", $AwsSessionToken)
}

$process = Start-Process -FilePath $installerPath -ArgumentList $argList -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "Installer finished successfully with exit code 0." -ForegroundColor Green
} else {
    Write-Warning "Installer exited with code: $($process.ExitCode). Check C:\Program Files (x86)\AWS Replication Agent\logs"
}

# 5. Verify Service Status
Write-Host "[3/3] Checking AWS Replication service..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$mgnService = Get-Service -DisplayName "*AWS Replication*" -ErrorAction SilentlyContinue

if ($mgnService) {
    Write-Host "`nAWS Replication Agent is registered and running!" -ForegroundColor Green
    Write-Host "Service Name: $($mgnService.Name)" -ForegroundColor Gray
    Write-Host "Status      : $($mgnService.Status)" -ForegroundColor Green
    Write-Host "`nNext Step: Navigate to AWS MGN Console -> 'Source servers' to monitor initial sync." -ForegroundColor Cyan
} else {
    Write-Warning "AWS Replication Service could not be found. Check installation logs in C:\Program Files (x86)\AWS Replication Agent\"
}
