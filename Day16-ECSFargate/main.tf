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
# 1. NETWORK TIER PIPELINE (VPC FOR MICROSERVICE ARCHITECTURE)
# ========================================================

resource "aws_vpc" "ecs_vpc" {
    cidr_block          = "10.0.0.0/16"
    enable_dns_hostnames= true
    enable_dns_support  = true
    tags                = {Name = "${var.project_name}-vpc"}
}

resource "aws_internet_gateway" "igw" {
    vpc_id  = aws_vpc.ecs_vpc.id
    tags    = {Name = "${var.project_name}-igw"}
}

resource "aws_subnet" "public_subnet_1" {
    vpc_id                  = aws_vpc.ecs_vpc.id
    cidr_block              = "10.0.1.0/24"
    availability_zone       = "${var.aws_region}a"
    map_public_ip_on_launch = true
    tags                    = {Name = "{var.project_name}-public-1"}
}

resource "aws_subnet" "public_subnet_2" {
    vpc_id                  = aws_vpc.ecs_vpc.id
    cidr_block              = "10.0.2.0/24"
    availability_zone       = "${var.aws_region}b"
    map_public_ip_on_launch = true
    tags                    = {Name = "{var.project_name}-public-2"}
}

resource "aws_route_table" "public_rt" {
    vpc_id  = aws_vpc.ecs_vpc.id
    route   {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = aws_internet_gateway.igw.id
    }
    tags    = {Name = "${var.aws_region}-rt"}
}

resource "aws_route_table_association" "a1" {
    subnet_id       = aws_subnet.public_subnet_1.id
    route_table_id  = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "a2" {
    subnet_id       = aws_subnet.public_subnet_2.id
    route_table_id  = aws_route_table.public_rt.id
}

# ========================================================
# 2. FIREWALL SECURITY LAYER (SECURITY GROUP CONFIGURATION)
# ========================================================

resource "aws_security_group" "ecs_task_sg" {
    name        = "${var.project_name}-task-sg"
    vpc_id      = aws_vpc.ecs_vpc.id
    description = "Allow Incoming Web Connections directly to container Tasks"

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# ========================================================
# 3. CONTAINER MANAGEMENT TIERS (AMAZON ECS CLUSTER & TASK)
# ========================================================

# Create the logical ECS Cluster grouping
resource "aws_ecs_cluster" "main_cluster" {
    name    = "${var.project_name}-cluster"
}

# Build the IAM Execution Identity Role required for Fargate to fetch container logs/images
resource "aws_iam_role" "ecs_execution_role" {
    name    = "${var.project_name}-ecs-execution-role"


    assume_role_policy  = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Action      = "sts:AssumeRole"
            Effect      = "Allow"
            Principal   = {Service = "ecs-tasks.amazonaws.com"}
        }]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
    role        = aws_iam_role.ecs_execution_role.name
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Define the Fargate Serverless Task Blueprint Specifications
resource "aws_ecs_task_definition" "web_task" {
    family                  = "${var.project_name}-web-task"
    network_mode            = "awsvpc" # Fargate requires awsvpc network allocation mapping!
    requires_compatibilities= ["FARGATE"]
    cpu                     = "256" # 0.25 vCPUy
    memory                  = "512" # 512 MB memory baseline allocation
    execution_role_arn      = aws_iam_role.ecs_execution_role.arn


    #Docker image initialization metadata
    container_definitions = jsonencode ([{
        name        = "static-web-server"
        image       = "nginxdemos/hello:latest" # Public demo image that outputs hosting metadata details
        essential   = true
        portMappings = [{
            containerPort   = 80
            hostPort        = 80
        }]
    }])
    
}

# Spin up the ECS Service to launch and continuously maintain 1 Fargate task container instance
resource "aws_ecs_service" "web_service" {
    name            = "${var.project_name}-service"
    cluster         = aws_ecs_cluster.main_cluster.id
    task_definition = aws_ecs_task_definition.web_task.arn
    desired_count   = 1
    launch_type     = "FARGATE" # Enforces serverless compute isolation architecture

    network_configuration {
        subnets             = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
        security_groups     = [aws_security_group.ecs_task_sg.id]
        assign_public_ip    = true
    }
}

# ========================================================
# 4. DATA METRICS MONITORING VERIFICATION OUTLINES
# ========================================================

output "ecs_service_name" {
    value       = aws_ecs_service.web_service.name
    description = "The Active Microservice instance name string"
}