terraform {
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}

provider "aws" {
    region  = var.primary_region
}

data "aws_availability_zones" "available"{
    state   =   "available"
}

# Always fetches the latest Amazon Linux 2023 image
data "aws_ssm_parameter" "al2023" {
    name    = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ========================================================
# 1. THE THREE NEIGHBORHOODS (VPC + subnet + internet gateway)
# ========================================================

resource "aws_vpc" "this" {
    for_each                = var.vpc_cidrs
    cidr_block              = each.value
    enable_dns_hostnames    = true
    enable_dns_support      = true
    tags                    = {Name = "${var.project_name}-vpc-${each.key}"}
}

resource "aws_internet_gateway" "this" {
    for_each    = var.vpc_cidrs
    vpc_id      = aws_vpc.this[each.key].id
    tags        =   {Name   = "${var.project_name}-igw-${each.key}"}
}

# cidrsubnet("10.10.0.0/16", 8, 1) = 10.10.1.0/24
resource "aws_subnet" "this" {
    for_each                = var.vpc_cidrs
    vpc_id                  = aws_vpc.this[each.key].id
    cidr_block              = cidrsubnet(each.value, 8, 1)
    availability_zone       = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true # only so the SSM agent can reach AWS (saves NAT cost)
    tags                    = {Name = "${var.project_name}-subnet-${each.key}"}
}

# ========================================================
# 2. THE ROUNDABOUT (TRANSIT GATEWAY + ATTACHMENTS)
# ========================================================

resource "aws_ec2_transit_gateway" "hub" {
    description                     = "Day 20 Central Hub"
    default_route_table_association = "enable" # attachments USE the default TGW route table
    default_route_table_propagation = "enable" # attachments TEACH their CIDR to it
    tags                            = {Name = "${var.project_name}-tgw"}
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
    for_each            = var.vpc_cidrs
    transit_gateway_id  = aws_ec2_transit_gateway.hub.id
    vpc_id              = aws_vpc.this[each.key].id
    subnet_ids          = [aws_subnet.this[each.key].id]
    tags                = {Name = "${var.project_name}-attach-{each.key}"}
}

# ========================================================
# 3. THE PRIVATE ROAD (VPC PEERING A <-> B)
# ========================================================

resource "aws_vpc_peering_connection" "a_b" {
    count       = var.enable_peering ? 1:0
    vpc_id      = aws_vpc.this["a"].id
    peer_vpc_id = aws_vpc.this["b"].id
    auto_accept = true # same account + same region = auto accepted
    tags        = {Name = "${var.project_name}-peer-a-b"}
}

# ========================================================
# 4. ROAD SIGNS (ROUTE TABLES, each route is its own resource)
# ========================================================

resource "aws_route_table" "this" {
  for_each = var.vpc_cidrs
  vpc_id   = aws_vpc.this[each.key].id
  tags     = { Name = "${var.project_name}-rt-${each.key}" }
}

resource "aws_route_table_association" "this" {
  for_each       = var.vpc_cidrs
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}

# Sign 1: anything unknown goes to the internet
resource "aws_route" "internet" {
  for_each               = var.vpc_cidrs
  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[each.key].id
}

# Sign 2: any 10.x.x.x address goes to the Transit Gateway
resource "aws_route" "to_tgw" {
  for_each               = var.vpc_cidrs
  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.hub.id

  # The TGW route is rejected if the attachment isn't ready yet
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# Sign 3 (more specific, so it WINS): A and B talk via peering
resource "aws_route" "a_to_b" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.this["a"].id
  destination_cidr_block    = var.vpc_cidrs["b"]
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

resource "aws_route" "b_to_a" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.this["b"].id
  destination_cidr_block    = var.vpc_cidrs["a"]
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# ========================================================
# 5. FIREWALL (SECURITY GROUPS)
# ========================================================

resource "aws_security_group" "this" {
  for_each    = var.vpc_cidrs
  name        = "${var.project_name}-sg-${each.key}"
  description = "Allow ping from all private VPCs"
  vpc_id      = aws_vpc.this[each.key].id

  ingress {
    description = "ICMP (ping) from 10.0.0.0/8"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ========================================================
# 6. ACCESS WITHOUT SSH KEYS (IAM ROLE FOR SSM)
# ========================================================

resource "aws_iam_role" "ssm" {
  name = "${var.project_name}-ssm-role"

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
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-ssm-profile"
  role = aws_iam_role.ssm.name
}

# ========================================================
# 7. ONE TEST SERVER PER VPC
# ========================================================

resource "aws_instance" "this" {
  for_each               = var.vpc_cidrs
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.this[each.key].id
  vpc_security_group_ids = [aws_security_group.this[each.key].id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  tags                   = { Name = "${var.project_name}-ec2-${each.key}" }

  # Internet route must exist first, or the SSM agent can't register
  depends_on = [aws_route.internet, aws_route_table_association.this]
}

# ========================================================
# 8. OUTPUTS
# ========================================================

output "tgw_id" {
  value = aws_ec2_transit_gateway.hub.id
}

output "instance_ids" {
  value = { for k, v in aws_instance.this : k => v.id }
}

output "private_ips" {
  value = { for k, v in aws_instance.this : k => v.private_ip }
}