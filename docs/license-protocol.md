# Product Key License Protocol v1

この文書は、Bardber クライアント用のプロダクトキー認証プロトコルを定義します。
目的は以下です。

- 初回のみオンライン検証
- 1端末1キー
- 失効時は閲覧のみ（編集・同期不可）
- 既存 API 形式（JSON + status/data/timestamp）との整合

## 1. Transport / Security

- Protocol: HTTPS 必須（TLS 1.2+）
- Content-Type: application/json; charset=utf-8
- Auth:
  - 初回アクティベーション: APIキー不要（product_key + device 情報で認証）
  - 通常 API: 既存 JWT Bearer を維持
- Clock skew: サーバーはクライアント時刻を信頼しない

## 2. Common Envelope

成功:

```json
{
  "status": "success",
  "data": {},
  "timestamp": "2026-04-11T12:34:56Z"
}
```

失敗:

```json
{
  "status": "error",
  "error": {
    "code": "LICENSE_INVALID",
    "message": "Product key is invalid",
    "details": {}
  },
  "timestamp": "2026-04-11T12:34:56Z"
}
```

## 3. Device Fingerprint

クライアントは端末識別子を永続化して送信します。

- device_id: UUID v4（初回生成後に固定）
- device_name: 任意（例: Android-SM-G991B）
- app_version: 例 1.0.4+5
- platform: android/ios/windows

送信例:

```json
{
  "device": {
    "device_id": "0f8fad5b-d9cb-469f-a165-70867728950e",
    "device_name": "Android-SM-G991B",
    "platform": "android",
    "app_version": "1.0.4+5"
  }
}
```

## 4. Endpoints

ベースパス:

- /api/v1/license

### 4.1 POST /api/v1/license/activate

用途:

- 初回アクティベーション
- キーと端末の紐付け
- オフライン利用用ライセンストークン発行

Request:

```json
{
  "product_key": "ABCD-1234-EFGH-5678",
  "device": {
    "device_id": "0f8fad5b-d9cb-469f-a165-70867728950e",
    "device_name": "Android-SM-G991B",
    "platform": "android",
    "app_version": "1.0.4+5"
  },
  "challenge": "base64-random-32bytes"
}
```

Success Response:

```json
{
  "status": "success",
  "data": {
    "license_id": "lic_01J9XYZ...",
    "license_status": "active",
    "plan": "standard",
    "issued_at": "2026-04-11T12:34:56Z",
    "expires_at": null,
    "grace_until": "2026-05-11T12:34:56Z",
    "offline_token": "base64url(jwt-or-paseto)",
    "server_signature": "base64-ed25519-signature",
    "policy": {
      "mode": "full",
      "allow_sync": true,
      "allow_write": true
    }
  },
  "timestamp": "2026-04-11T12:34:56Z"
}
```

Validation Rules:

