# ──────────────────────────────────────────────────────────────────────────────
# Remote State (enable once you've created the S3 bucket + lock table)
#
# 1. Create the bucket:
#    aws s3api create-bucket --bucket my-tf-state-bucket --region us-east-1
#
# 2. Enable versioning:
#    aws s3api put-bucket-versioning \
#      --bucket my-tf-state-bucket \
#      --versioning-configuration Status=Enabled
#
# 3. Create the DynamoDB lock table:
#    aws dynamodb create-table \
#      --table-name terraform-state-lock \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST
#
# 4. Uncomment the block below and run: terraform init -migrate-state
# ──────────────────────────────────────────────────────────────────────────────

# terraform {
#   backend "s3" {
#     bucket         = "my-tf-state-bucket"
#     key            = "order-pipeline/dev/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
