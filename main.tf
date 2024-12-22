# Provider Configuration
provider "aws" {
  region = "us-east-1"  # Change to your preferred region
}

# S3 Bucket for storing data
resource "aws_s3_bucket" "data_bucket" {
  bucket = "my-project-data-bucket"
  acl    = "private"
}

# RDS Instance for PostgreSQL
resource "aws_db_instance" "app_db" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "13.4"
  instance_class       = "db.t3.micro"
  name                 = "myappdb"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.postgres13"
  skip_final_snapshot  = true
  multi_az             = false
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.app_db_subnet.id
}

# DB Subnet Group for RDS
resource "aws_db_subnet_group" "app_db_subnet" {
  name       = "myapp-db-subnet"
  subnet_ids = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]  # Replace with actual subnet IDs

  tags = {
    Name = "MyAppDBSubnetGroup"
  }
}

# Glue Catalog Database
resource "aws_glue_catalog_database" "app_database" {
  name = "my_app_database"
}

# Glue Catalog Table
resource "aws_glue_catalog_table" "app_table" {
  name          = "my_app_table"
  database_name = aws_glue_catalog_database.app_database.name

  table_type = "EXTERNAL_TABLE"

  storage_descriptor {
    columns {
      name = "data_column"
      type = "string"
    }

    location      = "s3://my-project-data-bucket/data/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
  }
}

# ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name = "my-app-repo"
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

# Lambda Function using Docker Image from ECR
resource "aws_lambda_function" "app_lambda" {
  function_name = "my-app-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  image_uri     = "${aws_ecr_repository.app_repo.repository_url}:latest"

  memory_size = 128
  timeout     = 60
}

# Lambda Permission to Allow S3 to Trigger Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  principal     = "s3.amazonaws.com"
  function_name = aws_lambda_function.app_lambda.function_name
  source_arn    = aws_s3_bucket.data_bucket.arn
}
