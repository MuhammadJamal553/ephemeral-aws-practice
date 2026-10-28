# ☁️ Ephemeral AWS Cloud Architecture Practice Marathon

> **17 Days of Hands-On AWS + Terraform Infrastructure Engineering**

This repository documents my progressive **Build → Deploy → Test → Destroy → Repeat** AWS cloud engineering marathon.

The goal of this project is not simply to follow tutorials or deploy pre-built templates. It is to develop practical cloud engineering skills and genuine infrastructure muscle memory by repeatedly designing, provisioning, testing, troubleshooting, securing, and destroying AWS infrastructure using **Terraform (Infrastructure as Code)**.

Each day introduces a new AWS service, architectural concept, security practice, or infrastructure pattern while building upon concepts learned during previous days.

---

## 🎯 Project Objectives

Through this marathon, I am practicing:

- ☁️ AWS cloud architecture
- 🏗️ Terraform Infrastructure as Code
- 🔐 IAM and least-privilege security
- 🌐 Networking and global content delivery
- ⚡ Serverless architecture
- 📊 Monitoring and observability
- 🔑 Secrets management
- 🗄️ SQL and NoSQL databases
- 🚀 Auto Scaling infrastructure
- 📦 Containerized workloads
- 📨 Event-driven and asynchronous architectures
- 🛡️ Edge security and Web Application Firewall protection
- ♻️ Ephemeral infrastructure and cost-conscious cloud engineering

The core workflow is intentionally simple:

```text
Design
   ↓
Terraform Code
   ↓
terraform plan
   ↓
terraform apply
   ↓
Test / Verify
   ↓
Troubleshoot
   ↓
terraform destroy
   ↓
Repeat with a more advanced architecture
```

---

# 🏃‍♂️ The Progressive Architectural Journey

## 📁 Day 1 — Private Amazon S3 Storage

**Architecture:** Private Amazon S3 bucket.

**Core Concepts:**
- Amazon S3
- Terraform AWS provider
- S3 public access blocking
- Secure object storage
- Infrastructure creation and destruction

**Focus:** Establishing a secure storage foundation while learning the Terraform resource lifecycle.

---

## 🌍 Day 2 — CloudFront CDN + Private S3 Origin

**Architecture:** CloudFront → Private S3

**Core Concepts:**
- Amazon CloudFront
- Content Delivery Networks
- HTTPS delivery
- CloudFront distributions
- Origin Access Control (OAC)
- Private S3 origins
- Edge locations

**Focus:** Serving content globally without exposing the underlying S3 bucket directly to the internet.

---

## ⚡ Day 3 — Lambda + API Gateway

**Architecture:**

```text
Client
   ↓
API Gateway
   ↓
AWS Lambda
```

**Core Concepts:**
- AWS Lambda
- Python serverless functions
- Amazon API Gateway
- HTTP APIs
- Lambda invocation permissions
- CORS
- Terraform archive packaging

**Focus:** Building a serverless backend without managing traditional servers.

---

## 📢 Day 4 — SNS Event Notifications

**Architecture:**

```text
API Gateway
     ↓
   Lambda
     ↓
    SNS
     ↓
Subscribers
```

**Core Concepts:**
- Amazon SNS
- Publish/Subscribe architecture
- Event-driven systems
- IAM permissions
- Topic ARNs
- Least-privilege access

**Focus:** Decoupling application components using asynchronous notifications.

---

## 🌐 Day 5 — Full-Stack AWS Architecture

**Architecture:**

```text
User
 ↓
CloudFront
 ↓
Private S3 Frontend
 ↓
API Gateway
 ↓
Lambda
 ↓
SNS
```

**Services Combined:**

`S3 + CloudFront + API Gateway + Lambda + SNS`

**Focus:** Combining previously isolated AWS services into a complete cloud-hosted application architecture.

---

## 🗄️ Day 6 — DynamoDB State Management

**Architecture:**

```text
Client
  ↓
API Gateway
  ↓
Lambda
  ↓
DynamoDB
```

**Core Concepts:**
- Amazon DynamoDB
- Serverless persistence
- NoSQL databases
- Atomic counters
- Concurrent updates
- IAM database permissions

**Focus:** Moving from stateless serverless execution to persistent application state.

---

## ⚙️ Day 7 — Terraform Variables & Automation

**Project:** `Day7-VariablesAutomation`

**Core Concepts:**
- Terraform variables
- Configurable infrastructure
- Reusable Terraform code
- Infrastructure parameterization
- Reduced hardcoding
- Automation-friendly deployments

**Focus:** Moving from static Terraform configurations toward reusable Infrastructure as Code.

---

## 📊 Day 8 — CloudWatch Monitoring & Alarms

