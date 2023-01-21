import json
import boto3
import botocore
import traceback
import os
import logging
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

def lambda_handler(event: dict, context: object):
    headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        }
    try:
        # Lambda直, API Gateway経由の2パターンがあるので調整
        if 'body' in event.keys():
            # API Gateway経由の場合はbodyキーに格納されているので変換
            event = json.loads(event['body'])

        if _validation(event):
            region = event['region']
            action = event['action']
            app_env = event['app_env']
        else:
            message = 'validation error: 必須キーが抜けています'
            return {
                "statusCode": 422,
                'headers': headers,
                'body': json.dumps(message)
            }
        app_env = app_env.capitalize() # dev -> Dev
        tag = 'Is' + app_env + 'Ec2AutoStartStop' # ex. IsDevEc2AutoStartStop | IsStgEc2AutoStartStop | IsPreEc2AutoStartStop

        # bot3インスタンス生成
        client = boto3.client('ec2', region)
        # タグで指定してEC2インスタンス情報を取得
        responce = client.describe_instances(Filters=[{'Name': 'tag:' + tag, "Values": ['true']}])

        target_instans_ids = []
        tag_names = []
        for reservation in responce['Reservations']:
            for instance in reservation['Instances']:
                logging.info('start instance')
                logging.info(instance['InstanceId'])
                logging.info(instance['State']['Name'])
                logging.info('end instance')
                if action == 'start' and instance['State']['Name'] == 'stopped':
                    target_instans_ids.append(instance['InstanceId'])
                    tag_names = _colletTagNames(instance['Tags'], tag_names)
                elif action == 'stop' and instance['State']['Name'] == 'running':
                    target_instans_ids.append(instance['InstanceId'])
                    tag_names = _colletTagNames(instance['Tags'], tag_names)
        if target_instans_ids:
            if action == 'start':
                # EC2の起動
                client.start_instances(InstanceIds=target_instans_ids)
                logging.info('started instances.')
                tag_names_string = _convertListToStringForSlack("\n", tag_names)
                _slack("EC2 自動起動実行通知", action, tag_names_string)
            elif action == 'stop':
                client.stop_instances(InstanceIds=target_instans_ids)
                logging.info('stopped instances.')
                tag_names_string = _convertListToStringForSlack("\n", tag_names)
                _slack("EC2 自動停止実行通知", action, tag_names_string)
        if action == 'start':
            # AutoScalig Groupの台数を変更
            if _updateAutoScalingGroups(action, app_env, region) == False:
                raise Exception
        elif action == 'stop':
            if _updateAutoScalingGroups(action, app_env, region) == False:
                raise Exception
        else:
            logging.error('Invalid action.')

        message = 'Success'
        return {
            "statusCode": 200,
            'headers': headers,
            'body': json.dumps(message)
        }
    except:
        message = traceback.format_exc()
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps(message)
        }


def _validation(event: dict) -> bool:
    """
    バリデーション

    Parameters
    ----------
    event : dict
        リクエストボディが格納されたオブジェクト
    Returns
    -------
    bool
        バリデーション検証結果の真偽値
    """
    if 'region' in event.keys() and 'action' in event.keys() and 'app_env' in event.keys():
        return True
    else:
        return False


def _updateAutoScalingGroups(action: str, app_env: str, region: str) -> bool:
    """
    起動設定の更新

    Parameters
    ----------
    action: str
        action ["stop"|"start"]
    app_env: str
        環境情報["dev","stg","pre"]
    region: str
        AWSリージョン ex. ap-northeast-1
    Returns
    -------
    bool
        実行の真偽値
    """

    logging.info('start _updateAutoScalingGroups()')
    # 起動する場合の最小, 要求数
    start_param = dict(MinSize=1, DesiredCapacity=1)
    # 停止する場合の最小, 要求数
    stop_param = dict(MinSize=0, DesiredCapacity=0)

    autoscaling = boto3.client("autoscaling", region)
    response = autoscaling.describe_auto_scaling_groups()
    tag = 'Is' + app_env + 'AutoScalingGroupAutoStartStop' # ex. IsDevAutoScalingGroupAutoStartStop | IsStgAutoScalingGroupAutoStartStop # Pre環境のAutoScalingは現状なし 
    all_autoscaling_groups = response['AutoScalingGroups']
    auto_scaling_names = []
    auto_scaling_names = _getAutoScalingGroupNames(all_autoscaling_groups, tag)

    if not auto_scaling_names:
        logging.error('There are no auto_scaling_names. do nothing')
        return
    try:
        if action == 'start':
            for i in range(len(auto_scaling_names)):
                logging.info('start auto_scaling_name')
                logging.info(auto_scaling_names[i])
                logging.info('end auto_scaling_name')
                autoscaling.update_auto_scaling_group(AutoScalingGroupName=auto_scaling_names[i], **start_param)
            start_auto_scaling_names_string = _convertListToStringForSlack("\n", auto_scaling_names)
            _slack("EC2 自動起動実行通知", action, start_auto_scaling_names_string)
        elif action == 'stop':
            for i in range(len(auto_scaling_names)):
                logging.info('start auto_scaling_name')
                logging.info(auto_scaling_names[i])
                logging.info('end auto_scaling_name')
                autoscaling.update_auto_scaling_group(AutoScalingGroupName=auto_scaling_names[i], **stop_param)
            stop_auto_scaling_names_string = _convertListToStringForSlack("\n", auto_scaling_names)
            _slack("EC2 自動停止実行通知", action, stop_auto_scaling_names_string)
        else:
            logging.error('Invalid action.')
        return True;
    except:
        logging.error(traceback.format_exc())
        return False;


def _getAutoScalingGroupNames(all_autoscaling_groups: list, tag: str) -> list[str]:
    """
    AutoScaling名を配列で返却

    Parameters
    ----------
    all_autoscaling_groups: list
        AutoScalingGroup関連情報が格納された配列
    tag: str
        指定タグ名
    Returns
    -------
    auto_scaling_names: list[str]
        AutoScalingグループ名の配列
    """
    logging.info('start _getAutoScalingGroupNames()')
    auto_scaling_names = []
    for i in range(len(all_autoscaling_groups)):
        all_tags = all_autoscaling_groups[i]['Tags']
        for j in range(len(all_tags)):
            if all_tags[j]['Key'] == tag and all_tags[j]['Value'] == 'true':
                auto_scaling_names.append(all_autoscaling_groups[i]['AutoScalingGroupName'])
    return auto_scaling_names


def _colletTagNames(tags: list, tag_names: list) -> list:
    """
    タグからNameの値を配列で返却

    Parameters
    ----------
    tags: list
        EC2のTags配列
    Returns
    -------
    tag_names: list
    """
    for tag in tags:
        if tag['Key'] == "Name":
            tag_names.append(tag['Value'])
    return tag_names

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

def _slack(user_name, action, message):
    """
    Slack通知

    Parameters
    ----------
    user_name: str
        Slackユーザ名
    action: str
        実行命令 [start|stop]
    message: str
        SLACKメッセージ
    Returns
    -------
    void
    """
    color = "good"
    icon = ":recycle:"
    slack_text ="EC2 " + action
    slack_message = {
        'username': "EC2 自動起動・停止通知(Lambda:ec2-manager-by-tag)",
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
