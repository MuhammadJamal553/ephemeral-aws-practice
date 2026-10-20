terraform {
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}

provider "aws" {
    region = var.aws_region
}

# ========================================================
# 1. NETWORK TIER PIPELINE (VPC & SUBNET NETWORKING ARCHITECTURE)
# ========================================================

# Provision an isolated cloud corporate network envelope
resource "aws_vpc" "db_vpc" {
    cidr_block          = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support  = true

    tags = { Name = "${var.project_name}-vpc"}
}

# Database engines require at least two subnets across distinct Availability Zones to run Multi-AZ!
resource "aws_subnet" "private_data_az1" {
    vpc_id              = aws_vpc.db_vpc.id
    cidr_block          = "10.0.1.0/24"
    availability_zone   = "${var.aws_region}a"

    tags = {Name = "${var.project_name}-private-data-az1"}
}

resource "aws_subnet" "private_data_az2" {
    vpc_id              = aws_vpc.db_vpc.id
    cidr_block          = "10.0.2.0/24"
    availability_zone   = "${var.aws_region}b"

    tags = {Name = "${var.project_name}-private-data-az2"}
}


# Bind both private subnets together into a logical database subnet network assignment group
resource "aws_db_subnet_group" "rds_subnet_group" {
    name        = "${var.project_name}-subnet-group"
    description = "Isolated privatenetwork subnets for production database engines"
    subnet_ids  = [aws_subnet.private_data_az1.id, aws_subnet.private_data_az2.id]

    tags = {Name = "${var.project_name}-db-subnet-group"}
}

# ========================================================
# 2. FIREWALL SECURITY LAYER (SECURITY GROUP PERMISSIONS CONTROL)
# ========================================================

resource "aws_security_group" "db_security_wall" {
    name        = "${var.project_name}-db-sg"
    description = "Isolated Incoming Relational database traffic connection"
    vpc_id      = aws_vpc.db_vpc.id

    # Inbound Security Rules Layer
    ingress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks  = ["10.0.0.0/16"] # Lock access so only computing objects inside our private VPC network can query the cluster
    }

    # Outbound Security Rules Layer
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = -1
        cidr_blocks  = ["0.0.0.0/0"]
    }
    tags = {Name = "${var.project_name}-db-security-group"}
}

# ========================================================
# 3. HIGH AVAILABILITY DATA TIERS (AMAZON RDS INSTANCE DEPLOYMENT)
# ========================================================

resource "aws_db_instance" "postgres_db" {
    identifier              = "${var.project_name}-instance"
    allocated_storage       = 20 # Minimum baseline solid-state drive footprint capacity
    max_allocated_storage   = 100 # Exam concept: Storage Autoscaling enabled to prevent system disk saturation crashes
    engine                  = "postgres"
    engine_version          = "16.3"
    instance_class          = "db.t4g.micro" # Cost-optimized Graviton instance type tier

    db_name     = "jamal_portfolio_db"
    username    = "jamal_admin"
    password    = var.db_password

    db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
    vpc_security_group_ids  = [aws_security_group.db_security_wall.id]
    skip_final_snapshot     = true

    # ==========================================
    # CRUCIAL EXAM PARAMETER CONFIGURATIONS
    # ==========================================

    multi_az            = true # Forces synchronous standby failover secondary cluster instance replication across datacenters!
    publicly_accessible = false # Blocks all public IP assignment routing paths to insulate data securely from internet loops

    tags = {
        Environment = "MarathonPractice"
        Tier        = "DataStore"
    }
}

# ========================================================
# 4. MONITORING OUTPUT METRICS
# ========================================================

output "db_endpoint_address" {
    value       = aws_db_instance.postgres_db.address
    description = "The Isolated Private endpoint database hostname string."
}

output "db_failover_status" {
    value       = aws_db_instance.postgres_db.multi_az
    description = "Confirms if high-availability multi-datacenter cross-replication redundancy is running"
}
