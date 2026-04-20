# LStocker サーバーソフトウェア統合設計書

この文書は、LStocker Client と連携するサーバーソフトウェアを新規実装する AI / 開発担当へ渡すための実装用設計書です。

対象は次の 3 系統です。

- 業務 API サーバー
- 在庫バックアップ API サーバー
- ライセンス認証 API サーバー

この設計書の最重要方針は、既存の Flutter クライアント実装と互換であることです。既存文書とクライアント実装に差分がある場合は、クライアント実装を優先してください。

---

## 1. 文書の目的

- クライアントが期待している API 契約を明文化する
- サーバー側の責務分離を明確にする
- 実装担当 AI がそのまま開発へ入れる粒度で、DB 設計、同期規則、エラー規則、検証項目まで定義する
- 将来拡張可能でありつつ、現行クライアントを壊さない互換条件を固定する

---

## 2. 適用範囲

### 2.1 本設計に含むもの

- 業務 API の認証、商品、在庫、部門、同期 API
- プロダクトキー単位の在庫バックアップ API
- プロダクトキー認証とライセンス状態確認 API
- サーバー内の論理データモデル
- 同期競合判定、バックアップ復元、監査、運用上の要件

### 2.2 本設計に含まないもの

- Flutter クライアントの UI 実装
- モバイル OS / Windows の端末管理
- インフラの具体的な IaC 実装詳細
- CDN や WAF の個別製品選定

---

## 3. 事実源と優先順位

サーバー実装時の判断順は以下とします。

1. Flutter クライアント実装
2. この設計書
3. 既存の共有ドキュメント

特に次の実装を正本とみなします。

- 業務 API 契約: [lib/services/api_service.dart](../lib/services/api_service.dart), [lib/models/api_models.dart](../lib/models/api_models.dart)
- 在庫バックアップ API 契約: [lib/services/inventory_backup_service.dart](../lib/services/inventory_backup_service.dart)
- ライセンス認証 API 契約: [lib/services/product_key_service.dart](../lib/services/product_key_service.dart)
- ローカル DB 前提: [lib/services/database_helper.dart](../lib/services/database_helper.dart)

---

## 4. システム全体像

### 4.1 論理構成

```text
Flutter Client
  |- 業務 API サーバー
  |    |- 認証 /auth/login, /auth/refresh
  |    |- 商品 /products
  |    |- 在庫 /inventories
  |    |- 部門 /departments
  |    |- 同期 /products/sync, /inventories/sync
  |
  |- 在庫バックアップ API サーバー
  |    |- /api/v1/backups/inventories/upload
  |    |- /api/v1/backups/inventories/latest
  |
  |- ライセンス認証 API サーバー
       |- /api/v1/license/activate
       |- /api/v1/license/heartbeat
       |- 将来: /api/v1/license/deactivate
```

### 4.2 デプロイ方針

単一プロセスでも、別サービスでも構いません。ただし、責務は必ず分離してください。

- 業務 API: 商品・在庫・部門・ユーザー認証・同期
- バックアップ API: product_key 単位の在庫スナップショット保存と取得
- ライセンス API: プロダクトキーと端末の紐付け、ライセンス状態の返却

### 4.3 必須互換条件

- 業務 API は JWT Bearer を前提とする
- バックアップ API は JWT を要求しない
- ライセンス API はプロダクトキー認証を扱い、JWT とは独立させる
- クライアントはオフラインファーストであり、サーバーが同期前提の唯一の正ではない

---

## 5. クライアント前提の設計原則

### 5.1 オフラインファースト

- クライアントはローカル SQLite を正として一時運用する
- サーバーは後続同期で収束させる
- サーバーはクライアントの再送、重複送信、時刻ずれに耐える必要がある

### 5.2 後方互換優先

- JSON キー名は現行クライアントと一致させる
- ライセンス API だけは現行クライアント互換のため、共有仕様書よりも実装の期待値を優先する
- バックアップ API は snake_case と camelCase の一部混在受理に対応する

### 5.3 冪等性優先

