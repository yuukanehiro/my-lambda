package main

import (
  "net/http"
  "time"
  "strings"
  "os"
  "net/url"
  "encoding/json"
  "log"
  "strconv"
  "sort"
  "github.com/aws/aws-lambda-go/lambda"
)

type Params struct {
  Text string `json:"text"`
  Username string `json:"username"`
  IconEmoji string `json:"icon_emoji"`
  Channel string `json:"channel"`
}

const DATE_FORMAT string = "2006/01/02" // 日時の形式のサンプルを指定

func main() {
  // Lambdaで利用する為の作法
  lambda.Start(handler)
}

func handler() {
  text_body, is_danger := checkCerts()
  channel := os.Getenv("GO_ENV_SLACK_CHANNEL_NOTICE")
  if (is_danger) {
    channel = os.Getenv("GO_ENV_SLACK_CHANNEL_WARN")
    text_body = addMention(text_body)
  }
  payload := Params {
    Text: text_body, // 文言
    Username: os.Getenv("GO_ENV_SLACK_NOTIFY_TITLE"),// 通知用ユーザ名
    IconEmoji: os.Getenv("GO_ENV_SLACK_ICON_EMOJI"), // icon
    Channel: channel, // Slackの通知チャンネル
  }
  err := notifySlack(os.Getenv("GO_ENV_SLACK_WEBHOOK"), payload)
  if err != nil {
    log.Println(err)
    os.Exit(1)
  }
  log.Println("Slack Notify Success!")
}

/**
 * 証明書の有効期限の検証
 *
 * @return string
 */
func checkCerts() (string, bool) {
  fqdns := strings.Split(strings.TrimSpace(os.Getenv("GO_ENV_FQDNS")), ",") // ex. "www.google.co.jp,www.amazon.co.jp"
  fqdns = sortFqdnsByAlphabet(fqdns)

  result := map[string][]string{}
  buffer_date := getBufferDate()
  log.Println("buffer_date: " + buffer_date.Format(DATE_FORMAT))
  for _, fqdn := range fqdns {
    resp, err := http.Get("https://" + fqdn)
    if err != nil {
      // HTTP通信に失敗したFQDN
      result["unknown_fqdns"] = append(result["unknown_fqdns"], fqdn + ")")
      continue
    }

    expire_utc_time := resp.TLS.PeerCertificates[0].NotAfter
    expire_jst_time := expire_utc_time.In(time.FixedZone("Asia/Tokyo", 9 * 60 * 60))
    expire_date := expire_jst_time.Format(DATE_FORMAT)

    if (expire_jst_time.Before(buffer_date)) {
      // 警告対象のFQDN
      log.Println("fqdn: " + fqdn + ", expire_jst_time: " + expire_jst_time.Format(DATE_FORMAT))
      result["danger_fqdns"] = append(result["danger_fqdns"], fqdn + "(" + expire_date + ")")
    } else {
      // ドメイン証明書の有効期限が十分にあるFQDN
      log.Println("fqdn: " + fqdn + ", expire_jst_time: " + expire_jst_time.Format(DATE_FORMAT))
      result["safe_fqdns"] = append(result["safe_fqdns"], fqdn + "(" + expire_date + ")")
    }
  }
  is_danger := false
  danger_fqdn_message := "有効期限切れが迫った証明書:exclamation:" + "\n"
  for _, danger_fqdn := range result["danger_fqdns"] {
    is_danger = true
    danger_fqdn_message = danger_fqdn_message + danger_fqdn + "\n"
  }
  unknown_fqdn_message := "情報取得に失敗した証明書:question:" + "\n"
  for _, unknown_fqdn := range result["unknown_fqdns"] {
    is_danger = true
    unknown_fqdn_message = unknown_fqdn_message + unknown_fqdn + "\n"
  }
  safe_fqdn_message := "有効期限切れまで猶予のある証明書:green_heart:" + "\n"
  for _, safe_fqdn := range result["safe_fqdns"] {
    safe_fqdn_message = safe_fqdn_message + safe_fqdn + "\n"
  }
  response := danger_fqdn_message + "\n" + unknown_fqdn_message + "\n" + safe_fqdn_message
  return string(response), is_danger
}

/**
 * 猶予日の取得
 *
 * @return time.Time
 */
func getBufferDate() time.Time {
  buffer_days, _ := strconv.Atoi(os.Getenv("GO_ENV_BUFFER_DAYS"))
  return time.Now().AddDate(0, 0, buffer_days)
}

/**
 * @channelメンションの付与
 *
 * @param text_body string
 * @return string
 */
func addMention(text_body string) string {
  return "<!channel>" + "\n" + text_body
}

/**
 * アルファベットでソート
 *
 * @param fqdns []string
 * @return []string
 */
func sortFqdnsByAlphabet(fqdns []string) []string {
  sort.Slice(fqdns, func(i, j int) bool {
    return fqdns[i] < fqdns[j]
  })
  return fqdns
}

/**
 * webhookを利用したSlack通知
 *
 * @param webhook_url string
 * @param payload Params
 * @return nil | error
 */
func notifySlack(webhook_url string, payload Params) (err error) {
  p, err := json.Marshal(payload)
  if err != nil {
    log.Println(err)
    return err
  }
  resp, err := http.PostForm(webhook_url, url.Values{"payload": {string(p)}})
  if err != nil {
    log.Println(err)
    return err
  }
  // Golangの慣例に合わせて関数の最後だけどdeferでClose()する
  defer resp.Body.Close()
  return nil
}
