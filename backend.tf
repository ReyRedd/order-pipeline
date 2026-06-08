################################################################################
# Remote State - required for GitHub Actions CI/CD
#
# Create the S3 bucket ONCE before running terraform init:
#
#   aws s3api create-bucket --bucket <your-bucket-name> --region us-east-1
#   aws s3api put-bucket-versioning \
#     --bucket <your-bucket-name> \
#     --versioning-configuration Status=Enabled
#
# Then set TF_STATE_BUCKET in GitHub Secrets and run the workflow.
################################################################################

terraform {
  backend "s3" {
    # Values injected at runtime by GitHub Actions via -backend-config flags.
    # For local dev, run:
    #   terraform init -backend-config="bucket=<your-bucket>" \
    #                  -backend-config="key=order-pipeline/dev/terraform.tfstate" \
    #                  -backend-config="region=us-east-1" \
    #                  -backend-config="encrypt=true"
  }
}
