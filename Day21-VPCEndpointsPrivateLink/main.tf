terraform {
    required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~>5.0"
        }
    }
}

provider "aws" {
    region = var.primary_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
    state   = "available"
}

data "aws_ssm_parameter" "al2023" {
    name    = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ========================================================
# 1. THE PRIVATE NEIGHBORHOOD (no internet gateway on purpose!)
# ========================================================

resource "aws_vpc" "this" {
    cidr_block              = var.vpc_cidr
    enable_dns_hostnames    = true # required for interface endpoint private DNS
    enable_dns_support      = true 
    tags                    = {Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "private" {
    vpc_id                  = aws_vpc.this.id
    cidr_block              = cidrsubnet (var.vpc_cidr, 8 , 1)
    availability_zone       = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = false # no public IP at all
    tags                    = {Name = "${var.project_name}-private-subnet" }
}

resource "aws_route_table" "private" {
    vpc_id  = aws_vpc.this.id
    tags    = {Name = "${var.project_name}-private-rt" }
    # No 0.0.0.0/0 route exists here. The only extra route is added by the S3 gateway endpoint.
}

resource "aws_route_table_association" "private" {
    subnet_id       = aws_subnet.private.id
    route_table_id  = aws_route_table.private.id
}

# ========================================================
# 2. THE PRIVATE S3 BUCKET WITH ONE TEST FILE
# ========================================================

resource "aws_s3_bucket" "data" {
    bucket          = "${var.project_name}-data-${data.aws_caller_identity.current.id}"
    force_destroy   = true # lets terraform destroy delete the test file

}

resource "aws_s3_bucket_public_access_block" "data" {
    bucket                  = aws_s3_bucket.data.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_object" "hello" {
    bucket      = aws_s3_bucket.data.id
    key         = "hello.txt"
    content     = "Hellow From s3 through a private vpc endpoint"
    content_type= "text/plain"
}

# ========================================================
# 3. GATEWAY ENDPOINT FOR S3 (free, works through the route table)
# ========================================================

resource "aws_vpc_endpoint" "s3" {
    vpc_id              = aws_vpc.this.id
    service_name        = "com.amazonaws.${var.primary_region}.s3"
    vpc_endpoint_type   =  "Gateway"
    route_table_ids     = [aws_route_table.private.id]
    tags                = {Name = "${var.project_name}-s3-gateway-endpoint"}
}

# ========================================================
# 4. INTERFACE ENDPOINTS FOR SSM (private network cards, hourly cost)
# ========================================================

resource "aws_security_group" "endpoints" {
    name        = "${var.project_name}-endpoints-sg"
    description = "Allow HTTPS From Inside the VPC to the interface endpoints."
    vpc_id      = aws_vpc.this.id

    ingress {
        description = "HTTPS From VPC"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = [var.vpc_cidr]
    }
}

resource "aws_vpc_endpoint" "ssm" {
    for_each            = toset(["ssm", "ssmmessages", "ec2messages"])
    vpc_id              = aws_vpc.this.id
    service_name        = "com.amazonaws.${var.primary_region }.${each.key}"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = [aws_subnet.private.id]
    security_group_ids  = [aws_security_group.endpoints.id]
    private_dns_enabled = true # makes ssm.us-east-1.amazonaws.com resolve to a private IP
    tags                = { Name    = "${var.project_name}-${each.key}-endpoint" }


}


# ========================================================
# 5. OPTIONAL LOCK: only the endpoint may read objects
# ========================================================
resource "aws_s3_bucket_policy" "lock" {
    count   = var.lock_bucket_to_endpoint ? 1 : 0
    bucket  = aws_s3_bucket.data.id


    policy  = jsonencode ({
        Version     = "2012-10-17"
        Statement   = [{
            Sid         = "DenyReadsOutsideEndpoints"
            Effect      = "Deny"
            Principal   = "*"
            Action      = "s3:GetObject"
            Resource    = "${aws_s3_bucket.data.arn}/*"
            Condition   = {
                StringNotEquals = { "aws:SourceVpce" = aws_vpc_endpoint.s3.id }
            }
        }]
    })

    depends_on  = [aws_s3_bucket_public_access_block.data]
}

# ========================================================
# 6. THE TEST SERVER (SSM access + read-only S3)
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

resource "aws_iam_role_policy" "s3_read" {
  name = "read-day21-bucket"
  role = aws_iam_role.server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.data.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
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
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.server.id]
  iam_instance_profile   = aws_iam_instance_profile.server.name
  tags                   = { Name = "${var.project_name}-private-server" }

  # The SSM endpoints must exist first, or the agent cannot register
  depends_on = [aws_vpc_endpoint.ssm, aws_route_table_association.private]
}

# ========================================================
# 7. OUTPUTS
# ========================================================

output "instance_id" {
  value = aws_instance.server.id
}

output "bucket_name" {
  value = aws_s3_bucket.data.id
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}