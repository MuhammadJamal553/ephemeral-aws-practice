terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.primary_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ========================================================
# 1. THE NEIGHBORHOOD (VPC + public subnet so SSM and dnf work, no NAT)
# ========================================================

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # REQUIRED for private hosted zones
  enable_dns_hostnames = true # REQUIRED for private hosted zones
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project_name}-rt" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ========================================================
# 2. THE PRIVATE PHONE BOOK (PRIVATE HOSTED ZONE)
# ========================================================

resource "aws_route53_zone" "private" {
  name          = var.zone_name
  force_destroy = true # lets destroy delete the records first

  # This vpc block is what makes the zone PRIVATE
  vpc {
    vpc_id = aws_vpc.this.id
  }

  tags = { Name = "${var.project_name}-zone" }
}

# Two records, SAME name, different weights = weighted routing
resource "aws_route53_record" "app_blue" {
  zone_id        = aws_route53_zone.private.zone_id
  name           = "app.${var.zone_name}"
  type           = "A"
  ttl            = 1 # tiny TTL so every query sees the new weights
  records        = ["10.60.1.101"]
  set_identifier = "blue"

  weighted_routing_policy {
    weight = var.weight_blue
  }
}

resource "aws_route53_record" "app_green" {
  zone_id        = aws_route53_zone.private.zone_id
  name           = "app.${var.zone_name}"
  type           = "A"
  ttl            = 1
  records        = ["10.60.1.102"]
  set_identifier = "green"

  weighted_routing_policy {
    weight = var.weight_green
  }
}

# A plain "simple" record for comparison
resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.${var.zone_name}"
  type    = "A"
  ttl     = 60
  records = ["10.60.1.50"]
}

# ========================================================
# 3. THE TEST SERVER (SSM access, no SSH keys)
# ========================================================

resource "aws_iam_role" "server" {
  name = "${var.project_name}-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "server" {
  name = "${var.project_name}-server-profile"
  role = aws_iam_role.server.name
}

resource "aws_security_group" "server" {
  name        = "${var.project_name}-server-sg"
  description = "No inbound. Outbound only."
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "server" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.server.id]
  iam_instance_profile   = aws_iam_instance_profile.server.name
  tags                   = { Name = "${var.project_name}-server" }

  depends_on = [aws_route.internet, aws_route_table_association.public]
}

# ========================================================
# 4. OUTPUTS
# ========================================================

output "instance_id" {
  value = aws_instance.server.id
}

output "zone_id" {
  value = aws_route53_zone.private.zone_id
}