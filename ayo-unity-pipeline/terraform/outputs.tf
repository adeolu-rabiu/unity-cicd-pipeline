output "jenkins_public_ip" {
  description = "Public IP address of the Jenkins server"
  value       = aws_instance.jenkins_server.public_ip
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${aws_instance.jenkins_server.public_ip}:3000"
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${aws_instance.jenkins_server.public_ip}:9090"
}

output "kibana_url" {
  description = "URL to access Kibana"
  value       = "http://${aws_instance.jenkins_server.public_ip}:5601"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Unity builds"
  value       = aws_s3_bucket.unity_builds.bucket
}

output "ssh_command" {
  description = "SSH command to connect to the Jenkins server"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip}"
}
