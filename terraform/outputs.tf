output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.Application_Server.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.Application_Server.public_dns
}

output "s3_bucket_name" {
  description = "Name of the app S3 bucket"
  value       = aws_s3_bucket.app_bucket.bucket
}

output "vpc_id" {
  description = "ID of the VPC created"
  value       = aws_vpc.main.id
}