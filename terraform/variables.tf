variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name used to tag and name all resources"
  type        = string
  default     = "iac-demo"
}

variable "environment" {
  description = "Environment name: dev, staging, or prod"
  type        = string
  default     = "dev"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID for ap-south-1"
  type        = string
  default     = "ami-0f58b397bc5c1f2e8"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}