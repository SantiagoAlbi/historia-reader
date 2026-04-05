module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment
}

module "cdn" {
  source = "./modules/cdn"

  project_name       = var.project_name
  environment        = var.environment
  books_bucket_id    = module.storage.books_bucket_id
  books_bucket_arn   = module.storage.books_bucket_arn
  frontend_bucket_id = module.storage.frontend_bucket_id
}

module "database" {
  source = "./modules/database"

  project_name = var.project_name
  environment  = var.environment
}

module "auth" {
  source = "./modules/auth"

  project_name = var.project_name
  environment  = var.environment
}
/*
module "api" {
  source = "./modules/api"

  project_name                = var.project_name
  environment                 = var.environment
  books_table_name            = module.database.books_table_name
  books_table_arn             = module.database.books_table_arn
  reading_progress_table_name = module.database.reading_progress_table_name
  reading_progress_table_arn  = module.database.reading_progress_table_arn
  user_pool_id                = module.auth.user_pool_id
  aws_region                  = var.aws_region
  books_bucket_id             = module.storage.books_bucket_id
  cloudfront_distribution_id  = module.cdn.distribution_id
}
*/
module "api" {
  source = "./modules/api"

  project_name                = var.project_name
  environment                 = var.environment
  books_table_name            = module.database.books_table_name
  books_table_arn             = module.database.books_table_arn
  reading_progress_table_name = module.database.reading_progress_table_name
  reading_progress_table_arn  = module.database.reading_progress_table_arn
  user_pool_id                = module.auth.user_pool_id
  aws_region                  = var.aws_region
  books_bucket_id             = module.storage.books_bucket_id
  cloudfront_domain           = module.cdn.distribution_domain
  cloudfront_key_pair_id      = "K2ME18PMXZ5XB1"
}

module "ingestion" {
  source = "./modules/ingestion"

  project_name     = var.project_name
  environment      = var.environment
  books_bucket_id  = module.storage.books_bucket_id
  books_bucket_arn = module.storage.books_bucket_arn
  books_table_name = module.database.books_table_name
  books_table_arn  = module.database.books_table_arn
}

module "observability" {
  source = "./modules/observability"

  project_name       = var.project_name
  environment        = var.environment
  state_machine_arn  = module.ingestion.state_machine_arn
  lambda_backend_arn = module.api.lambda_backend_arn
  sns_topic_arn      = module.ingestion.sns_topic_arn
}

module "cicd" {
  source = "./modules/cicd"

  project_name = var.project_name
  environment  = var.environment
  github_repo  = var.github_repo
}
#

#
