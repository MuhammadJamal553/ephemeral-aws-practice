# ☁️ Ephemeral AWS Cloud Architecture Practice Marathon

> **22 Days of Hands-On AWS + Terraform Infrastructure Engineering**

This repository documents my **Build → Deploy → Test → Destroy → Repeat** AWS cloud engineering marathon.

The goal is not to follow tutorials or deploy pre-built templates. It is to build real infrastructure muscle memory by repeatedly designing, provisioning, testing, troubleshooting, securing and destroying AWS infrastructure with **Terraform (Infrastructure as Code)**, while preparing for the **AWS Certified Solutions Architect – Associate (SAA-C03)** exam.

Each day introduces a new AWS service, architecture pattern or security concept and builds on the days before it.

---

## 🎯 Project Objectives

- ☁️ AWS cloud architecture (SAA-C03 aligned)
- 🏗️ Terraform Infrastructure as Code
- 🔐 IAM, STS and least-privilege security
- 🌐 Networking, VPC connectivity and global content delivery
- ⚡ Serverless architecture
- 📊 Monitoring and observability
- 🔑 Secrets and encryption management
- 🗄️ SQL and NoSQL databases
- 🚀 Auto Scaling and high availability
- 📦 Containerized workloads
- 📨 Event-driven and asynchronous architectures
- 🛡️ Edge security and Web Application Firewall protection
- 🌎 Multi-region resilience and compliance
- ♻️ Ephemeral infrastructure and cost-conscious engineering

```text
Design → Terraform Code → plan → apply → Verify → Troubleshoot → destroy → Repeat
```

---

# 🏃‍♂️ The Progressive Architectural Journey

## Phase 1: Storage, Delivery and Serverless Foundations (Days 1–6)

| Day | Project | Architecture and concepts |
|---|---|---|
| 1 | `Day1-ThePrivateS3Bucket` | Private S3 bucket with strict public access blocks |
| 2 | `Day2-CloudFront` | CloudFront CDN → private S3 origin using Origin Access Control (OAC) |
| 3 | `Day3-LambdaAPI` | API Gateway (HTTP API) → Lambda (Python 3.12), CORS, invocation permissions |
| 4 | `Day4-SNSAlerts` | Lambda → SNS topic, least-privilege IAM, pub/sub decoupling |
| 5 | `Day5-FullStackConvergence` | CloudFront + S3 frontend + API Gateway + Lambda + SNS combined |
| 6 | `Day6-DynamoDBState` | API Gateway → Lambda → DynamoDB with atomic counters |

## Phase 2: Automation, Observability and Identity (Days 7–10)

| Day | Project | Architecture and concepts |
|---|---|---|
| 7 | `Day7-VariablesAutomation` | `variables.tf`, outputs, parameterized and reusable Terraform |
| 8 | `Day8-CloudWatchAlarms` | CloudWatch alarms on Lambda failures, incident tripwires |
| 9 | `Day9-SecretsManagement` | SSM Parameter Store with KMS-encrypted `SecureString`, no hardcoded secrets |
| 10 | `Day10-IAMCrossAccount` | STS `AssumeRole`, trust policies, temporary credentials |

## Phase 3: Data Tier and Global Resilience (Days 11–14)

| Day | Project | Architecture and concepts |
|---|---|---|
| 11 | `Day11-RDSPostgres` | RDS PostgreSQL, private subnet groups, security groups |
| 12 | `Day12-ElasticCacheRedis` | ElastiCache Redis, in-memory caching, network-controlled access |
| 13 | `Day13-GlobalRoute53` | Multi-region workload (us-east-1 + us-west-2) using Terraform provider aliases, DR simulation |
| 14 | `Day14-EdgeSecurityWAF` | AWS WAFv2 Web ACL, IP rate limiting, CloudFront integration |

## Phase 4: Compute, Containers and Messaging (Days 15–18)

| Day | Project | Architecture and concepts |
|---|---|---|
| 15 | `Day15-AutoScalingEC2` | EC2 Auto Scaling Group + Application Load Balancer across multiple AZs |
| 16 | `Day16-ECSFargate` | ECS cluster, Fargate tasks, task definitions, serverless containers |
| 17 | `Day17-SQSDeadLetterQueue` | SQS queue with redrive policy and a Dead-Letter Queue |
| 18 | `Day18-SNSMessageFiltering` | SNS fan-out to multiple SQS queues with JSON filter policies |

