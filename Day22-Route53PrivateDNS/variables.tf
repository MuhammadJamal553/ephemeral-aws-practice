variable "primary_region" {
    type    = string
    default = "us-east-1"
}

variable "project_name" {
    type    = string
    default = "jamal-khan-marathon-day22"
}

variable "vpc_cidr" {
    type    = string
    default = "10.60.0.0/16"
}

variable "zone_name" {
    type    = string
    default = "marathon.internal"
}

# Traffic split. Set weight_blue to 0 to send everyone to green.
variable "weight_blue" {
    type    = number
    default = 80
}

variable "weight_green" {
    type    = number
    default = 20
}

