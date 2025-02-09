output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "linux_private_ip" {
  value = aws_instance.linux.private_ip
}

output "nebo_access_key_id" {
  value       = aws_iam_access_key.nebo_access_key.id
  sensitive = true
}

output "nebo_secret_access_key" {
  value       = aws_iam_access_key.nebo_access_key.secret
  sensitive = true
}
