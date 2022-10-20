# Lambdaにアタッチ用
resource "aws_iam_policy" "lambda_exec_policy" {
  name = "lambda-multi-policy-${var.environment}"
  policy = file("${path.module}/policy/lambda-exec.json")
}
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-multi-role-${var.environment}"
  assume_role_policy = file("${path.module}/policy/assume-lambda.json")
}
resource "aws_iam_role_policy_attachment" "lambda_multi_role_attach_lambda_multi_policy" {
  role       = "${aws_iam_role.lambda_multi_role.name}"
  policy_arn = "${aws_iam_policy.lambda_multi_policy.arn}"
}
# ECS・RDS管理Lambda
resource "aws_iam_policy" "lambda_ec2_rds_stop_start_manager_policy" {
  name = "lambda-ec2-rds-stop-start-manager-policy-${var.ENV_VALUE_ENVIRONMENT}"
  policy = file("${path.module}/policy/lambda-ec2-rds-stop-start-manager.json")
}
resource "aws_iam_role" "lambda_ec2_rds_stop_start_manager_role" {
  name = "lambda-ec2-rds-stop-start-manager-role-${var.ENV_VALUE_ENVIRONMENT}"
  assume_role_policy = file("${path.module}/policy/assume-lambda.json")
}
resource "aws_iam_role_policy_attachment" "lambda_ec2_rds_stop_start_manager_role_attach_lambda_ec2_rds_stop_start_manager_policy" {
  role       = "${aws_iam_role.lambda_ec2_rds_stop_start_manager_role.name}"
  policy_arn = "${aws_iam_policy.lambda_ec2_rds_stop_start_manager_policy.arn}"
}
