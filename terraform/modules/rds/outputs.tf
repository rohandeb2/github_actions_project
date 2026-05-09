output "db_endpoint" { value = aws_db_instance.main.endpoint; sensitive = true }
output "db_name"     { value = aws_db_instance.main.db_name }
output "db_username" { value = aws_db_instance.main.username; sensitive = true }
