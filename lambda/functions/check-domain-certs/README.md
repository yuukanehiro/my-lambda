# check domain certs

## description
Check the expiration date of the certificate through HTTPS communication and report to Slack.

## env

```
export GO_ENV_FQDNS="www.google.co.jp,www.yahoo.co.jp"
export GO_ENV_SLACK_WEBHOOK="https://hooks.slack.com/services/xxxxxx/yyyyyyzzzzzzzz"
export GO_ENV_SLACK_CHANNEL_NOTICE="#example-system-notice"
export GO_ENV_SLACK_CHANNEL_WARN="##example-system-warn"
export GO_ENV_SLACK_ICON_EMOJI=":dog:"
export GO_ENV_SLACK_NOTIFY_TITLE="ドメイン証明書有効期限 監視Bot"
export GO_ENV_BUFFER_DAYS="30"
```