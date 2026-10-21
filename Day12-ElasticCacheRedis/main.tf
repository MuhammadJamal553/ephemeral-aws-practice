terraform {
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}

provider "aws" {
    region  = var.aws_region
}

# ========================================================
# 1. NETWORK TIER PIPELINE (VPC & SUBNET NETWORKING ARCHITECTURE)
# ========================================================

resource "aws_vpc" "cache_vpc" {
    cidr_block          = "10.0.0.0/16"
    enable_dns_hostnames= true
    enable_dns_support  = true

    tags = { Name = "${var.project_name}-vpc"}
}

# Caching nodes must live inside private networks spread across different Availability Zones
resource "aws_subnet" "private_cache_az1" {
    vpc_id              = aws_vpc.cache_vpc.id
    cidr_block          = "10.0.1.0/24"
    availability_zone   = "${var.aws_region}a"

    tags = { Name = "${var.project_name}-private-cache-az1"}
}

resource "aws_subnet" "private_cache_az2" {
    vpc_id              = aws_vpc.cache_vpc.id
    cidr_block          = "10.0.2.0/24"
    availability_zone   = "${var.aws_region}b"

    tags = { Name = "${var.project_name}-private-cache-az2"}
}

# Bind the caching subnets into a logical ElastiCache subnet group
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
    name        = "${var.project_name}-subnet-group"
    description = "Isolated Private Subnet Group for in-memory caching nodes."
    subnet_ids  = [aws_subnet.private_cache_az1.id,aws_subnet.private_cache_az2.id]
}

# ========================================================
# 2. FIREWALL SECURITY LAYER (SECURITY GROUP CONFIGURATION)
# ========================================================
resource "aws_security_group" "cache_security_wall" {
    name        = "${var.project_name}-cache-sg"
    description = "Isolated incoming memory caching traffic connections."
    vpc_id      = aws_vpc.cache_vpc.id

    # Inbound Security Rules Layer
    ingress {
        from_port   = 6379 # Standard communication network port for Redis clusters
        to_port     = 6379
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/16"] # Lock down access to internal VPC resources only
    }

    # Outbound Security Rules Layer
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = { Name = "${var.project_name}-cache-security-group"}
}

# ========================================================
# 3. MEMORY ACCELERATION TIERS (AMAZON ELASTICACHE REDIS)
# ========================================================

resource "aws_elasticache_cluster" "redis_cache" {
    cluster_id          = "${var.project_name}-cluster"
    engine              = "redis"
    engine_version      = "7.1" # Modern production-stable standard Redis version
    node_type           = "cache.t4g.micro" # Cost-optimized memory instance tier running Graviton
    num_cache_nodes     = 1 # Standard single node layout for validation practice sprints
    parameter_group_name= "default.redis7"
    port                = 6379


    subnet_group_name   = aws_elasticache_subnet_group.redis_subnet_group.name
    security_group_ids  = [aws_security_group.cache_security_wall.id]

    tags = {
        Environment = "MarathonPractice"
        Tier        = "CacheAccelaration"
    }
}

# ========================================================
# 4. MONITORING OUTPUT METRICS
# ========================================================

output "redis_primary_endpoint" {
    value       = "aws_elasticache_cluster.redis_cache.cache_nodes[0].address"
    description = "The Isolated dynamic Internal connection hostname string for your application caching connection logic."
}