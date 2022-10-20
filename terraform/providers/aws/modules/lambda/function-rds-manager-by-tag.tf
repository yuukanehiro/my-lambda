resource "aws_lambda_function" "rds_manager_by_tag" {
  function_name = "rds-manager-by-tag-${var.ENV_VALUE_ENVIRONMENT}"
  role          = "${var.lambda_ec2_rds_stop_start_manager_role_arn}"

  handler  = "function.lambda_handler"
  runtime  = "python3.9"
  filename = data.archive_file.dummy.output_path
  environment {
    variables = {
      "${var.ENV_NAME_SLACK_CHANNEL_NAME_NOTICE}" = "${var.ENV_VALUE_SLACK_CHANNEL_NAME_NOTICE}"
      "${var.ENV_NAME_SLACK_WEBHOOK_URL}" = "${var.ENV_VALUE_SLACK_WEBHOOK_URL}"
    }
  }
  lifecycle {
    ignore_changes = all
  }
}
resource "aws_lambda_function_url" "rds_manager_by_tag" {
  function_name      = aws_lambda_function.rds_manager_by_tag.function_name
  authorization_type = "NONE"

  depends_on = [
    aws_lambda_function.rds_manager_by_tag
  ]
}

// Event Bridge(AWS版Cron)
# RDS Cluster群 起動ルール
resource "aws_cloudwatch_event_rule" "rds_manager_by_tag_start" {
  name                = "rds-manager-by-tag-rule-start-${var.ENV_VALUE_ENVIRONMENT}"
  description         = "start RDS Clusters"
  schedule_expression = "cron(0 0 ? * Mon-Fri *)" // 初期値 cron(Minutes Hours Day-of-month Month Day-of-week Year)
  # コンソールで変更できるようにする
  lifecycle {
    ignore_changes = [
      schedule_expression,
      is_enabled
    ]
  }
}
resource "aws_cloudwatch_event_target" "rds_manager_by_tag_start" {
  rule      = "${aws_cloudwatch_event_rule.rds_manager_by_tag_start.name}"
  target_id = "rds-manager-by-tag-${var.ENV_VALUE_ENVIRONMENT}"
  arn       = "${aws_lambda_function.rds_manager_by_tag.arn}"
  input = var.MANAGER_BY_TAG_INPUT_JSON_START

  depends_on = [
    aws_lambda_function.rds_manager_by_tag
  ]
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_rds_manager_by_tag_start" {
  statement_id  = "rds-manager-by-tag-start-${var.ENV_VALUE_ENVIRONMENT}"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.rds_manager_by_tag.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.rds_manager_by_tag_start.arn}"
}

# RDS Cluster群 停止ルール
resource "aws_cloudwatch_event_rule" "rds_manager_by_tag_stop" {
  name                = "rds-manager-by-tag-rule-stop-${var.ENV_VALUE_ENVIRONMENT}"
  description         = "stop RDS Clusters"
  schedule_expression = "cron(0 15 ? * Mon-Fri *)" // 初期値 cron(Minutes Hours Day-of-month Month Day-of-week Year)
  lifecycle {
    ignore_changes = [
      schedule_expression // AWSコンソールで変更できるようにする
    ]
  }
}
resource "aws_cloudwatch_event_target" "rds_manager_by_tag_stop" {
  rule      = "${aws_cloudwatch_event_rule.rds_manager_by_tag_stop.name}"
  target_id = "rds-manager-by-tag-${var.ENV_VALUE_ENVIRONMENT}"
  arn       = "${aws_lambda_function.rds_manager_by_tag.arn}"
  input = var.MANAGER_BY_TAG_INPUT_JSON_STOP

  depends_on = [
    aws_lambda_function.rds_manager_by_tag
  ]
}
resource "aws_lambda_permission" "allow_cloudwatch_to_call_rds_manager_by_tag_stop" {
  statement_id  = "rds-manager-by-tag-stop-${var.ENV_VALUE_ENVIRONMENT}"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.rds_manager_by_tag.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.rds_manager_by_tag_stop.arn}"
}