## Phase 5: Compliance, Networking and DNS (Days 19–22) 🆕

### 🗂️ Day 19: S3 Cross-Region Replication + Object Lock

**Project:** `Day19-S3ReplicationCompliance`

```text
Source bucket (us-east-1)  ──async replication──►  Replica bucket (us-west-2)
   Versioning + Object Lock                           Versioning + Object Lock
   WORM (Compliance mode)
```

**Concepts:** cross-region replication (CRR), mandatory versioning on both buckets, the replication IAM role (including Object Lock permissions), Object Lock in **Compliance** mode (WORM), provider aliases for a second region.

**Lesson:** Compliance mode locked objects cannot be deleted by anyone, including the root user, until retention expires. Plan the destroy step before uploading test objects.

---

### 🌐 Day 20: Transit Gateway + VPC Peering

**Project:** `Day20-TransitGatewayPeering`

```text
      VPC-A 10.10.0.0/16 ◄──── VPC Peering ────► VPC-B 10.20.0.0/16
              │                                        │
              └──────────► Transit Gateway ◄───────────┘
                                  ▲
                                  │
                        VPC-C 10.30.0.0/16
```

**Concepts:** Transit Gateway hub-and-spoke, VPC peering, route tables, longest prefix match, SSM Session Manager access without SSH keys or NAT.

**What I measured (A pinging B and C):**

| Path | Route used | TTL | Latency |
|---|---|---|---|
| A → B | VPC peering (`10.20.0.0/16`, most specific) | 127 | about 0.4 ms |
| A → C | Transit Gateway (`10.0.0.0/8`) | 126 | about 5 ms |

Turning peering off with `-var="enable_peering=false"` moved A → B onto the Transit Gateway path, since the broader `10.0.0.0/8` route took over.

**Exam takeaways:**
- The **most specific route wins** (longest prefix match).
- VPC peering is **non-transitive** and needs non-overlapping CIDRs.
- Transit Gateway is transitive and scales to many VPCs, but bills per attachment-hour plus per GB.
- Every route is a separate `aws_route` resource. Mixing inline `route {}` blocks with `aws_route` makes Terraform fight over the table.

---

### 🔒 Day 21: VPC Endpoints (Private Connectivity)

**Project:** `Day21-VPCEndpointsPrivateLink`

```text
   Private subnet (no IGW, no NAT, no public IP)
   ┌──────────────────────────────────────┐
   │  EC2 ──► S3 Gateway Endpoint ────────┼──► S3 bucket
   │   └────► SSM Interface Endpoints ────┼──► Systems Manager
   └──────────────────────────────────────┘
```

**Concepts:** gateway endpoint (S3, DynamoDB) vs interface endpoint (PrivateLink), private DNS, `aws:SourceVpce` bucket-policy condition, managing a server with SSM and no internet.

**What I verified:**
- From inside the private server, a request to the internet failed (`NO_INTERNET_AS_EXPECTED`).
- The same server read an S3 object through the gateway endpoint.
- The route table had only the `local` route and an S3 prefix-list route to the endpoint, with no `0.0.0.0/0` route.

**Troubleshooting lesson:** the SSM agent stayed offline because the interface endpoints did not exist in AWS yet. Re-applying and rebooting the instance fixed it. The agent retries slowly, so a reboot after the endpoints become `available` is the fast fix.

**Exam takeaway:** "reach AWS services without the internet" means a **VPC endpoint**, not a NAT gateway.

---

### 🌐 Day 22: Route 53 Private Hosted Zone and Weighted Routing

**Project:** `Day22-Route53PrivateDNS`

**Concepts:** private hosted zones (the VPC needs DNS support and hostnames enabled), weighted records for blue/green traffic shifting, routing policy types, alias vs CNAME.

**Status:** deployed and destroyed within the same session. I stopped before running the verification tests, because Route 53 is **not free-tier eligible** (only hosted zones deleted within 12 hours are not charged). The code is kept as a reference.

---

# 🧠 Skills Developed So Far