**Project:** `Day8-CloudWatchAlarms`

**Core Concepts:**
- Amazon CloudWatch
- Metrics
- Monitoring
- CloudWatch alarms
- Operational visibility
- Infrastructure observability

**Focus:** Learning that deploying infrastructure is only part of cloud engineering — production systems must also be monitored.

---

## 🔐 Day 9 — AWS Secrets Management

**Project:** `Day9-SecretsManagement`

**Core Concepts:**
- Secure secret storage
- Credential management
- Avoiding hardcoded secrets
- IAM-controlled secret access
- Secure application configuration

**Focus:** Separating sensitive credentials from application and infrastructure source code.

---

## 🤝 Day 10 — IAM Cross-Account Access

**Project:** `Day10-IAMCrossAccount`

**Core Concepts:**
- AWS IAM
- IAM roles
- Trust relationships
- Cross-account access
- AssumeRole
- Least privilege
- AWS security boundaries

**Focus:** Understanding how AWS identities securely access resources across account boundaries.

---

## 🐘 Day 11 — Amazon RDS PostgreSQL

**Project:** `Day11-RDSPostgres`

**Core Concepts:**
- Amazon RDS
- PostgreSQL
- Managed relational databases
- Database networking
- Security groups
- Database credentials
- Terraform database provisioning

**Focus:** Provisioning persistent relational database infrastructure using Infrastructure as Code.

---

## ⚡ Day 12 — ElastiCache Redis

**Project:** `Day12-ElasticCacheRedis`

**Core Concepts:**
- Amazon ElastiCache
- Redis
- In-memory caching
- Application performance
- Cache architecture
- Network-controlled access

**Focus:** Understanding how caching can reduce database workload and improve application response times.

---

## 🌎 Day 13 — Route 53 Global DNS

**Project:** `Day13-GlobalRoute53`

**Core Concepts:**
- Amazon Route 53
- DNS
- Hosted zones
- DNS records
- Global traffic routing
- Cloud service integration

**Focus:** Understanding how users are routed from human-readable domain names to cloud infrastructure.

---

## 🛡️ Day 14 — AWS WAF Edge Security

**Architecture:**

```text
Internet
   ↓
AWS WAF
   ↓
CloudFront
   ↓
Application / Origin
```

**Core Concepts:**
- AWS WAF
- Web ACLs
- Edge security
- Request filtering
- Web application protection
- CloudFront security integration

**Focus:** Adding a dedicated security layer in front of internet-facing infrastructure.

---

## 📈 Day 15 — EC2 Auto Scaling

**Project:** `Day15-AutoScalingEC2`

**Core Concepts:**
- Amazon EC2
- Launch templates
- Auto Scaling Groups
- Elastic infrastructure
- Instance scaling
- High availability concepts
- Dynamic compute capacity

**Focus:** Moving beyond fixed compute resources toward infrastructure capable of adapting to workload demand.

---

## 🐳 Day 16 — Amazon ECS Fargate

**Project:** `Day16-ECSFargate`

**Core Concepts:**
- Amazon ECS
- AWS Fargate
- Containers
- Task definitions
- Container orchestration
- Serverless container compute
- Infrastructure as Code for containers

**Focus:** Running containerized workloads on AWS without directly managing the underlying EC2 servers.

---

## 📨 Day 17 — SQS + Dead-Letter Queue

**Architecture:**

```text
Producer
   ↓
Amazon SQS
   ↓
Consumer
   │
   ├── Success → Processed
   │
   └── Repeated Failure
              ↓
       Dead-Letter Queue
```

**Core Concepts:**
- Amazon SQS
- Message queues
- Asynchronous processing
- Application decoupling
- Retry handling
- Dead-Letter Queues
- Failure isolation
- Resilient event-driven architecture

**Focus:** Designing distributed applications that can tolerate processing failures without losing problematic messages.

---

# 🧠 Skills Developed So Far

After 17 stages, this repository covers multiple layers of AWS cloud architecture:

| Area | Technologies / Concepts |
|---|---|
| Infrastructure as Code | Terraform |
| Object Storage | Amazon S3 |
| CDN / Edge | Amazon CloudFront |
| Serverless Compute | AWS Lambda |
| APIs | Amazon API Gateway |
| Notifications | Amazon SNS |
| Message Queues | Amazon SQS |
| NoSQL Database | Amazon DynamoDB |
| Relational Database | Amazon RDS / PostgreSQL |
| Caching | Amazon ElastiCache / Redis |
| DNS | Amazon Route 53 |
| Compute | Amazon EC2 |
| Scaling | EC2 Auto Scaling |
| Containers | Amazon ECS / Fargate |
| Monitoring | Amazon CloudWatch |
| Security | IAM, OAC, AWS WAF |
| Secrets | AWS Secrets Management |
| Identity | IAM Cross-Account Access |
| Architecture | Serverless, event-driven and decoupled systems |