- 同じ同期リクエストが再送されても破壊的にならないこと
- ライセンス activate は Idempotency-Key を受理すること
- バックアップ upload は product_key ごとの最新スナップショット上書きとして扱うこと

---

## 6. データモデル

### 6.1 products

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| jan_code | string | 必須 | PK。JAN コード |
| name | string | 必須 | 商品名 |
| description | string nullable | 任意 | 説明 |
| image_path | string nullable | 任意 | 画像参照パス |
| dept_number | int | 必須 | 部門番号 |
| sales_period | int | 必須 | 販売許容期間（日数） |
| is_deleted | bool | 必須 | 論理削除 |
| server_modified_at | datetime | 必須 | サーバー最終更新時刻 |
| modified_by | int nullable | 任意 | 最終更新ユーザー |
| created_at | datetime | 必須 | 作成時刻 |
| updated_at | datetime | 必須 | 更新時刻 |

### 6.2 inventories

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| id | int | 必須 | PK |
| jan_code | string | 必須 | 商品参照 |
| quantity | int | 必須 | 数量 |
| expiration_date | datetime | 必須 | 賞味期限 |
| registration_date | datetime | 必須 | 在庫登録日 |
| is_archived | bool | 必須 | アーカイブフラグ |
| server_modified_at | datetime | 必須 | サーバー最終更新時刻 |
| modified_by | int nullable | 任意 | 最終更新ユーザー |
| created_at | datetime | 必須 | 作成時刻 |
| updated_at | datetime | 必須 | 更新時刻 |

### 6.3 departments

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| dept_number | int | 必須 | PK |
| name | string | 必須 | 部門名 |
| updated_at | datetime | 必須 | 更新時刻 |

### 6.4 users

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| id | int | 必須 | PK |
| username | string | 必須 | 一意 |
| password_hash | string | 必須 | ハッシュ保存 |
| role | string | 必須 | admin / staff など |
| is_active | bool | 必須 | 有効フラグ |
| created_at | datetime | 必須 | 作成時刻 |
| updated_at | datetime | 必須 | 更新時刻 |

### 6.5 license_bindings

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| license_id | string | 必須 | ライセンス識別子 |
| product_key | string | 必須 | 正規化済みキー |
| device_id | string | 必須 | 端末識別子 |
| device_name | string nullable | 任意 | 表示名 |
| platform | string nullable | 任意 | android / ios / windows 等 |
| app_version | string nullable | 任意 | クライアント版 |
| status | string | 必須 | active / revoked / expired |
| policy_mode | string | 必須 | full / read_only |
| offline_token | string nullable | 任意 | オフライン利用トークン |
| bound_at | datetime | 必須 | 紐付時刻 |
| last_heartbeat_at | datetime nullable | 任意 | 最終確認時刻 |
| updated_at | datetime | 必須 | 更新時刻 |

### 6.6 inventory_backups

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| backup_id | string | 必須 | バックアップ識別子 |
| product_key | string | 必須 | バックアップ論理キー |
| inventories_json | json | 必須 | 在庫配列スナップショット |
| item_count | int | 必須 | 件数 |
| checksum | string | 必須 | 改ざん検知用 |
| created_at | datetime | 必須 | 作成時刻 |
| source | string | 必須 | manual_upload 等 |

### 6.7 sync_audit_logs

| カラム | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| id | int | 必須 | PK |
| entity_type | string | 必須 | product / inventory |
| entity_id | string | 必須 | jan_code または inventory id |
| operation | string | 必須 | create / update / delete |
| request_id | string nullable | 任意 | リクエスト相関 ID |
| client_timestamp | datetime nullable | 任意 | クライアント申告時刻 |
| server_timestamp | datetime | 必須 | 受理時刻 |
| applied | bool | 必須 | 適用可否 |
| conflict_type | string nullable | 任意 | newer_on_server 等 |
| actor_user_id | int nullable | 任意 | 実行者 |
| payload_digest | string | 必須 | 監査用ダイジェスト |
| created_at | datetime | 必須 | 作成時刻 |

---

## 7. 共通レスポンス規則

### 7.1 業務 API の基本エンベロープ

業務 API は以下を基本とします。

成功:

```json
{
  "status": "success",
  "data": {},
  "timestamp": "2026-04-20T12:00:00Z"
}
```

失敗:

```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "human readable"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### 7.2 バックアップ API のレスポンス許容

クライアントは柔軟に読み取るため、推奨形式は success エンベロープですが、少なくとも以下を満たしてください。

- 取得系では `inventories` 配列が読み出せること
- 配列の位置は `data.inventories` を推奨
- 後方互換として `data.items`, `data.records`, ルート `inventories` でも可

### 7.3 ライセンス API の互換上の注意

現行クライアントは共有仕様書と異なる期待値を持っています。サーバー実装では次を必須とします。

- ルート `status` は `ok` を返す
- `data.result` に `ok` を返す
- `data.license_key` を返す
- `data.status` にライセンス状態を返す
- `data.policy` は文字列 `full` / `read_only` でも受理される形にする

推奨レスポンス:

```json
{
  "status": "ok",
  "data": {
    "result": "ok",
    "license_id": "lic_001",
    "license_key": "ABCD-1234-EFGH-5678",
    "status": "active",
    "policy": "full",
    "offline_token": "opaque-token"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

将来拡張として、`policy.mode` 等の追加フィールドを併記してもよいですが、現行クライアント互換を壊してはいけません。

---

## 8. 業務 API 設計

### 8.1 認証 API

#### POST /auth/login

用途:

- 業務 API 利用のための JWT 発行

Request:

```json
{
  "username": "staff01",
  "password": "plain-text-input"
}
```

Response data:

```json
{
  "user_id": 1,
  "username": "staff01",
  "access_token": "jwt-access-token",
  "refresh_token": "jwt-refresh-token",
  "expires_in": 3600
}
```

要件:

- access_token は Bearer で利用できること
- refresh_token は `/auth/refresh` で再発行に使えること
- `expires_in` は秒数で返すこと

#### POST /auth/refresh

Request:

```json
{
  "refresh_token": "jwt-refresh-token"
}
```

Response data:

```json
{
  "access_token": "new-jwt-access-token",
  "expires_in": 3600
}
```

要件:

- 401 時にクライアントが自動リトライするため、再発行処理は軽量であること
- 同時多発リフレッシュでも安全に扱えること

### 8.2 ヘルス / ブートストラップ

#### GET /health

- 200 を返すこと
- バックアップ API の接続確認でも同系統の疎通確認が必要

#### GET /info

- サーバー名、バージョン、環境などのメタ情報を返す
- クライアントは Map として扱うため、互換性のために JSON Object を返すこと

#### POST /activate

- 現行クライアントはボディなしで呼び出す
- 用途は端末やセッションのアクティベーション通知
- 最低限 200 か 204 を返せばよい
- 将来使う場合に備え、監査ログ記録を推奨

### 8.3 商品 API

#### GET /products

Query:

- `since` optional
- `limit` optional, default 1000
- `offset` optional, default 0

Response data:

```json
{
  "products": [
    {
      "jan_code": "4901234567890",
      "name": "商品A",
      "description": "説明",
      "image_path": "images/p001.jpg",
      "dept_number": 10,
      "sales_period": 3,
      "server_modified_at": "2026-04-20T12:00:00Z",
      "modified_by": 1
    }
  ],
  "total_count": 1,
  "server_timestamp": "2026-04-20T12:00:05Z"
}
```

要件:

- `server_timestamp` は必須
- `total_count` は必須
- `since` 指定時は `server_modified_at > since` を返す
- 論理削除商品は通常一覧から除外するか、削除情報として同期系で返す

#### POST /products/sync

Request:

```json
{
  "last_sync_timestamp": "2026-04-19T00:00:00Z",
  "client_timestamp": "2026-04-20T12:00:00Z",
  "products": [
    {
      "jan_code": "4901234567890",
      "name": "商品A",
      "description": "説明",
      "image_path": "images/p001.jpg",
      "dept_number": 10,
      "sales_period": 3,
      "operation": "create"
    }
  ]
}
```

Response data:

```json
{
  "applied_count": 1,
  "server_changes": [],
  "conflicts": [],
  "server_timestamp": "2026-04-20T12:00:02Z"
}
```

要件:

- `conflicts` は常に配列を返す
- `server_changes` は常に配列を返す
- `server_timestamp` は必須
- `server_modified_at` を各行に付与する

### 8.4 在庫 API

#### GET /inventories

Query:

- `since` optional
- `limit` optional, default 1000
- `offset` optional, default 0
- `jan_code` optional

Response data:

```json
{
  "inventories": [
    {
      "id": 1001,
      "jan_code": "4901234567890",
      "quantity": 5,
      "expiration_date": "2026-05-01T00:00:00.000",
      "registration_date": "2026-04-20T00:00:00.000",
      "is_archived": false,
      "server_modified_at": "2026-04-20T12:00:00Z",
      "modified_by": 1
    }
  ],
  "total_count": 1,
  "server_timestamp": "2026-04-20T12:00:05Z"
}
```

#### POST /inventories/sync

Request:

```json
{
  "last_sync_timestamp": "2026-04-19T00:00:00Z",
  "client_timestamp": "2026-04-20T12:00:00Z",
  "inventories": [
    {
      "id": 1001,
      "jan_code": "4901234567890",
      "quantity": 5,
      "expiration_date": "2026-05-01T00:00:00.000",
      "registration_date": "2026-04-20T00:00:00.000",
      "is_archived": false,
      "operation": "update"
    }
  ]
}
```

Response data:

```json
{
  "applied_count": 1,
  "created_ids": [
    {
      "client_temp_id": "temp_1713500000",
      "server_id": 1001
    }
  ],
  "server_changes": [],
  "conflicts": [],
  "server_timestamp": "2026-04-20T12:00:02Z"
}
```

要件:

- `created_ids` は常に配列を返す
- 新規在庫作成時、クライアント側暫定 ID とサーバー ID の対応を返せること
- `server_changes` は常に配列を返す
- `conflicts` は常に配列を返す

### 8.5 部門 API

#### GET /departments

Response data:

```json
{
  "departments": [
    {
      "dept_number": 10,
      "name": "加工食品"
    }
  ],
  "server_timestamp": "2026-04-20T12:00:00Z"
}
```

要件:

- `server_timestamp` は必須
- 変更頻度は低い前提だが、キャッシュしやすいよう ETag 対応推奨

---

## 9. 同期アルゴリズム

### 9.1 基本原則

- クライアント送信分を適用した上で、サーバー側の変更差分を返す
- 衝突しないものは即時適用する
- 衝突したものは `conflicts` に格納する
- すべての変更行に `server_modified_at` を持たせる

### 9.2 競合判定

競合は次の条件で判定します。

- 同一エンティティが `last_sync_timestamp` 以降にサーバーでも更新されている
- かつクライアントからも update / delete が来ている

判定に使う値:

- サーバー側: `server_modified_at`
- クライアント側: `updatedAtLocal` に相当する更新時刻は送られないため、リクエスト全体の `client_timestamp` と監査ログを補助的に用いる

### 9.3 競合レスポンス

商品競合例:

```json
{
  "jan_code": "4901234567890",
  "conflict_type": "newer_on_server",
  "server_version": {
    "jan_code": "4901234567890",
    "name": "商品A(サーバー版)",
    "description": null,
    "image_path": null,
    "dept_number": 10,
    "sales_period": 3,
    "server_modified_at": "2026-04-20T12:00:00Z",
    "modified_by": 1
  },
  "client_version": {
    "jan_code": "4901234567890",
    "name": "商品A(クライアント版)",
    "description": null,
    "image_path": null,
    "dept_number": 10,
    "sales_period": 3,
    "operation": "update"
  },
  "resolution": "server_wins"
}
```

### 9.4 推奨解決方針

- 初期実装は `server_wins` を標準とする
- 将来の UI 拡張用に `client_wins` を受理できる設計にする
- `client_wins` 指定時は、サーバーが強制上書きを許可する

### 9.5 単調時刻規則

- `server_modified_at` は UTC の ISO8601 で返す
- 同一行の再更新では、以前の値以上であること
- バックアップ復元時にも単調性を崩さないこと

### 9.6 削除規則

- products は論理削除を基本とする
- inventories は次の 2 形態を区別する
  - `is_archived = true`: 業務上のアーカイブ
  - `operation = delete`: 同期上の削除要求
- クライアント互換上、`is_archived` は削除とは別概念として扱う

---

## 10. 在庫バックアップ API 設計

### 10.1 基本方針

- バックアップ対象は在庫のみ
- 商品マスタ、部門マスタ、アプリ設定、ライセンス状態は含めない
- 識別キーは `product_key`
- 同一 `product_key` について最新スナップショット 1 件を即時取得できること

### 10.2 POST /api/v1/backups/inventories/upload

Request:

```json
{
  "product_key": "ABCD-EFGH-IJKL-MNOP",
  "inventories": [
    {
      "id": 101,
      "jan_code": "4900000000001",
      "quantity": 5,
      "expiration_date": "2026-05-01T00:00:00.000",
      "registration_date": "2026-04-19T00:00:00.000",
      "is_archived": false
    }
  ]
}
```

要件:

- `product_key` は必須
- `inventories` は必須配列
- 同一 `product_key` へ保存する際は、最新スナップショットとして上書き保存してよい
- `id` は参考値であり、バックアップサーバー内部 PK と一致させる必要はない
- 少なくとも `jan_code`, `quantity`, `expiration_date` は欠落なく保存する
- `registration_date`, `is_archived` は受け入れること

推奨レスポンス:

```json
{
  "status": "success",
  "data": {
    "product_key": "ABCD-EFGH-IJKL-MNOP",
    "stored_count": 1,
    "updated_at": "2026-04-20T12:00:00Z"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### 10.3 POST /api/v1/backups/inventories/latest

Request:

```json
{
  "product_key": "ABCD-EFGH-IJKL-MNOP"
}
```

推奨レスポンス:

```json
{
  "status": "success",
  "data": {
    "product_key": "ABCD-EFGH-IJKL-MNOP",
    "inventories": [
      {
        "id": 101,
        "jan_code": "4900000000001",
        "quantity": 5,
        "expiration_date": "2026-05-01T00:00:00.000",
        "registration_date": "2026-04-19T00:00:00.000",
        "is_archived": false
      }
    ],
    "updated_at": "2026-04-20T12:00:00Z"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

受理 / 返却互換条件:

- `jan_code` または `janCode`
- `expiration_date` または `expirationDate`
- `registration_date` または `registrationDate`
- `is_archived` または `isArchived`

### 10.4 復元時のサーバー前提

クライアントは取得した在庫一覧でローカル在庫を全置換します。差分マージではありません。

したがって、サーバーは次を前提にする必要があります。

- latest は常に自己完結したスナップショットを返す
- 不完全な部分更新を返してはいけない
- 空配列を返す場合は「バックアップなし」相当として扱われる

### 10.5 疎通確認

- `GET /health` または `GET /` のどちらかで 2xx を返すこと
- クライアントは `/health` を先に試し、失敗したら `/` を試す

---

## 11. ライセンス認証 API 設計

### 11.1 方針

- プロダクトキーは `XXXX-XXXX-XXXX-XXXX`
- 1 キー 1 端末を基本とする
- 端末識別子はクライアント生成の `device_id`
- 現行クライアント互換のため、リクエストとレスポンスは最小限シンプルに受ける
- 将来拡張用に追加フィールドを受けてもよいが、現行互換を壊さない

### 11.2 POST /api/v1/license/activate

現行クライアント互換 Request:

```json
{
  "license_key": "ABCD-1234-EFGH-5678",
  "device_id": "uuid-v4"
}
```

拡張互換として受理推奨の Request:

```json
{
  "product_key": "ABCD-1234-EFGH-5678",
  "device": {
    "device_id": "uuid-v4",
    "device_name": "Windows-PC",
    "platform": "windows",
    "app_version": "1.0.5-dev10+16"
  },
  "challenge": "base64url-random"
}
```

必須レスポンス互換:

```json
{
  "status": "ok",
  "data": {
    "result": "ok",
    "license_id": "lic_001",
    "license_key": "ABCD-1234-EFGH-5678",
    "status": "active",
    "policy": "full",
    "offline_token": "opaque-token"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

要件:

- `Idempotency-Key` ヘッダを受理する
- 既に同一 `license_key + device_id` の組み合わせなら冪等成功でよい
- 他端末へ既にバインド済みの場合は 409 を返す
- product key / license key のどちらのキー名でも受理できるようにしてよい

### 11.3 POST /api/v1/license/heartbeat

現行クライアント互換 Request:

```json
{
  "license_key": "ABCD-1234-EFGH-5678",
  "device_id": "uuid-v4",
  "offline_token": "opaque-token"
}
```

必須レスポンス互換:

```json
{
  "status": "ok",
  "data": {
    "result": "ok",
    "status": "active",
    "policy": "full",
    "offline_token": "rotated-token"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

要件:

- `offline_token` はローテーションしてもよい
- `status` は `active`, `revoked`, `expired`, `unknown` を最低限扱う
- `policy` は `full` または `read_only`
- read_only 時は同期と書き込みを禁止する前提で返す

### 11.4 POST /api/v1/license/deactivate

将来実装項目です。現行クライアント導線は未実装ですが、サーバー設計上は予約します。

### 11.5 ライセンス状態の業務 API 反映

ライセンス API と業務 API を同一運用する場合、`policy = read_only` のときは少なくとも以下を拒否してください。

- 商品の作成・更新・削除
- 在庫の作成・更新・削除
- `/products/sync`
- `/inventories/sync`

閲覧系は継続可能にします。

---

## 12. バックアップ復元と同期の整合

### 12.1 クライアントの復元動作

クライアントはバックアップ復元時に次を行います。

- 返却された在庫一覧でローカル `inventories` テーブルを全置換
- ローカル `sync_queue` の inventory エントリを削除

### 12.2 サーバー側で守るべきこと

- 復元後の次回同期で全件競合を起こしにくいよう、スナップショットは一貫した時点の内容にする
- 業務 API 側の `server_modified_at` は、復元前後で時間が逆行しないようにする
- 復元元データが古い場合でも、サーバーが新しいデータを持つなら次回同期で server_changes として返せるようにする

### 12.3 推奨実装

- バックアップ取得は業務 DB と独立したスナップショットとして管理する
- 業務 DB に対する復元管理 API を将来追加する場合は、dry-run と full-replace を分ける
- 復元実行時は audit log を残す

---

## 13. 入力検証規則

### 13.1 JAN コード

- string として扱う
- 先頭ゼロを保持する
- 一意であること
- 厳密な桁数検証は将来拡張でもよいが、少なくとも空文字禁止

### 13.2 数量

- 0 以上の整数

### 13.3 日付

- クライアントは ISO8601 文字列を送る
- サーバーは UTC へ正規化して保持する
- 返却時も ISO8601 で返す

### 13.4 プロダクトキー

- 正規表現: `^[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$`
- 正規化は大文字化してから行う

---

## 14. エラー設計

### 14.1 推奨 HTTP ステータス

- 200: 正常
- 201: 作成成功
- 204: 内容なし成功
- 400: リクエスト不正
- 401: JWT 不正または期限切れ
- 403: 権限不足、read_only、license invalid
- 404: 対象なし
- 409: ライセンス重複バインド、競合状態
- 422: バリデーションエラー
- 429: レート制限
- 500: サーバー内部エラー
- 503: 一時障害

### 14.2 推奨エラーコード

- VALIDATION_ERROR
- AUTH_REQUIRED
- TOKEN_EXPIRED
- FORBIDDEN_READ_ONLY
- PRODUCT_NOT_FOUND
- INVENTORY_NOT_FOUND
- LICENSE_INVALID
- LICENSE_ALREADY_BOUND
- LICENSE_REVOKED
- LICENSE_EXPIRED
- DEVICE_MISMATCH
- RATE_LIMITED
- SERVER_TEMPORARY_UNAVAILABLE

---

## 15. 非機能要件

### 15.1 セキュリティ

- すべて HTTPS 必須
- JWT と offline_token は平文保存しない
- パスワードは安全なハッシュで保存する
- 監査ログには機微情報を直書きしない

### 15.2 性能

- 一覧 API は `limit` / `offset` に対応
- 初期値 1000 件で返せること
- 同期 API は 1 リクエストあたり数百件程度を無理なく処理できること

### 15.3 可用性

- `/health` は DB 接続や基本依存を確認できること
- バックアップ API は一時障害時に 503 を返し、クライアント再試行を阻害しないこと

### 15.4 監査

- 同期 API の受信要約ログを残す
- ライセンス activate / heartbeat を監査可能にする
- バックアップ upload / latest を監査可能にする

---

## 16. 推奨インデックス

- products: `jan_code`, `is_deleted`, `server_modified_at`
- inventories: `id`, `jan_code`, `is_archived`, `expiration_date`, `server_modified_at`
- users: `username`
- license_bindings: `product_key`, `device_id`, `license_id`
- inventory_backups: `product_key`, `created_at`
- sync_audit_logs: `entity_type`, `entity_id`, `server_timestamp`

---

## 17. 実装順序

1. 共通エンベロープとエラーフォーマットを実装する
2. `/auth/login`, `/auth/refresh` を実装する
3. `/health`, `/info`, `/activate` を実装する
4. `/departments`, `/products`, `/inventories` の参照 API を実装する
5. `/products/sync`, `/inventories/sync` を実装する
6. `/api/v1/backups/inventories/upload`, `/latest` を実装する
7. `/api/v1/license/activate`, `/heartbeat` を実装する
8. 監査ログ、レート制限、read_only 制御を実装する

---

## 18. 実装担当 AI への具体指示

### 18.1 破壊的変更を禁止する項目

- 商品 API の `jan_code` キー名変更
- 在庫 API の `expiration_date`, `registration_date`, `is_archived` キー名変更
- 同期レスポンスから `server_timestamp`, `conflicts`, `created_ids` を省略すること
- ライセンス API の `status = ok`, `data.result = ok` をやめること
- バックアップ latest から `inventories` 配列を返さないこと

### 18.2 最低限必要なテスト

- JWT ログイン成功 / 失敗
- 401 後の refresh 成功 / 失敗
- 商品同期で競合なし / 競合あり
- 在庫同期で新規作成 ID 再マッピングあり
- 在庫バックアップ upload / latest 正常系
- バックアップ latest 空配列
- ライセンス activate 正常系
- ライセンス activate 重複端末バインド
- ライセンス heartbeat で read_only へ降格
- `/health` と `/` の疎通

### 18.3 モックで再現すべきケース

- 同じ同期リクエストの二重送信
- `since` 境界時刻の差分取得
- バックアップ復元直後の再同期
- ライセンス API の token rotation
- 商品マスタが無い状態で在庫バックアップを復元したケース

---

## 19. 未決事項

以下は今回の設計で方針を置いていますが、必要なら実装前に再確認してください。

### 19.1 競合解決の最終仕様

- 初期実装は `server_wins` を推奨
- 将来 UI で `client_wins` を選べるようにするかは未決

### 19.2 ライセンス API の拡張形式

- 現行互換だけなら `license_key`, `device_id` で十分
- 将来は `device`, `challenge`, `server_signature` を追加できるようにする

### 19.3 商品画像の責務範囲

- `image_path` は保持対象
- 実ファイル保管を業務 API に含めるかは未決

### 19.4 バックアップ世代管理

- 現行クライアント互換だけなら product_key ごとの最新 1 件で足りる
- 運用要件次第で世代管理を拡張する

---

## 20. 要約

このサーバー設計で最も重要なのは次の 4 点です。

- 業務 API、バックアップ API、ライセンス API の責務を混ぜないこと
- クライアントが期待する JSON 形を崩さないこと
- 同期競合とバックアップ復元後の整合を `server_modified_at` 中心で保つこと
- ライセンス API は共有文書ではなく現行クライアント互換を最優先すること

この文書を基準に実装すれば、現行 Flutter クライアントと接続可能な最小サーバー群を段階的に構築できます。