- product_key 形式: ^[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$
- 同一キーが別 device_id に既に紐付く場合: 409 LICENSE_ALREADY_BOUND
- 同一 device_id の再アクティベートは idempotent に成功可

### 4.2 POST /api/v1/license/heartbeat

用途:

- ライセンス状態確認（手動確認、または定期確認）
- 失効/停止の反映

Request:

```json
{
  "license_id": "lic_01J9XYZ...",
  "device_id": "0f8fad5b-d9cb-469f-a165-70867728950e",
  "offline_token": "base64url(jwt-or-paseto)",
  "app_version": "1.0.4+5"
}
```

Success Response:

```json
{
  "status": "success",
  "data": {
    "license_status": "active",
    "reason": null,
    "policy": {
      "mode": "full",
      "allow_sync": true,
      "allow_write": true
    },
    "next_check_after": "2026-04-12T00:00:00Z",
    "offline_token": "new-token-optional"
  },
  "timestamp": "2026-04-11T12:34:56Z"
}
```

失効時 Response 例:

```json
{
  "status": "success",
  "data": {
    "license_status": "revoked",
    "reason": "payment_overdue",
    "policy": {
      "mode": "read_only",
      "allow_sync": false,
      "allow_write": false
    },
    "next_check_after": "2026-04-11T13:34:56Z"
  },
  "timestamp": "2026-04-11T12:34:56Z"
}
```

### 4.3 POST /api/v1/license/deactivate

用途:

- 端末交換時に紐付け解除

Request:

```json
{
  "license_id": "lic_01J9XYZ...",
  "device_id": "0f8fad5b-d9cb-469f-a165-70867728950e",
  "reason": "device_replacement"
}
```

Response:

```json
{
  "status": "success",
  "data": {
    "deactivated": true
  },
  "timestamp": "2026-04-11T12:34:56Z"
}
```

## 5. Error Codes

- LICENSE_INVALID: キー不正（404 or 422）
- LICENSE_ALREADY_BOUND: 他端末に紐付済み（409）
- LICENSE_REVOKED: 失効済み（403）
- LICENSE_EXPIRED: 期限切れ（403）
- DEVICE_MISMATCH: token と device_id 不一致（403）
- RATE_LIMITED: 試行回数超過（429）
- CHALLENGE_INVALID: challenge 不正（400）
- SERVER_TEMPORARY_UNAVAILABLE: 一時障害（503）

## 6. Client State Machine

- unactivated:
  - 起動時にアクティベーション画面へ遷移
  - 通常機能は利用不可
- active_full:
  - 通常利用可（read/write/sync）
- active_read_only:
  - 閲覧のみ可（write/sync を無効化）
- blocked:
  - 改ざん検知、署名不正、重大違反時

遷移:

- unactivated -> active_full: activate success
- active_full -> active_read_only: heartbeat で revoked/expired
- active_read_only -> active_full: heartbeat で active 復帰
- any -> blocked: token signature invalid など

## 7. Offline Behavior Policy

- 起動時:
  - 保存済み offline_token があり署名検証 OK なら起動継続
  - policy.mode が read_only なら閲覧モード
- オンライン時:
  - heartbeat を 24 時間ごと、または設定画面から手動実行
- オフライン猶予:
  - grace_until を超えたら read_only に降格

## 8. Idempotency / Retry

- activate は以下で冪等:
  - key = sha256(product_key + device_id)
  - ヘッダ Idempotency-Key を受理
- クライアント再試行:
  - 408/429/5xx のみ指数バックオフ（1s, 2s, 4s, max 30s）

## 9. Compatibility With Existing Client

既存実装への適用方針:

- レスポンス構造は既存 `SuccessResponse/ErrorResponse` と同型
- フィールド命名は snake_case
- エラーは `error.code` を必ず返す
- 設定画面の「手動確認」は heartbeat に接続

## 10. Minimal Server-Side Data Model

licenses:

- id (string)
- product_key_hash (string, unique)
- status (active/revoked/expired)
- plan (string)
- bound_device_id (string)
- activated_at (datetime)
- expires_at (datetime nullable)
- updated_at (datetime)

license_events:

- id
- license_id
- type (activate/heartbeat/deactivate/revoke)
- device_id
- payload_json
- created_at

## 11. Recommended Cryptography

- offline_token: PASETO v4.public または JWT(EdDSA)
- 署名鍵: Ed25519
- サーバー秘密鍵は KMS 管理
- クライアントには公開鍵のみ同梱

## 12. OpenAPI Skeleton (excerpt)

```yaml
paths:
  /api/v1/license/activate:
    post:
      summary: Activate product key on first device
  /api/v1/license/heartbeat:
    post:
      summary: Check license state and get policy
  /api/v1/license/deactivate:
    post:
      summary: Unbind license from device
```

---

この v1 は「初回オンライン認証 + 以降ローカル利用 + 失効時閲覧のみ」を満たす最小仕様です。
将来 v2 では、管理者ポータル、複数端末ライセンス、監査 API を拡張できます。
