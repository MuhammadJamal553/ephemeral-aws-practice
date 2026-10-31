variable "primary_region" {
    type    = string
    default = "us-east-1"
}

variable "project_name" {
    type    = string
    default = "jamal-khan-marathon-day20"
}

# One entry per VPC. Add or remove entries and Terraform adapts.
variable "vpc_cidrs" {
    type    = map(string)
    default = {
        a   = "10.10.0.0/16"
        b   = "10.20.0.0/16"
        c   = "10.30.0.0/16"
    }
}

variable "enable_peering" {
    type    = bool
    default = true
}