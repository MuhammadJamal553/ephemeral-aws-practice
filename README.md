# Ephemeral AWS Cloud Architecture Practice Marathon

## Project Overview
This repository serves as a progressive, hands-on engineering log documenting a **Build-Destroy-Repeat Marathon**. The core objective of this initiative is to break away from pre-made AI templates and establish genuine muscle memory in designing, provisioning, and securing enterprise-grade cloud systems using **Terraform (Infrastructure as Code)** and **AWS**. 

Every day, a new architectural pattern is developed, deployed live to verify global network operations, and systematically destroyed via the command line to embrace the industry paradigm of disposable infrastructure.

---

## 🏃‍♂️ The Progressive Architectural Journey (Days 1–6)

### 📁 Day 1: Foundational Object Storage
*   **Architecture:** Deployed a highly secure, private **Amazon S3** bucket origin.
*   **Core Concepts:** Blocked all public access control lists (ACLs) and bucket policies to enforce the baseline data security posture.

### 📁 Day 2: Global Content Delivery & Edge Isolation
*   **Architecture:** Integrated **Amazon CloudFront** as a global Content Delivery Network (CDN) ahead of the private S3 bucket.
*   **Core Concepts:** Enforced HTTPS encryption routing and configured **Origin Access Control (OAC)** to lock down the S3 bucket origin, forcing all global traffic to pass exclusively through AWS Edge locations for sub-millisecond delivery.

### 📁 Day 3: Event-Driven Serverless Compute Pipeline
*   **Architecture:** Provisioned an **AWS Lambda** backend execution tier (Python 3.12) triggered by an **Amazon API Gateway (HTTP API)** public front door.
*   **Core Concepts:** Automated localized code deployment packaging via Terraform archive compression and resolved cross-origin communication rules (CORS).

### 📁 Day 4: Decoupled Asynchronous Alerting Bus
*   **Architecture:** Extended the serverless pipeline by introducing **Amazon SNS (Simple Notification Service)** into the processing logic.
*   **Core Concepts:** Decoupled application integration using a Pub/Sub alerting framework to eliminate compute bottlenecks. Practiced the **Principle of Least Privilege** by restricting the Lambda execution IAM policy to a specific target topic ARN.

### 📁 Day 5: Full-Stack Converged Enterprise Web App
*   **Architecture:** Unified all previous layers into a single, cohesive infrastructure stack (S3 + CloudFront + API Gateway + Lambda + SNS).
*   **Core Concepts:** Programmed an interactive frontend page that communicates asynchronously with a decoupled backend cloud architecture to dispatch immediate administrative tracking warnings upon visitor arrivals.

### 📁 Day 6: Managed NoSQL State Management
*   **Architecture:** Transitioned the serverless landscape from stateless routing into a stateful, persistent ecosystem using **Amazon DynamoDB**.
*   **Core Concepts:** Leveraged native database **Atomic Counters** (`ADD #count_val :incr`) to handle race conditions during high-concurrency event loops, tracking session metrics accurately with zero server management overhead.

---

## 🛠️ Global Project Control Blueprint

### Prerequisites
*   AWS CLI pre-configured with secure IAM access credentials.
*   Terraform CLI installed locally.

### Infrastructure Lifecycle Commands
Every module follows a strict lifecycle loop to guarantee cost optimization and code validation:
```bash
# 1. Initialize the target folder directory and download providers
terraform init

# 2. Compile an execution plan to verify architectural dependencies
terraform plan

# 3. Deploy the live resources into the cloud account
terraform apply

# 4. Tear down all live components instantly to secure credit limits
terraform destroy
```
