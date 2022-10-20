terraform {
  required_version = "1.1.1" # バージョンを制限する。ただしバグフィックスなどのパッチバージョンは更新
  backend "s3" {
    bucket = "sample-terraform-09555555"
    region = "ap-northeast-1"
    # keyは環境で一意にすること
    key     = "develop/terraform.tfstate"
    profile = "terraform-local-deployer"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.10.0" # バージョンを制限する。ただしバグフィックスなどのパッチバージョンは更新
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = {
      env             = var.ENV_VALUE_ENVIRONMENT
      project         = var.TAG_PROJECT
      ChorusCost_Tag1 = var.TAG_PROJECT
    }
  }
}
provider "aws" {
  region  = "us-east-1"
  alias   = "virginia"
  profile = var.aws_profile
  default_tags {
    tags = {
      env             = var.ENV_VALUE_ENVIRONMENT
      project         = var.TAG_PROJECT
      ChorusCost_Tag1 = var.TAG_PROJECT
    }
  }
}

# IAM
module "iam" {
  source                = "../../module/iam"
  ENV_VALUE_ENVIRONMENT = var.ENV_VALUE_ENVIRONMENT
}
# Lambda
module "lambda" {
  source = "../../module/lambda"

  ENV_NAME_ENVIRONMENT                       = var.ENV_NAME_ENVIRONMENT
  ENV_VALUE_ENVIRONMENT                      = var.ENV_VALUE_ENVIRONMENT
  ENV_NAME_SLACK_CHANNEL_NAME_NOTICE         = var.ENV_NAME_SLACK_CHANNEL_NAME_NOTICE
  ENV_VALUE_SLACK_CHANNEL_NAME_NOTICE        = var.ENV_VALUE_SLACK_CHANNEL_NAME_NOTICE
  ENV_NAME_SLACK_WEBHOOK_URL                 = var.ENV_NAME_SLACK_WEBHOOK_URL
  ENV_VALUE_SLACK_WEBHOOK_URL                = var.ENV_VALUE_SLACK_WEBHOOK_URL
  MANAGER_BY_TAG_INPUT_JSON_START            = var.MANAGER_BY_TAG_INPUT_JSON_START
  MANAGER_BY_TAG_INPUT_JSON_STOP             = var.MANAGER_BY_TAG_INPUT_JSON_STOP
  lambda_ec2_rds_stop_start_manager_role_arn = module.iam.lambda_ec2_rds_stop_start_manager_role_arn
  codebuild_service_role_arn                 = module.iam.codebuild_service_role_arn
  codepipeline_service_role_arn              = module.iam.codepipeline_service_role_arn
  aws_codecommit_repository_sample_lambda   = data.terraform_remote_state.common.outputs.aws_codecommit_repository_sample_lambda
}

