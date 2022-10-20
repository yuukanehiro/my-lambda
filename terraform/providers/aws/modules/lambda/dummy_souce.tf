# 空のlambdaを作成する為のdummyソースコードとなるリソース
data "archive_file" "dummy" {
  type        = "zip"
  output_path = "${path.module}/../../upload/dummy.zip"
  source {
    content  = "dummy"
    filename = "dummy"
  }
  depends_on = [
    null_resource.main
  ]
}

resource "null_resource" "main" {}
