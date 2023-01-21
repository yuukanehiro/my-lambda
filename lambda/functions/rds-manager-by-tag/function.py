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
            message = 'validation error: not exists required key'
            return {
                "statusCode": 422,
                'headers': headers,
                'body': json.dumps(message)
            }
        app_env = app_env.capitalize() # ex. dev -> Dev
        check_tag_key = _getCheckTagKeyName(app_env)
        rds = boto3.client('rds')
        response = rds.describe_db_clusters()
        start_cluster_names = []
        stop_cluster_names = []
        start_cluster_names_string = ""
        stop_cluster_names_string = ""
        for DBCluster in response['DBClusters']:
            for tag in DBCluster['TagList']:
                if tag['Key'] == check_tag_key and tag['Value'] == 'true':
                    if action == 'start':
                        if DBCluster['Status'] == 'stopped':
                            logging.info("startDBCluster: " + DBCluster['DBClusterIdentifier'])
                            rds.start_db_cluster(DBClusterIdentifier=DBCluster['DBClusterIdentifier'])
                            start_cluster_names.append(DBCluster['DBClusterIdentifier'])
                            start_cluster_names_string = _convertListToStringForSlack("\n", start_cluster_names)
                    elif action == 'stop':
                        if DBCluster['Status'] == 'available':
                            logging.info("stopDBCluster: " + DBCluster['DBClusterIdentifier'])
                            rds.stop_db_cluster(DBClusterIdentifier=DBCluster['DBClusterIdentifier'])
                            stop_cluster_names.append(DBCluster['DBClusterIdentifier'])
                            stop_cluster_names_string = _convertListToStringForSlack("\n", stop_cluster_names)

        if action == 'start':
            _slack("DB Cluster 自動起動実行通知", action, start_cluster_names_string)
        if action == 'stop':
            _slack("DB Cluster 自動停止実行通知", action, stop_cluster_names_string)
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


def _getCheckTagKeyName(app_env) -> str:
    """
    DB Cluster 制御タグキー名返却

    Returns
    -------
    str
        検証用タグ名 [IsDevRdsAutoStartStop | IsStgRdsAutoStartStop | IsPreRdsAutoStartStop]
    """
    return 'Is' + app_env + 'RdsAutoStartStop'


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

def _slack(user_name, action, message):
    """
    Slack通知

    Parameters
    ----------
    user_name: str
        Slackユーザ名
    action: str
        RDS実行命令 [start|stop]
    message: str
        SLACKメッセージ
    Returns
    -------
    void
    """
    color = "good"
    icon = ":recycle:"
    slack_text ="Aurora Cluster " + action
    slack_message = {
        'username': "開発系DB Cluster 自動起動・停止通知(Lambda:rds-manager-by-tag)",
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
