resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-${var.environment}-db"
  engine            = "postgres"
  engine_version    = "15.12"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  skip_final_snapshot     = var.environment != "prod"
  deletion_protection     = var.environment == "prod"
  multi_az                = var.environment == "prod"

  tags = {
    Name        = "${var.project_name}-rds"
    Environment = var.environment
  }
}