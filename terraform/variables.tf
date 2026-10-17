variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used in resource names/tags"
  type        = string
  default     = "ecommerce"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "instance_type" {
  description = "t3.small (2 GB RAM) is enough for 5 services + MongoDB"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Optional existing EC2 key pair name for SSH. Leave null to skip."
  type        = string
  default     = null
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH. Restrict to your IP (x.x.x.x/32) for anything beyond a demo."
  type        = string
  default     = "0.0.0.0/0"
}

variable "dockerhub_username" {
  description = "Docker Hub username that owns the 5 public images"
  type        = string
}

variable "image_tag" {
  description = "Tag used when pushing the images"
  type        = string
  default     = "v1"
}

variable "jwt_secret" {
  description = "JWT signing secret for the user service"
  type        = string
  default     = "change-me-devops-assignment"
  sensitive   = true
}
