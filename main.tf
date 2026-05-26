################################################################################
# order-pipeline — Phase 2: SQS + real business logic
################################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── Zip Lambda source automatically ──────────────────────────────────────────
data "archive_file" "order_intake" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/order_intake"
  output_path = "${path.module}/builds/order_intake.zip"
}

data "archive_file" "order_processor" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/order_processor"
  output_path = "${path.module}/builds/order_processor.zip"
}

# ── DynamoDB: orders + inventory tables ──────────────────────────────────────
module "dynamodb" {
  source      = "./modules/dynamodb"
  table_name  = "${var.project_name}-orders-${var.environment}"
  environment = var.environment
}

# ── SQS Queue + Dead-Letter Queue ────────────────────────────────────────────
module "sqs" {
  source      = "./modules/sqs"
  queue_name  = "${var.project_name}-orders-${var.environment}"
  environment = var.environment
}

# ── Lambda: order_intake ──────────────────────────────────────────────────────
module "lambda" {
  source              = "./modules/lambda"
  function_name       = "${var.project_name}-order-intake-${var.environment}"
  filename            = data.archive_file.order_intake.output_path
  source_hash         = data.archive_file.order_intake.output_base64sha256
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  sqs_queue_url       = module.sqs.queue_url
  sqs_queue_arn       = module.sqs.queue_arn
  enable_sqs          = true
  environment         = var.environment
  project_name        = var.project_name
}

# ── Lambda: order_processor ───────────────────────────────────────────────────
module "lambda_processor" {
  source               = "./modules/lambda_processor"
  function_name        = "${var.project_name}-order-processor-${var.environment}"
  filename             = data.archive_file.order_processor.output_path
  source_hash          = data.archive_file.order_processor.output_base64sha256
  dynamodb_table_name  = module.dynamodb.table_name
  dynamodb_table_arn   = module.dynamodb.table_arn
  inventory_table_name = module.dynamodb.inventory_table_name
  inventory_table_arn  = module.dynamodb.inventory_table_arn
  sqs_queue_arn        = module.sqs.queue_arn
  dlq_arn              = module.sqs.dlq_arn
  environment          = var.environment
}

# ── API Gateway ───────────────────────────────────────────────────────────────
module "api_gateway" {
  source            = "./modules/api_gateway"
  api_name          = "${var.project_name}-api-${var.environment}"
  lambda_invoke_arn = module.lambda.invoke_arn
  lambda_arn        = module.lambda.function_arn
  environment       = var.environment
}

# ── Application Load Balancer ─────────────────────────────────────────────────
module "alb" {
  source        = "./modules/alb"
  name          = "${var.project_name}-${var.environment}"
  instance_port = 8080
  environment   = var.environment
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────
module "asg" {
  source           = "./modules/asg"
  name             = "${var.project_name}-${var.environment}"
  instance_type    = "t3.micro"
  instance_port    = 8080
  min_size         = 2
  max_size         = 4
  desired_size     = 2
  target_group_arn = module.alb.target_group_arn
  alb_sg_id        = module.alb.alb_sg_id
  vpc_id           = module.alb.vpc_id
  subnet_ids       = module.alb.subnet_ids
  environment      = var.environment
}
