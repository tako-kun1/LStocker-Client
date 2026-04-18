# Backup Server Compatibility Fix Instructions

この文書は、最新の LStocker Backup Server README を、現行 LStocker Client 契約と再照合した結果に基づく改訂版の修正指示です。

前回までに指摘した大半の不整合は解消されています。現時点では、重大度の高い残件は少数です。

結論として、引き続き修正主体はクライアント側ではなくサーバー側です。

## 1. 前提

基準とするクライアント実装:

- [lib/services/auth_service.dart](lib/services/auth_service.dart)
- [lib/services/api_service.dart](lib/services/api_service.dart)
- [lib/models/api_models.dart](lib/models/api_models.dart)
- [lib/services/sync_service.dart](lib/services/sync_service.dart)

今回の修正指示は、最新 README に残っている差分のみを対象とします。

## 2. 現在の評価

既に整っている点:

- `/auth/login` と `/auth/refresh` が README に記載されている
- Bearer token 前提が README に反映されている
- `GET /products` と `GET /inventories` に `total_count` と `server_timestamp` がある
- `GET /departments` に `server_timestamp` がある
- `modified_by` が整数で記述されている
- `/activate` が空 body 互換になっている
- `created_ids[].client_temp_id` が README に反映されている

残っている主要差分:

1. `/inventories/sync` の request 例が、現行クライアントの送信内容と一致していない
2. `POST /products` / `POST /inventories` の request body 説明が、現行クライアントの request DTO と一致していない

## 3. 残件1: `/inventories/sync` request 例の修正

### 3.1 問題

最新 README では、`/inventories/sync` の request 例に以下のような項目があります。

- `client_temp_id`
- `id: null`

しかし、現行クライアントの `InventoryUpdateDto` には `client_temp_id` は存在しません。[lib/models/api_models.dart](lib/models/api_models.dart)

また、実際のクライアントは在庫作成時にローカル DB へ先に insert した後、その採番済み `id` を payload に含めて同期します。[lib/services/sync_service.dart](lib/services/sync_service.dart)

したがって、README の request 例は現行クライアントとは不一致です。

### 3.2 修正指示

README の `/inventories/sync` request 例は、以下の方針で修正してください。

- request body から `client_temp_id` を削除する
- create 時でも `id` は `null` 前提にしない
- 現行クライアント互換としては、ローカル採番済みの `id` を受け取れる前提にする

### 3.3 推奨する README 記述

```json
{
  "last_sync_timestamp": "2026-04-18T00:00:00Z",
  "client_timestamp": "2026-04-18T12:00:00Z",
  "inventories": [
    {
      "id": 42,
      "jan_code": "4900000000001",
      "quantity": 10,
      "expiration_date": "2026-05-01T00:00:00.000",
      "registration_date": "2026-04-18T00:00:00.000",
      "is_archived": false,
      "operation": "create"
    }
  ]
}
```

### 3.4 補足

`created_ids[].client_temp_id` を response に残すこと自体は問題ありません。README では次のように整理してください。

- request は現行クライアント互換で `client_temp_id` 非依存
- response は将来互換も考慮し `created_ids[].client_temp_id` を返してよい

ただし、サーバー実装で `client_temp_id` を必須扱いにしてはいけません。

## 4. 残件2: CRUD request body 説明の修正

### 4.1 問題

最新 README では、以下のような説明があります。

- `POST /products`: `operation` を除く `ProductDto` 相当
- `POST /inventories`: `operation` と `id` を除く在庫 DTO 相当

しかし、現行クライアントが送っているのは DTO ではなく update request です。

- 商品は `ProductUpdateDto`
- 在庫は `InventoryUpdateDto`

参照先:

- [lib/services/api_service.dart](lib/services/api_service.dart)
- [lib/models/api_models.dart](lib/models/api_models.dart)

### 4.2 修正指示

README の CRUD request body 説明は、DTO 相当という曖昧な表現をやめ、以下のように明記してください。

- `POST /products` は現行クライアント互換として `ProductUpdateDto` と同形の JSON を受け付ける
- `POST /inventories` は現行クライアント互換として `InventoryUpdateDto` と同形、またはそのサブセットを受け付ける

### 4.3 推奨する README 記述

#### POST /products

```json
{
  "jan_code": "4900000000001",
  "name": "Sample Product",
  "description": "example",
  "image_path": null,
  "dept_number": 1,
  "sales_period": 30,
  "operation": "create"
}
```

補足:

- サーバー側で `operation` を無視してもよい
- 少なくとも現行クライアントが送る shape を拒否しないこと

#### POST /inventories

```json
{
  "id": 42,
  "jan_code": "4900000000001",
  "quantity": 10,
  "expiration_date": "2026-05-01T00:00:00.000",
  "registration_date": "2026-04-18T00:00:00.000",
  "is_archived": false,
  "operation": "create"
}
```

補足:

- `operation` を無視してもよい
- `id` は create でも送られる可能性がある前提で受け付けること

## 5. 実装担当への修正優先順位

### P1: 先に直す

1. `/inventories/sync` request 例から `client_temp_id` 前提を外す
2. `/inventories/sync` create request を `id` 送信ありでも受け付ける前提に修正する
3. `POST /products` の request body 説明を `ProductUpdateDto` 基準に修正する
4. `POST /inventories` の request body 説明を `InventoryUpdateDto` 基準に修正する

### P2: 次に直す

1. README に「現行クライアント互換では request と response で項目が完全対称ではない箇所がある」ことを注記する
2. `created_ids[].client_temp_id` を response へ残す理由を README に 1 行補足する

## 6. 受け入れ基準

以下を満たしたら、現時点の README はクライアント互換の観点で概ね妥当です。

1. `/inventories/sync` request 例に `client_temp_id` が含まれていない
2. `/inventories/sync` request 例が `id` 送信ありの現行クライアント挙動と矛盾しない
3. `POST /products` の request body 説明が `ProductUpdateDto` 基準になっている
4. `POST /inventories` の request body 説明が `InventoryUpdateDto` 基準になっている
5. 既に整った項目である `/auth/login`, `/auth/refresh`, `server_timestamp`, `total_count`, `modified_by`, `/activate` 互換が崩れていない

## 7. 補足

- 現在の README は前回よりかなり改善されているため、全面的な書き直しは不要です
- 今回の修正は「残件の微修正」です
- クライアントコード側を直す必要は現時点ではありません