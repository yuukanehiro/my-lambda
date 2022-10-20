#CD用プロジェクト
resource "aws_codebuild_project" "continuous_deploy" {
  // プロジェクトの設定
  name          = "sample-lambda-${var.ENV_VALUE_ENVIRONMENT}"
  description   = "continuous integration project for terraform repogistory"
  badge_enabled = false

  // ソース
  source {
    type                = "CODECOMMIT"
    location            = var.aws_codecommit_repository_sample_lambda.repository_name
    git_clone_depth     = 1
    report_build_status = true // リポジトリ側へ結果通知
    buildspec           = "buildspec-lambda-cicd.yml"
  }
  source_version = "refs/heads/${var.ENV_VALUE_ENVIRONMENT}"

  // 環境
  environment {
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:2.0-21.10.15" // カスタムイメージURL
    type            = "LINUX_CONTAINER"           // 環境タイプ
    compute_type    = "BUILD_GENERAL1_SMALL"      // コンピューティングタイプ
    privileged_mode = false

    environment_variable {
      name  = var.ENV_NAME_ENVIRONMENT
      value = var.ENV_VALUE_ENVIRONMENT
    }
  }

  service_role = var.codebuild_service_role_arn
  // タイムアウト
  build_timeout = "30"
  // キュータイムアウト
  queued_timeout = "60"

  // アーティファクト
  artifacts {
    type = "NO_ARTIFACTS"
  }

  // キャッシュ
  cache {
    type  = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE"]
  }

  // ログ
  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "codebuild-cd-sample-lambda-${var.ENV_VALUE_ENVIRONMENT}"
      stream_name = "logs-for-codebuild-cd-sample-lambda-${var.ENV_VALUE_ENVIRONMENT}"
    }

    s3_logs {
      status = "DISABLED"
    }
  }
  lifecycle {
    ignore_changes = [
      source,
    ]
  }
}
