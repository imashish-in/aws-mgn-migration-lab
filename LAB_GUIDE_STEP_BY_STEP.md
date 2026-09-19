# AWS MGN & Application Discovery Service: Step-by-Step Lab Guide

This guide walks you through every step of migrating an enterprise **Heterogeneous Web Group (1x Windows Server 2022 IIS + 1x Amazon Linux 2023 NGINX)** from a simulated on-premises datacenter into AWS using **AWS Application Discovery Service (ADS)** and **AWS Application Migration Service (MGN)**.

---

## Lab Prerequisites

1. **AWS Account**: Active account with administrative privileges.
2. **AWS CLI**: Installed and configured locally (`aws configure`).
3. **Region**: Recommended `us-east-1` (N. Virginia) or `us-west-2` (Oregon).
4. **Knowledge Level**: Basic familiarity with EC2, VPC, IIS, NGINX, Linux Bash, and Windows PowerShell.

---

## Step 1: Initialize AWS Application Migration Service (MGN)

Before installing agents, MGN must be initialized in your chosen AWS Region.

1. Open the **AWS Management Console** and navigate to **Application Migration Service**.
2. Click **Get Started** / **Set up service**.
3. Under **Replication Template Settings**:
   - **Staging area subnet**: Select default or choose any subnet in your target region.
   - **Replication Server instance type**: `t3.small` (recommended default).
   - **EBS volume type**: `gp3`.
   - **Data routing**: `Public IP` (or `Private IP` if using VPN/DirectConnect/Peering).
4. Click **Create template**.

> [!NOTE]
> AWS MGN automatically provisions the required IAM service-linked role (`AWSServiceRoleForApplicationMigrationService`) during this one-time setup.

---

## Step 2: Deploy CloudFormation Stacks

Deploy the 4 CloudFormation modules in order:

### 2.1 Deploy Module 01: Dual-VPC Networking
Creates the Source VPC (`10.0.0.0/16`) and Target VPC (`10.1.0.0/16`), subnets, and security groups.

```powershell
aws cloudformation create-stack `
  --stack-name mgn-lab-01-networking `
  --template-body file://cft/01-networking.yaml

# Wait for completion:
aws cloudformation wait stack-create-complete --stack-name mgn-lab-01-networking
Write-Host "Module 01 Deployed Successfully!" -ForegroundColor Green
```

### 2.2 Deploy Module 02: IAM Roles & Policies
Creates instance profiles for Windows/Linux instances and the dedicated agent installer user.

```powershell
aws cloudformation create-stack `
  --stack-name mgn-lab-02-iam `
  --template-body file://cft/02-iam-roles.yaml `
  --capabilities CAPABILITY_NAMED_IAM

aws cloudformation wait stack-create-complete --stack-name mgn-lab-02-iam
Write-Host "Module 02 Deployed Successfully!" -ForegroundColor Green
```

### 2.3 Deploy Module 03: Source Web Group (1x Windows + 1x Linux)
Provisions **Node-01 (Windows Server 2022 with IIS)** and **Node-02 (Amazon Linux 2023 with NGINX)** behind an Application Load Balancer.

```powershell
aws cloudformation create-stack `
  --stack-name mgn-lab-03-source-webgroup `
  --template-body file://cft/03-source-windows-webgroup.yaml

Write-Host "Creating Web Group (Takes ~4 minutes for OS initialization)..."
aws cloudformation wait stack-create-complete --stack-name mgn-lab-03-source-webgroup
Write-Host "Module 03 Deployed Successfully!" -ForegroundColor Green
```

### 2.4 Deploy Module 04: Target Launch Template & Target ALB
Provisions the target ALB and launch configuration for post-migration cutover.

```powershell
aws cloudformation create-stack `
  --stack-name mgn-lab-04-target `
  --template-body file://cft/04-target-launch-template.yaml