| Area | Technologies / Concepts |
|---|---|
| Infrastructure as Code | Terraform, variables, outputs, `for_each`, `count`, provider aliases |
| Object Storage | S3, CloudFront, OAC, Cross-Region Replication, Object Lock |
| Serverless | Lambda, API Gateway (HTTP APIs) |
| Messaging | SNS, SQS, DLQs, fan-out, filter policies |
| Databases | DynamoDB, RDS PostgreSQL, ElastiCache Redis |
| Networking | VPC, Transit Gateway, VPC peering, VPC endpoints, route tables, ALB, Route 53 private zones |
| Compute | EC2, Auto Scaling, ECS Fargate |
| Security | IAM, STS, KMS, SSM Parameter Store, AWS WAF, security groups |
| Monitoring | CloudWatch metrics and alarms |
| Resilience | Multi-AZ, multi-region, retries and failure isolation |

---

# 🛠️ Prerequisites

- AWS account
- AWS CLI, Terraform CLI and Git
- Securely configured AWS credentials

```bash
aws --version
terraform --version
git --version
aws sts get-caller-identity
```

# ♻️ Infrastructure Lifecycle

```bash
terraform init       # download providers
terraform fmt        # format
terraform validate   # check syntax
terraform plan       # preview changes
terraform apply      # deploy
# verify with the AWS CLI, browser or API calls
terraform destroy    # tear everything down
```

Destroying resources after each lab is intentional. It proves the infrastructure is **reproducible and disposable** and keeps costs under control.

---

# 🔐 Security Principles Practiced

- Least-privilege, resource-specific IAM policies
- Private-by-default infrastructure
- Temporary credentials with STS `AssumeRole`
- S3 public access blocking and CloudFront OAC
- Encrypted secrets (KMS `SecureString`), no hardcoded credentials
- AWS WAF edge protection with rate limiting
- Security-group-controlled access
- WORM data retention with Object Lock
- Keyless server access with SSM Session Manager
- **Repository hygiene:** `.gitignore` excludes state files, `.terraform/` folders, `.tfvars`, zip packages and temp files, so no account details or secrets are committed

---

# 💰 Cost Awareness

Some resources bill by the hour even when idle, for example **Transit Gateway attachments, interface VPC endpoints, NAT Gateways, RDS, ElastiCache and load balancers**. Always:

1. Read the `terraform plan` before applying.
2. Run `terraform destroy` when the lab ends.
3. Check the AWS console for leftovers.

### Free-tier-only mode

My AWS free account is close to expiring, so from Day 23 onward every lab uses **only free-tier eligible services with no hourly cost** (for example Lambda, DynamoDB, Step Functions, S3 and CloudWatch within their free allowances). Days 20 to 22 used a small amount of promotional credit and were destroyed immediately after use.

---

# 📂 Repository Structure

```text
ephemeral-aws-practice/
│
├── Day1-ThePrivateS3Bucket/
├── Day2-CloudFront/
├── Day3-LambdaAPI/
├── Day4-SNSAlerts/
├── Day5-FullStackConvergence/
├── Day6-DynamoDBState/
├── Day7-VariablesAutomation/
├── Day8-CloudWatchAlarms/
├── Day9-SecretsManagement/
├── Day10-IAMCrossAccount/
├── Day11-RDSPostgres/
├── Day12-ElasticCacheRedis/
├── Day13-GlobalRoute53/
├── Day14-EdgeSecurityWAF/
├── Day15-AutoScalingEC2/
├── Day16-ECSFargate/
├── Day17-SQSDeadLetterQueue/
├── Day18-SNSMessageFiltering/
├── Day19-S3ReplicationCompliance/
├── Day20-TransitGatewayPeering/
├── Day21-VPCEndpointsPrivateLink/
├── Day22-Route53PrivateDNS/
│
├── .gitignore
└── README.md
```

---

# 📈 Current Progress

```text
AWS + Terraform Practice Marathon

██████████████████████  22 Architecture Challenges Completed
```

**Current milestone:** Day 22 ✅

---

# 🚀 What This Repository Represents

A **cloud engineering laboratory**, not a single production app. It documents a progression through increasingly complex AWS architectures:

> **Build it → break and debug it → understand it → destroy it → rebuild something more advanced.**

**Long-term focus:** Cloud Engineering • DevOps • Infrastructure as Code • AWS Security • Automation • System Architecture

---

## 👨‍💻 Author

**Muhammad Jamal Khan**
BS Computer Science | Cloud / DevOps / Cybersecurity Learner
GitHub: **MuhammadJamal553**

---

## ⭐ Project Status

🟢 **Active:** more AWS architecture challenges are being added as the marathon continues.