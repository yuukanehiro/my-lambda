# =========================================
# ドメイン証明書の有効期限チェック関数
# =========================================

# Lambda関数リソース
resource "aws_lambda_function" "check_certs" {
  function_name    = "${var.project_name}-check-certs-${var.environment}"
  filename         = filename = data.archive_file.dummy.output_path
  role             = "${var.lambda_multi_role_arn}"
  handler          = "function"
  runtime          = "go1.x"

  memory_size = 128
  timeout     = 60
  environment {
    variables = {
      # AWSのコンソール上でLambdaの環境変数に直接設定してください
      GO_ENV_FQDNS = "" // 「,」で区切って対象のFQDNを指定 ex. "www.google.co.jp,www.yahoo.co.jp"
      GO_ENV_SLACK_WEBHOOK = "" // ex. "https://hooks.slack.com/services/xxxxx/yyyyy/zzzzz"
      GO_ENV_SLACK_CHANNEL_NOTICE = "" // notice通知先Slackチャンネル名 ex. "#example-system-notice"
      GO_ENV_SLACK_CHANNEL_WARN = "" // warn通知先Slackチャンネル名 ex. "##example-system-warn"
      GO_ENV_SLACK_ICON_EMOJI = "" // ex. ":dog:"
      GO_ENV_SLACK_NOTIFY_TITLE = "" // Slack通知タイトル ex. "ドメイン証明書有効期限 監視Bot"
      GO_ENV_BUFFER_DAYS = "" // 猶予期限 ex. 30
    }
  }
  // AWSのコンソールで管理できるようにTerraformでは管理しない
  lifecycle {
    ignore_changes = all
  }
}

// Event Bridge(AWS版Cron)
resource "aws_cloudwatch_event_rule" "check_certs" {
  name                = "${var.project_name}-check-certs-${var.environment}"
  description         = "check certs at fire cron"
  schedule_expression = "cron(0 0 ? * Tue *)" // 初期値 cron(Minutes Hours Day-of-month Month Day-of-week Year)
  lifecycle {
    ignore_changes = [
      schedule_expression // AWSコンソールで変更できるようにする
    ]
  }
}
resource "aws_cloudwatch_event_target" "check_certs" {
  rule      = "${aws_cloudwatch_event_rule.check_certs.name}"
  target_id = "${var.project_name}-check-certs-${var.environment}"
  arn       = "${aws_lambda_function.check_certs.arn}"
}
resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_certs" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.check_certs.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.check_certs.arn}"
}
