# terraform/modules/auth/main.tf

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users-${var.environment}"

  # El usuario se loguea con email
  username_attributes = ["email"]

  # Verificación automática por email al registrarse
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  # Atributos del perfil de usuario
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }
}

# User Pool Client — representa nuestra aplicación dentro del User Pool
# Es quien tiene permiso de autenticar usuarios
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

resource "aws_cognito_user" "test_user" {
  count = var.environment == "dev" ? 1 : 0

  user_pool_id = aws_cognito_user_pool.main.id
  username     = "santi.albisetti@gmail.com"

  attributes = {
    email          = "santi.albisetti@gmail.com" #your test email here
    email_verified = "true"
  }

  temporary_password   = "Test1234!"
  message_action       = "SUPPRESS"
}
