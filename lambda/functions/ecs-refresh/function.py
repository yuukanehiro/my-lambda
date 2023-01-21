import boto3
import os
import logging
import traceback
import json
from urllib.request import Request, urlopen

def lambda_handler(event: dict, context: object):
  bucket_name = _addEnvSuffix('ecs-refresh')
  deployment_config_name = 'CodeDeployDefault.ECSAllAtOnce'
  try:
    deploy_app_names = os.environ['DEPLOY_APP_NAMES'] # ex. "app-A,app-B"
    deploy_app_names_list = deploy_app_names.split(',')
    app_names_list_for_slack = []
    for deploy_app_name in deploy_app_names_list:
      app_names_list_for_slack.append(_addEnvSuffix(deploy_app_name))
      bucket_key = _makeS3BucketKey(bucket_name)
      _createDeployment(_addEnvSuffix(deploy_app_name), bucket_name, bucket_key, deployment_config_name)
    app_names_list_for_slack_string = _convertListToStringForSlack("\n", app_names_list_for_slack)
    message=app_names_list_for_slack_string
    color = "good"
    _slack(message, color)
  except:
    message = traceback.format_exc()
    color = "danger"
    _slack(message, color)

def _makeS3BucketKey(deploy_app_name: str) -> str:
  """
  make key name
  Parameters
  ----------
  key: str
   target name string
  Returns
  -------
  str
  """
  return deploy_app_name + '/appspec.yaml'

def _addEnvSuffix(name: str) -> str:
  """
  Add Suffix
  Parameters
  ----------
  name: str
   target name string
  Returns
  -------
  str
  """
  return name + '-' + os.environ['ENVIRONMENT']

def _createDeployment(deploy_app_name: str, bucket_name: str, bucket_key: str, deployment_config_name: str) -> None:
  """
  ECS Refresh
  Parameters
  ----------
  deploy_app_name: str
    CodeDeploy application name
  bucket_name: str
    S3 Bucket Name
  deployment_config_name: str
    CodeDeploy Deployment Config Name
  Returns
  -------
  None
  """
  client_codedeploy = boto3.client('codedeploy')
  client_codedeploy.create_deployment(
    applicationName=deploy_app_name,
    deploymentGroupName=deploy_app_name,
    revision={
      'revisionType': 'S3',
      's3Location': {
        'bucket': bucket_name,
        'key': deploy_app_name + '/appspec.yaml',
        'bundleType': 'YAML'
      }
    },
    deploymentConfigName=deployment_config_name,
  )

def _convertListToStringForSlack(keyword: str, target_list: list) -> str:
  """
  Slack用に配列を改行文字に変換

  Parameters
  ----------
  keyword: str
      配列要素の区切り文字
  target_list: list
      配列要素
  Returns
  -------
  str
  """
  return keyword.join(map(str, target_list))

def _slack(message, color):
  """
  Slack通知
  Parameters
  ----------
  message: str
    SLACK Message
  Returns
  -------
  void
  """
  icon = ":recycle:"
  slack_text ="ECS Reflesh Start!"
  slack_message = {
    'username': "ECS Reflesher(Lambda:ecs-refresh-" + os.environ['ENVIRONMENT'] + ")",
    'text': slack_text,
    'icon_emoji': icon,
    'channel': os.environ['SLACK_CHANNEL_NAME_NOTICE'],
    'attachments': [
      {
        "color": color,
        "text": message
      }
    ]
  }
  req = Request(os.environ['SLACK_WEBHOOK_URL'], json.dumps(slack_message).encode('utf-8'))
  try:
    response = urlopen(req)
    response.read()
    logging.info("Message posted to %s", os.environ['SLACK_WEBHOOK_URL'])
  except HTTPError as e:
    logging.error("Request failed: %d %s", e.code, e.reason)
  except URLError as e:
    logging.error("Server connection failed: %s", e.reason)
