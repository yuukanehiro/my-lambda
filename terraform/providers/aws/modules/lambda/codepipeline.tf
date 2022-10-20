resource "aws_codepipeline" "codepipeline" {
  name     = "sample-lambda-deployer-${var.ENV_VALUE_ENVIRONMENT}"
  role_arn = "${var.codepipeline_service_role_arn}"

  artifact_store {
    location = aws_s3_bucket.sample_lambda_codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = var.aws_codecommit_repository_sample_lambda.repository_name
        BranchName     = "${var.ENV_VALUE_ENVIRONMENT}"
      }
    }
  }

  # 本番のみ手動承認stageを作成
  dynamic "stage" {
    for_each = var.ENV_VALUE_ENVIRONMENT == "production" ? [1] : []
    content {
      name = "Approval"
      action {
        name          = "Approval"
        category      = "Approval"
        owner         = "AWS"
        provider      = "Manual"
        version       = "1"
        configuration = {
          CustomData = "承認してください"
        }
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["apply_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.continuous_deploy.name
      }
    }
  }
  lifecycle {
    ignore_changes = [stage[0].action[0].configuration["BranchName"]]
  }
}
