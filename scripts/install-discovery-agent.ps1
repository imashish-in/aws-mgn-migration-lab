<#
.SYNOPSIS
    Downloads and installs the AWS Application Discovery Agent on Windows Server.
.DESCRIPTION
    Automates the installation and service startup of the AWS Application Discovery Agent
    to capture system performance, running processes, and network connections.
.PARAMETER Region
    AWS Region where Application Discovery Service is configured (e.g., us-east-1, us-west-2).
.PARAMETER AwsAccessKeyId
    AWS Access Key ID with Discovery agent permissions.
.PARAMETER AwsSecretAccessKey
    AWS Secret Access Key.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage="Enter your target AWS Region (e.g., us-east-1)")]
    [string]$Region,

    [Parameter(Mandatory=$true, HelpMessage="Enter your AWS Access Key ID")]
    [string]$AwsAccessKeyId,

    [Parameter(Mandatory=$true, HelpMessage="Enter your AWS Secret Access Key")]
    [string]$AwsSecretAccessKey
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  AWS Application Discovery Agent Installer (Windows)     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Ensure TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Setup download directory
$workDir = "C:\lab-scripts\discovery"
if (!(Test-Path -Path $workDir)) {
    New-Item -Path $workDir -ItemType Directory -Force | Out-Null
}

$installerPath = "$workDir\AWSDiscoveryAgentInstaller.exe"
$installerUrl = "https://s3.us-west-2.amazonaws.com/aws-discovery-agent.us-west-2/windows/latest/AWSDiscoveryAgentInstaller.exe"

# 3. Download Installer
Write-Host "[1/3] Downloading AWS Discovery Agent installer..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "Download completed: $installerPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download AWS Discovery Agent installer. Error: $_"
    exit 1
}

# 4. Silent Installation
Write-Host "[2/3] Installing AWS Discovery Agent in region: $Region..." -ForegroundColor Yellow
$installArgs = "REGION=`"$Region`" KEY_ID=`"$AwsAccessKeyId`" KEY_SECRET=`"$AwsSecretAccessKey`" /q"

$process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "Installer process completed successfully." -ForegroundColor Green
} else {
    Write-Warning "Installer exited with code: $($process.ExitCode). Verifying service..."
}

# 5. Verify Service Health
Write-Host "[3/3] Verifying AWS Discovery Agent service status..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$service = Get-Service -Name "AWSDiscoveryAgent" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "`nAWS Discovery Agent is active and RUNNING!" -ForegroundColor Green
    Write-Host "Server $($env:COMPUTERNAME) will appear in the AWS Migration Hub / Discovery console within 5-10 minutes." -ForegroundColor Cyan
} else {
    Write-Warning "AWSDiscoveryAgent service is not running. Please check logs in C:\ProgramData\Amazon\AWSDiscoveryAgent\logs"
}
