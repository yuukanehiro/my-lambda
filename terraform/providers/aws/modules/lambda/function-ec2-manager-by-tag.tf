# 空のlambdaを作成する為のdummyソースコードとなるリソース
resource "aws_lambda_function" "ec2_manager_by_tag" {
  function_name = "ec2-manager-by-tag-${var.ENV_VALUE_ENVIRONMENT}"
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
resource "aws_lambda_function_url" "ec2_manager_by_tag" {
  function_name      = aws_lambda_function.ec2_manager_by_tag.function_name
  authorization_type = "NONE"
  depends_on = [
    aws_lambda_function.ec2_manager_by_tag
  ]
}

// Event Bridge(AWS版Cron)
# EC2群 起動ルール
resource "aws_cloudwatch_event_rule" "ec2_manager_by_tag_start" {
  name                = "ec2-manager-by-tag-rule-start-${var.ENV_VALUE_ENVIRONMENT}"
  description         = "start EC2 And AutoScalingGroup"
  schedule_expression = "cron(0 0 ? * Mon-Fri *)" // 初期値 cron(Minutes Hours Day-of-month Month Day-of-week Year)
  # コンソールで変更できるようにする
  lifecycle {
    ignore_changes = [
      schedule_expression,
      is_enabled
    ]
  }
}
resource "aws_cloudwatch_event_target" "ec2_manager_by_tag_start" {
  rule      = "${aws_cloudwatch_event_rule.ec2_manager_by_tag_start.name}"
  target_id = "ec2-manager-by-tag-${var.ENV_VALUE_ENVIRONMENT}"
  arn       = "${aws_lambda_function.ec2_manager_by_tag.arn}"
  input = var.MANAGER_BY_TAG_INPUT_JSON_START

  depends_on = [
    aws_lambda_function.ec2_manager_by_tag
  ]
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_ec2_manager_by_tag_start" {
  statement_id  = "ec2-manager-by-tag-start-${var.ENV_VALUE_ENVIRONMENT}"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ec2_manager_by_tag.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.ec2_manager_by_tag_start.arn}"
}

# EC2群 停止ルール
resource "aws_cloudwatch_event_rule" "ec2_manager_by_tag_stop" {
  name                = "ec2-manager-by-tag-rule-stop-${var.ENV_VALUE_ENVIRONMENT}"
  description         = "stop EC2 And AutoScalingGroup"
  schedule_expression = "cron(0 15 ? * Mon-Fri *)" // 初期値 cron(Minutes Hours Day-of-month Month Day-of-week Year)
  lifecycle {
    ignore_changes = [
      schedule_expression // AWSコンソールで変更できるようにする
    ]
  }
}
resource "aws_cloudwatch_event_target" "ec2_manager_by_tag_stop" {
  rule      = "${aws_cloudwatch_event_rule.ec2_manager_by_tag_stop.name}"
  target_id = "ec2-manager-by-tag-${var.ENV_VALUE_ENVIRONMENT}"
  arn       = "${aws_lambda_function.ec2_manager_by_tag.arn}"
  input = var.MANAGER_BY_TAG_INPUT_JSON_STOP

  depends_on = [
    aws_lambda_function.ec2_manager_by_tag
  ]
}
resource "aws_lambda_permission" "allow_cloudwatch_to_call_ec2_manager_by_tag_stop" {
  statement_id  = "ec2-manager-by-tag-stop-${var.ENV_VALUE_ENVIRONMENT}"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ec2_manager_by_tag.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.ec2_manager_by_tag_stop.arn}"
}
