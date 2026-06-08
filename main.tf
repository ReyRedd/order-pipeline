################################################################################
# order-pipeline - Phase 4: Cognito + Step Functions + GitHub Actions CI/CD
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

# ── Zip all Lambda functions automatically ────────────────────────────────────
data "archive_file" "order_intake" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/order_intake"
  output_path = "${path.module}/builds/order_intake.zip"
}
data "archive_file" "orchestrator" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/orchestrator"
  output_path = "${path.module}/builds/orchestrator.zip"
}
data "archive_file" "validate_order" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/states/validate_order"
  output_path = "${path.module}/builds/validate_order.zip"
}
data "archive_file" "check_inventory" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/states/check_inventory"
  output_path = "${path.module}/builds/check_inventory.zip"
}
data "archive_file" "calculate_pricing" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/states/calculate_pricing"
  output_path = "${path.module}/builds/calculate_pricing.zip"
}
data "archive_file" "fulfill_order" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/states/fulfill_order"
  output_path = "${path.module}/builds/fulfill_order.zip"
}
data "archive_file" "handle_failure" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/states/handle_failure"
  output_path = "${path.module}/builds/handle_failure.zip"
}

# ── DynamoDB ──────────────────────────────────────────────────────────────────
module "dynamodb" {
  source      = "./modules/dynamodb"
  table_name  = "${var.project_name}-orders-${var.environment}"
  environment = var.environment
}

# ── SQS + DLQ ─────────────────────────────────────────────────────────────────
module "sqs" {
  source      = "./modules/sqs"
  queue_name  = "${var.project_name}-orders-${var.environment}"
  environment = var.environment
}

# ── SNS Topics ────────────────────────────────────────────────────────────────
module "sns" {
  source             = "./modules/sns"
  name               = "${var.project_name}-${var.environment}"
  notification_email = var.notification_email
  environment        = var.environment
}

# ── Cognito User Pool ─────────────────────────────────────────────────────────
module "cognito" {
  source      = "./modules/cognito"
  name        = "${var.project_name}-${var.environment}"
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

# ── Step Functions state Lambdas + orchestrator ───────────────────────────────
# Created before Step Functions so their ARNs are available for the state machine
module "lambda_states" {
  source                 = "./modules/lambda_states"
  name                   = "${var.project_name}-${var.environment}"
  sqs_queue_arn          = module.sqs.queue_arn
  dlq_arn                = module.sqs.dlq_arn
  state_machine_arn      = module.step_functions.state_machine_arn
  orders_table_name      = module.dynamodb.table_name
  orders_table_arn       = module.dynamodb.table_arn
  inventory_table_name   = module.dynamodb.inventory_table_name
  inventory_table_arn    = module.dynamodb.inventory_table_arn
  sns_topic_arn          = module.sns.order_notifications_arn
  orchestrator_zip       = data.archive_file.orchestrator.output_path
  orchestrator_hash      = data.archive_file.orchestrator.output_base64sha256
  validate_zip           = data.archive_file.validate_order.output_path
  validate_hash          = data.archive_file.validate_order.output_base64sha256
  check_inventory_zip    = data.archive_file.check_inventory.output_path
  check_inventory_hash   = data.archive_file.check_inventory.output_base64sha256
  calculate_pricing_zip  = data.archive_file.calculate_pricing.output_path
  calculate_pricing_hash = data.archive_file.calculate_pricing.output_base64sha256
  fulfill_order_zip      = data.archive_file.fulfill_order.output_path
  fulfill_order_hash     = data.archive_file.fulfill_order.output_base64sha256
  handle_failure_zip     = data.archive_file.handle_failure.output_path
  handle_failure_hash    = data.archive_file.handle_failure.output_base64sha256
  environment            = var.environment
}

# ── Step Functions Express state machine ──────────────────────────────────────
module "step_functions" {
  source                       = "./modules/step_functions"
  name                         = "${var.project_name}-${var.environment}"
  validate_lambda_arn          = module.lambda_states.validate_arn
  check_inventory_lambda_arn   = module.lambda_states.check_inventory_arn
  calculate_pricing_lambda_arn = module.lambda_states.calculate_pricing_arn
  fulfill_order_lambda_arn     = module.lambda_states.fulfill_order_arn
  handle_failure_lambda_arn    = module.lambda_states.handle_failure_arn
  environment                  = var.environment
}

# ── API Gateway + Cognito authorizer ──────────────────────────────────────────
module "api_gateway" {
  source                = "./modules/api_gateway"
  api_name              = "${var.project_name}-api-${var.environment}"
  lambda_invoke_arn     = module.lambda.invoke_arn
  lambda_arn            = module.lambda.function_arn
  cognito_user_pool_arn = module.cognito.user_pool_arn
  environment           = var.environment
}

# ── ALB ───────────────────────────────────────────────────────────────────────
module "alb" {
  source        = "./modules/alb"
  name          = "${var.project_name}-${var.environment}"
  instance_port = 8080
  environment   = var.environment
}

# ── ASG ───────────────────────────────────────────────────────────────────────
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

# ── CloudWatch Alarms + Dashboard ─────────────────────────────────────────────
module "cloudwatch" {
  source                    = "./modules/cloudwatch"
  name                      = "${var.project_name}-${var.environment}"
  ops_alerts_arn            = module.sns.ops_alerts_arn
  dlq_name                  = module.sqs.dlq_name
  queue_name                = module.sqs.queue_name
  processor_function_name   = module.lambda_states.orchestrator_name
  intake_function_name      = module.lambda.function_name
  alb_arn_suffix            = module.alb.alb_arn_suffix
  dlq_threshold             = var.dlq_threshold
  lambda_error_threshold    = var.lambda_error_threshold
  alb_5xx_threshold         = var.alb_5xx_threshold
  high_order_rate_threshold = var.high_order_rate_threshold
  environment               = var.environment
  aws_region                = var.aws_region
}
