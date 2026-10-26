terraform{
    required_providers{
        aws ={
            source  = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}

provider "aws" {
    region  = var.aws_region
}


# ========================================================
# 1. NETWORK TIER PIPELINE (HIGHLY AVAILABLE MULTI-AZ VPC)
# ========================================================

resource "aws_vpc" "main_vpc" {
    cidr_block          = "10.0.0.0/16"
    enable_dns_hostnames= true
    enable_dns_support  = true
    tags                = {Name ="${var.project_name}-vpc"}
}

resource "aws_internet_gateway" "igw" {
    vpc_id  = aws_vpc.main_vpc.id
    tags    = {Name = "${var.project_name}-igw"}
}

# Public Subnets across two different datacenters for our Load Balancer
resource "aws_subnet" "public_az1" {
    vpc_id                  = aws_vpc.main_vpc.id
    cidr_block              = "10.0.1.0/24"
    availability_zone       = "${var.aws_region}a"
    map_public_ip_on_launch = true
    tags                    = {Name = "${var.project_name}-public-az1"}
}

resource "aws_subnet" "public_az2" {
    vpc_id                  = aws_vpc.main_vpc.id
    cidr_block              = "10.0.2.0/24"
    availability_zone       = "${var.aws_region}b"
    map_public_ip_on_launch = true
    tags                    = {Name = "${var.project_name}-public-az2"}
}

resource "aws_route_table" "public_rt" {
    vpc_id  = aws_vpc.main_vpc.id
    route {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = aws_internet_gateway.igw.id
    }
    tags    = {Name = "${var.aws_region}-public-rt"}
}

resource "aws_route_table_association" "az1" {
    subnet_id       = aws_subnet.public_az1.id
    route_table_id  = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "az2" {
    subnet_id       = aws_subnet.public_az2.id
    route_table_id  = aws_route_table.public_rt.id
}

# ========================================================
# 2. FIREWALL SECURITY LAYER (DECOUPLED SECURITY GROUPS)
# ========================================================

# Load Balancer Security Wall (Allows public web traffic)
resource "aws_security_group" "alb_sg" {
    name        = "${var.project_name}-alb-sg"
    vpc_id      = aws_vpc.main_vpc.id
    description = "Allow Incoming HTTP Traffic to the Load Balancer"


    ingress{
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress{
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# EC2 Instance Security Wall (Allows traffic ONLY from the Load Balancer)
resource "aws_security_group" "instance_sg" {
    name        = "${var.project_name}-instance-sg"
    vpc_id      = aws_vpc.main_vpc.id
    description = "Allow Traffic Strictly originating from the ALB pricipal"


    ingress{
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        security_groups = [aws_security_group.alb_sg.id] # Strict architectural mapping!
    }

    egress{
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# ========================================================
# 3. ROUTING TIERS (APPLICATION LOAD BALANCER COMPILATION)
# ========================================================

resource "aws_lb" "external_alb" {
    name                = "${var.project_name}-alb"
    internal            = false
    load_balancer_type  = "application"
    security_groups     = [aws_security_group.alb_sg.id]
    subnets             = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
}

resource "aws_lb_target_group" "alb_tg" {
    name        = "${var.project_name}-tg"
    port        = 80
    protocol    = "HTTP"
    vpc_id      = aws_vpc.main_vpc.id

    health_check {
        path                = "/"
        interval            = 15
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_listener" "http" {
    load_balancer_arn   = aws_lb.external_alb.arn
    port                = "80"
    protocol            = "HTTP"

    default_action  {
        type                = "forward"
        target_group_arn    = aws_lb_target_group.alb_tg.arn
    }
}

# ========================================================
# 4. ELASTIC COMPUTE FLOTILLA (LAUNCH TEMPLATE & AUTO SCALING)
# ========================================================

# Automatically fetch the latest Amazon Linux 2023 AMI image ID natively
data "aws_ami" "amazon_linux" {
    most_recent = true
    owners      = ["amazon"]
    filter {
        name    = "name"
        values  = ["al2023-ami-2023*-x86_64"]
    }
}

resource "aws_launch_template" "ec2_template" {
    name_prefix     = "${var.project_name}-template-"
    image_id        = data.aws_ami.amazon_linux.id
    instance_type   = "t3.micro" # Fits completely inside the standard free tier limits

    network_interfaces {
        associate_public_ip_address = true
        security_groups             = [aws_security_group.instance_sg.id]
    }

    # User Data Script: Runs automatically at machine boot to mount an Apache server cluster
    user_data   = base64encode (<<-EOF
                #!/bin/bash
                sudo dnf update -y
                sudo install -y httpd
                sudo systemctl start httpd
                sudo systemctl enable httpd
                echo "<h1>Elastic Fleet Test Success! Hello from Host: $(hostname -f)</h1>" > /var/www/html/index.html
                EOF
    ) 
}

resource "aws_autoscaling_group" "asg" {
    name_prefix         = "${var.project_name}-asg"
    vpc_zone_identifier = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
    target_group_arns   = [aws_lb_target_group.alb_tg.arn]


    desired_capacity= 2 # Launch 2 instances across separate datacenters immediately
    max_size        = 3
    min_size        = 1

    launch_template {
        id      = aws_launch_template.ec2_template.id
        version = "$Latest"
    }

    tag {
        key                 = "Name"
        value               = "${var.project_name}-worker"
        propagate_at_launch = true
    }
}


# ========================================================
# 5. MONITORING SYSTEM METRICS OUTPUTS
# ========================================================

output "load_balancer_dns_name" {
    value       = "http://${aws_lb.external_alb.dns_name}"
    description = "The Publblic Access Entry Point URL String Routed to your Elastic EC2 Server Fleet"
}