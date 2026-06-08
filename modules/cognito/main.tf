################################################################################
# Cognito User Pool - manages user accounts and issues JWT tokens
################################################################################

resource "aws_cognito_user_pool" "this" {
  name = "${var.name}-users"

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  # Auto-verify email addresses
  auto_verified_attributes = ["email"]

  # Schema: require email on signup
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  tags = { Name = "${var.name}-users" }
}

################################################################################
# App Client - the credential your API uses to talk to Cognito
################################################################################

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.name}-api-client"
  user_pool_id = aws_cognito_user_pool.this.id

  # Allow username + password auth (used by API callers to get tokens)
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Token validity
  access_token_validity  = 1   # hours
  id_token_validity      = 1
  refresh_token_validity = 7   # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}
