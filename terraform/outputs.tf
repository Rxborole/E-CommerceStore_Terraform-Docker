output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.app.public_dns
}

output "application_url" {
  description = "Open this in a browser (allow ~3-5 minutes after apply for user-data to finish)"
  value       = "http://${aws_instance.app.public_ip}"
}

output "frontend_live_check" {
  value = "http://${aws_instance.app.public_ip}/live"
}

output "backend_status_urls" {
  description = "Each returns '<name> Service Running' when the container is up"
  value = {
    user    = "http://${aws_instance.app.public_ip}/status/user"
    product = "http://${aws_instance.app.public_ip}/status/product"
    cart    = "http://${aws_instance.app.public_ip}/status/cart"
    order   = "http://${aws_instance.app.public_ip}/status/order"
  }
}

output "ssh_command" {
  description = "Only useful if key_name was set"
  value       = var.key_name == null ? "No key pair configured" : "ssh -i <path-to-${var.key_name}.pem> ubuntu@${aws_instance.app.public_ip}"
}