---

# 🏗️ Architecture Progression

The marathon intentionally progresses from individual resources toward interconnected cloud systems.

```text
Day 1
S3
 │
 ▼
Day 2
S3 + CloudFront
 │
 ▼
Day 3
API Gateway + Lambda
 │
 ▼
Day 4
Lambda + SNS
 │
 ▼
Day 5
Full-Stack Integration
 │
 ▼
Day 6
Persistent NoSQL State
 │
 ▼
Day 7
Reusable Terraform
 │
 ▼
Day 8
Monitoring & Alarms
 │
 ▼
Day 9
Secrets Security
 │
 ▼
Day 10
Cross-Account IAM
 │
 ▼
Day 11
Relational Databases
 │
 ▼
Day 12
Caching
 │
 ▼
Day 13
Global DNS
 │
 ▼
Day 14
Edge Security
 │
 ▼
Day 15
Auto Scaling Compute
 │
 ▼
Day 16
Serverless Containers
 │
 ▼
Day 17
Reliable Message Queues
```

---

# 🛠️ Global Project Control Blueprint

## Prerequisites

Before deploying any of the projects:

- AWS account
- AWS CLI
- Terraform CLI
- Securely configured AWS credentials
- Basic understanding of AWS IAM permissions
- Git

Check the installed tools:

```bash
aws --version
terraform --version
git --version
```

Verify AWS authentication:

```bash
aws sts get-caller-identity
```

---

# ♻️ Infrastructure Lifecycle

Each project follows the same Infrastructure as Code lifecycle.

### 1. Initialize Terraform

```bash
terraform init
```

Downloads the required Terraform providers and initializes the working directory.

### 2. Format the Terraform configuration

```bash
terraform fmt
```

### 3. Validate the configuration

```bash
terraform validate
```

### 4. Review the deployment

```bash
terraform plan
```

### 5. Deploy the infrastructure

```bash
terraform apply
```

### 6. Verify the AWS resources

Resources are tested using the appropriate AWS service, AWS CLI, browser, API request, or application workflow.

### 7. Destroy the infrastructure

```bash
terraform destroy
```

Destroying resources after each exercise is an intentional part of the project.

It reinforces the concept that infrastructure should be **reproducible and disposable**, while also helping control AWS costs during experimentation.

---

# 🔐 Security Principles Practiced

Security is incorporated throughout the marathon rather than treated as a separate topic.

Key principles include:

- **Principle of Least Privilege**
- Private-by-default infrastructure
- IAM role-based permissions
- Resource-specific IAM policies
- S3 public access blocking
- CloudFront Origin Access Control
- HTTPS-based delivery
- Secure secrets management
- Cross-account trust relationships
- AWS WAF edge protection
- Security group controlled access
- Failure isolation through queues and DLQs

---

# 💰 Cost Awareness

This is an **ephemeral infrastructure practice repository**.

Resources are created for learning and testing and should be destroyed when they are no longer required.

```bash
terraform destroy
```

> **Important:** Some AWS resources may incur charges while running. Always inspect the Terraform plan, understand AWS pricing, verify successful destruction, and check the AWS console for resources that may remain after an exercise.

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
│
├── .gitignore
└── README.md
```

---

# 📈 Current Progress

```text
AWS + Terraform Practice Marathon

█████████████████  17 Architecture Challenges Completed
```

**Current milestone:** Day 17 ✅

The repository has progressed from deploying a single private S3 bucket to working with:

**serverless applications, databases, caching, DNS, monitoring, IAM security, WAF protection, Auto Scaling, containers, queues, and failure-handling architectures.**

---

# 🚀 What This Repository Represents

This repository is not intended to represent a single production application.

Instead, it is a **cloud engineering laboratory** documenting my progression through increasingly complex AWS architectures.

The emphasis is on learning by repeatedly:

> **Building it → breaking/debugging it → understanding it → destroying it → rebuilding something more advanced.**

The long-term objective is to strengthen practical skills in:

**Cloud Engineering • DevOps • Infrastructure as Code • AWS Security • Automation • System Architecture**

---

## 👨‍💻 Author

**Muhammad Jamal Khan**

BS Computer Science  
Cloud / DevOps / Cybersecurity Learner

GitHub: **MuhammadJamal553**

---

## ⭐ Project Status

🟢 **Active — More AWS architecture challenges are being added as the marathon continues.**

If you find this learning journey useful, feel free to explore the individual day folders and follow the repository as the architecture progresses.