aws cloudformation wait stack-create-complete --stack-name mgn-lab-04-target
Write-Host "Module 04 Deployed Successfully!" -ForegroundColor Green
```

---

## Step 3: Verify the Source Web Group (Windows & Linux)

Retrieve the Source ALB URL and verify that both Windows IIS and Linux NGINX nodes are serving traffic.

```powershell
$sourceAlbUrl = (aws cloudformation describe-stacks `
  --stack-name mgn-lab-03-source-webgroup `
  --query "Stacks[0].Outputs[?OutputKey=='WebGroupAlbUrl'].OutputValue" `
  --output text)

Write-Host "Source Web Group URL: $sourceAlbUrl" -ForegroundColor Cyan

# Test the source endpoint using the verification script:
.\scripts\verify-migration.ps1 -SourceEndpoint $sourceAlbUrl -Iterations 6
```

Open `$sourceAlbUrl` in your web browser. Refresh multiple times:
- **Node-01 (Windows)** displays a **Blue** card showing *IIS 10.0 Online*.
- **Node-02 (Linux)** displays a **Green** card showing *NGINX Online*.

---

## Step 4: Create Installer IAM Credentials

Generate an Access Key ID and Secret Access Key for the `mgn-lab-agent-installer` user created in Module 02.

```powershell
$credentials = aws iam create-access-key --user-name mgn-lab-agent-installer | ConvertFrom-Json

$accessKeyId = $credentials.AccessKey.AccessKeyId
$secretAccessKey = $credentials.AccessKey.SecretAccessKey

Write-Host "=== SAVE THESE CREDENTIALS FOR AGENT INSTALLATION ===" -ForegroundColor Yellow
Write-Host "AWS_ACCESS_KEY_ID     : $accessKeyId"
Write-Host "AWS_SECRET_ACCESS_KEY : $secretAccessKey"
Write-Host "====================================================" -ForegroundColor Yellow
```

---

## Step 5: Install AWS Application Discovery Service (ADS)

The Discovery Agent collects OS specs, CPU/Memory utilization, and network connections.

### 5.1 Connect via AWS Systems Manager (SSM)
1. Open the **AWS EC2 Console** -> **Instances**.
2. Select the target instance -> Click **Connect** -> **Session Manager** -> **Connect**.

---

### 5.2 Install Discovery Agent on Node 01 (Windows)
In the Session Manager PowerShell session on **`mgn-lab-source-web-node-01-windows`**:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://s3.us-west-2.amazonaws.com/aws-discovery-agent.us-west-2/windows/latest/AWSDiscoveryAgentInstaller.exe" -OutFile "C:\AWSDiscoveryAgentInstaller.exe"

# Replace credentials:
.\AWSDiscoveryAgentInstaller.exe REGION="us-east-1" KEY_ID="<YOUR_ACCESS_KEY_ID>" KEY_SECRET="<YOUR_SECRET_ACCESS_KEY>" /q

# Verify Service
Get-Service -Name "AWSDiscoveryAgent"
```

---

### 5.3 Install Discovery Agent on Node 02 (Linux)
In the Session Manager Bash terminal on **`mgn-lab-source-web-node-02-linux`**:

```bash
mkdir -p /tmp/discovery && cd /tmp/discovery
curl -s -O https://s3-us-west-2.amazonaws.com/aws-discovery-agent.us-west-2/linux/latest/aws-discovery-agent.tar.gz
tar -xzf aws-discovery-agent.tar.gz

# Replace credentials:
sudo bash install -r us-east-1 -k "<YOUR_ACCESS_KEY_ID>" -s "<YOUR_SECRET_ACCESS_KEY>"

# Verify Service
sudo systemctl status aws-discovery-daemon --no-pager
```

---

### 5.4 View in AWS Migration Hub Console
1. Navigate to **AWS Migration Hub** -> **Discovery** -> **Servers**.
2. Within 5-10 minutes, both the Windows node and Linux node will appear with their Hostnames, IP addresses, OS versions, and hardware specs.
3. Select both servers -> Click **Group as application** -> Name it `Web-Cluster-App`.

---

## Step 6: Install AWS Application Migration Service (MGN) Agent

The MGN Replication Agent performs block-level data replication from the source servers to the AWS Staging Area.

### 6.1 Install MGN Agent on Node 01 (Windows)
In the Session Manager PowerShell session on **`mgn-lab-source-web-node-01-windows`**:

```powershell
$Region = "us-east-1"  # Replace with your lab region

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path "C:\mgn" -ItemType Directory -Force | Out-Null
Invoke-WebRequest -Uri "https://aws-application-migration-service-$Region.s3.$Region.amazonaws.com/latest/windows/AwsReplicationWindowsInstaller.exe" -OutFile "C:\mgn\AwsReplicationWindowsInstaller.exe"

# Run Installer:
cd C:\mgn
.\AwsReplicationWindowsInstaller.exe --region $Region --aws-access-key-id "<YOUR_ACCESS_KEY_ID>" --aws-secret-access-key "<YOUR_SECRET_ACCESS_KEY>" --no-prompt
```

---

### 6.2 Install MGN Agent on Node 02 (Linux)
In the Session Manager Bash terminal on **`mgn-lab-source-web-node-02-linux`**:

```bash
REGION="us-east-1" # Replace with your lab region

mkdir -p /tmp/mgn && cd /tmp/mgn
curl -s -O "https://aws-application-migration-service-${REGION}.s3.${REGION}.amazonaws.com/latest/linux/aws-replication-installer-init.py"

# Run Installer:
sudo python3 aws-replication-installer-init.py \
    --region "$REGION" \
    --aws-access-key-id "<YOUR_ACCESS_KEY_ID>" \
    --aws-secret-access-key "<YOUR_SECRET_ACCESS_KEY>" \
    --no-prompt

# Verify Service
sudo systemctl status aws-replication-service --no-pager
```

---

### 6.3 Monitor Replication Progress
1. Open the **AWS Application Migration Service** console.
2. Click **Source servers**.
3. You will observe both the Windows and Linux servers.
4. The **Data replication status** will transition through:
   - `Initiating` (Replication server spinning up in staging subnet)
   - `Initial sync (X%)` (Replicating EBS blocks)
   - `Continuous data replication` / `Healthy` (Continuous real-time delta sync)
5. **Lifecycle status** will become: `Ready for testing`.

---

## Step 7: Configure Launch Settings for Target Cloud

Configure how the target EC2 instances should be launched in the **Target VPC**:

1. In the AWS MGN Console, click on the **Windows Server**.
   - Go to **Launch settings** tab -> Click **Modify**.
   - Target VPC: `mgn-lab-target-vpc`.
   - Subnet: `mgn-lab-target-subnet-1`.
   - Security Groups: `mgn-lab-target-web-sg`.
   - Instance Type: `t3.medium`.
   - Save changes.
2. Click on the **Linux Server**.
   - Go to **Launch settings** tab -> Click **Modify**.
   - Target VPC: `mgn-lab-target-vpc`.
   - Subnet: `mgn-lab-target-subnet-2`.
   - Security Groups: `mgn-lab-target-web-sg`.
   - Instance Type: `t3.small` (or `t3.medium`).
   - Save changes.

---

## Step 8: Launch Test Instances (Migration Validation)

Testing is a mandatory safety gate in AWS MGN before cutover.

1. In **Source servers**, select both Windows and Linux nodes.
2. Click **Test and Cutover** -> **Launch test instances**.
3. Confirm by clicking **Launch**.
4. Monitor the **Launch history** tab until the status is `Launched`.
5. Check the **EC2 Console**: You will see two new instances named with suffix `(Test)`.
6. Test HTTP port 80 on each test instance to confirm IIS on Windows and NGINX on Linux are running cleanly.
7. Return to MGN Console -> Select both servers -> Click **Test and Cutover** -> **Mark as "Ready for cutover"**.
8. Confirm deletion of test instances when prompted (MGN will clean up the temporary test EC2 instances).

---

## Step 9: Perform Final Cutover Migration

Cutover stops active replication, syncs final block deltas, and launches the production target instances.

1. Select both servers in **Source servers**.
2. Click **Test and Cutover** -> **Launch cutover instances**.
3. Confirm and click **Launch**.
4. Once instances are in `Running` state in EC2:
   - Attach the newly launched Cutover EC2 instances to the **Target Target Group** (`mgn-lab-tgt-tg`):
     - EC2 Console -> **Target Groups** -> `mgn-lab-tgt-tg` -> **Register targets**.
     - Select both migrated instances (Windows and Linux) -> Include as pending -> Register targets.
5. In MGN Console -> Select servers -> **Test and Cutover** -> **Finalize cutover**.
   - This completes the migration lifecycle and frees up the temporary Staging Area replication server and staging disks!

---

## Step 10: Post-Migration Verification

Run the verification test suite against both the Source ALB and Target ALB:

```powershell
$targetAlbUrl = (aws cloudformation describe-stacks `
  --stack-name mgn-lab-04-target `
  --query "Stacks[0].Outputs[?OutputKey=='TargetAlbUrl'].OutputValue" `
  --output text)

Write-Host "Target Migrated Web Group URL: $targetAlbUrl" -ForegroundColor Green

# Run full comparative validation across both Windows and Linux target nodes:
.\scripts\verify-migration.ps1 `
  -SourceEndpoint $sourceAlbUrl `
  -TargetEndpoint $targetAlbUrl `
  -Iterations 10
```

Both target instances (Windows Node 01 and Linux Node 02) will respond with `HTTP 200 OK`, matching the source state with zero data loss.

---

## Step 11: Teardown & Resource Cleanup

To prevent ongoing AWS charges, delete resources in the following order:

```powershell
# 1. Delete IAM Access Keys created in Step 4
aws iam delete-access-key --user-name mgn-lab-agent-installer --access-key-id $accessKeyId

# 2. In MGN Console: Select Source Servers -> Actions -> "Disconnect from service" -> "Archive"

# 3. Delete CloudFormation Stacks (Reverse order)
aws cloudformation delete-stack --stack-name mgn-lab-04-target
aws cloudformation delete-stack --stack-name mgn-lab-03-source-webgroup
aws cloudformation delete-stack --stack-name mgn-lab-02-iam
aws cloudformation delete-stack --stack-name mgn-lab-01-networking

Write-Host "Cleanup initiated successfully!" -ForegroundColor Green
```
