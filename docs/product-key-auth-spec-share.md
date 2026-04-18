# Product Key Authentication Spec (Share)

この文書は、認証サーバー実装担当 AI/開発者との共有用に、現行クライアント実装に合わせた仕様をまとめたものです。

## 1. Base URL

- 認証サーバー base URL（既定）
  - `https://auth.nazono.cloud:8443`
- 上書き方法
  - `--dart-define=LICENSE_AUTH_SERVER_BASE_URL=https://<host>:<port>`

## 2. Endpoints

クライアントが呼び出す認証 API は以下の2つです。

- `POST /api/v1/license/activate`
- `POST /api/v1/license/heartbeat`

## 3. Product Key Format

- 表示/入力フォーマット: `XXXX-XXXX-XXXX-XXXX`
- 使用可能文字: `A-Z`, `0-9`
- 実データ長: 16文字（ハイフン除く）
- クライアント入力時の自動整形:
  - 英大文字化
  - 英数字以外は除去
  - 4文字ごとに `-` を自動挿入
  - 16文字超は切り捨て

バリデーション正規表現:

- `^[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$`

## 4. Request / Response Contract

### 4.1 Activate

Request:

```json
{
  "product_key": "ABCD-1234-EFGH-5678",
  "device": {
    "device_id": "uuid-v4",
    "device_name": "hostname-or-platform",
    "platform": "android|ios|windows|macos|linux|unknown",
    "app_version": "1.0.5-dev3+9"
  },
  "challenge": "base64url-random-32bytes"
}
```

Success envelope（必須）:

```json
{
  "status": "success",
  "data": {
    "license_id": "string",
    "offline_token": "string",
    "license_status": "active|revoked|expired|...",
    "policy": {
      "mode": "full|read_only|..."
    }
  },
  "timestamp": "ISO8601"
}
```

Error envelope（推奨）:

```json
{
  "status": "error",
  "error": {
    "code": "LICENSE_INVALID",
    "message": "human readable"
  },
  "timestamp": "ISO8601"
}
```

### 4.2 Heartbeat

Request:

```json
{
  "license_id": "string",
  "device_id": "uuid-v4",
  "offline_token": "string",
  "app_version": "1.0.5-dev3+9"
}
```

Success envelope（必須）:

```json
{
  "status": "success",
  "data": {
    "license_status": "active|revoked|expired|...",
    "policy": {
      "mode": "full|read_only|..."
    },
    "offline_token": "string (optional: rotated token)"
  },
  "timestamp": "ISO8601"
}
```

## 5. Client Behavior

### 5.1 Startup Flow

- 未認証時（`license_is_activated != true`）
  - ライセンス認証画面へ遷移
  - 認証成功までホームに進まない
- 認証済み時
  - 起動時に heartbeat をバックグラウンド実行（ただし1日1回）

### 5.2 Daily Check Policy

- `license_last_checked_at` を保持
- 前回確認から24時間未満なら heartbeat をスキップ
- 24時間以上経過時のみ heartbeat 実行

### 5.3 Error Handling

- `DioExceptionType.connectionTimeout` / `connectionError`
  - ユーザー向けメッセージ: 接続不可
- API エラー時
  - `error.message` があれば優先表示

## 6. Local Persistence Keys (SharedPreferences)

- `license_product_key`
- `license_is_activated`
- `license_activated_at`
- `license_device_id`
- `license_id`
- `license_offline_token`
- `license_status`
- `license_policy_mode`
- `license_last_checked_at`

## 7. Device Identifier

- `device_id` はクライアント側で初回生成（UUID v4相当）して永続化
- 以降は同じ `device_id` を送信

## 8. Security Notes

- 通信は HTTPS 前提
- クライアントは認証トークン・ライセンス情報をローカル保存
- サーバー側は以下を推奨
  - product key と device の紐付け管理
  - offline token ローテーション
  - `status/error/timestamp` の一貫したレスポンス

## 9. Current Scope and TODO

現行クライアント実装で確定している範囲:

- activate/heartbeat の実装
- 起動時認証ゲート
- 1日1回 heartbeat
- 入力フォーマット自動整形

未適用またはサーバー側で詰めるべき点:

- `read_only` ポリシー時の完全な書き込み制御
- deactivate API のクライアント導線
- offline token の署名検証強化
