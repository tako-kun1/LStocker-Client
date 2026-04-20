# Inventory Backup Server Handoff

この文書は、LStocker Client の現行実装を前提として、バックアップサーバー側ソフトウェアを開発している AI / 実装担当へ渡すための要約仕様です。

現在のバックアップ機能は、過去の「商品・在庫の双方向同期」ではなく、次の方針へ寄せています。

- バックアップ対象は在庫情報のみ
- バックアップの識別キーはプロダクトキー
- 通常運用では、端末からサーバーへ在庫スナップショットをアップロードする
- プロダクトキー認証成功時に、そのキーに紐づく最新バックアップをサーバーからダウンロードする

## 1. 重要な結論

バックアップサーバー側は、少なくとも次の 2 API を受ける必要があります。

- `POST /api/v1/backups/inventories/upload`
- `POST /api/v1/backups/inventories/latest`

また、クライアントは現在 `product_key` をトップレベルに持つ JSON を送ります。

## 2. バックアップ対象

### 含むもの

- 在庫情報
- バックアップ識別用の `product_key`

### 含まないもの

- 商品マスタ
- 部門マスタ
- 通知設定
- アプリ設定
- ライセンス状態そのもの
- 更新チェック関連情報

注意:

- 商品マスタはバックアップ対象外です。
- そのため、バックアップ復元後に商品マスタが端末に無い場合、在庫一覧は JAN コードベースまたは「未登録商品」として表示される可能性があります。

## 3. アップロードのタイミング

現行クライアントでサーバーへ在庫バックアップを送るタイミングは次です。

- 設定画面の「今すぐ在庫バックアップを保存する」ボタン押下時

参照:

- [lib/views/settings_screen.dart](lib/views/settings_screen.dart)
- [lib/services/inventory_backup_service.dart](lib/services/inventory_backup_service.dart)

現時点では自動定期アップロードはありません。

## 4. ダウンロードのタイミング

現行クライアントでサーバーから最新バックアップを取得するタイミングは次です。

- プロダクトキー認証成功直後

流れ:

1. ユーザーがプロダクトキーを入力する
2. ライセンス認証サーバーで認証に成功する
3. その後、バックアップサーバーへ `product_key` を使って最新在庫バックアップを問い合わせる
4. 返ってきた在庫一覧でローカル在庫を全置換する

参照:

- [lib/views/license_activation_screen.dart](lib/views/license_activation_screen.dart)
- [lib/services/product_key_service.dart](lib/services/product_key_service.dart)
- [lib/services/inventory_backup_service.dart](lib/services/inventory_backup_service.dart)
- [lib/services/database_helper.dart](lib/services/database_helper.dart)

## 5. 現行アップロード request 仕様

エンドポイント:

- `POST /api/v1/backups/inventories/upload`

現行クライアント request body:

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

### フィールド意味

- `product_key`
  - バックアップの論理キー
  - 同じプロダクトキーに対して最新スナップショットを保存する前提
- `inventories[]`
  - 端末内の在庫一覧

### `inventories[]` の現行フィールド

- `id`
  - ローカル在庫 ID
  - サーバー側では必ずしも主キーとして使わなくてよい
- `jan_code`
  - 商品識別用の JAN コード
- `quantity`
  - 数量
- `expiration_date`
  - 賞味期限
- `registration_date`
  - 在庫登録日
- `is_archived`
  - 対応済み / 完売などのアーカイブ状態

### サーバー実装上の推奨

- 少なくとも `product_key`, `jan_code`, `quantity`, `expiration_date` を保存対象とする
- `registration_date` と `is_archived` も受け入れる
- `id` は参考値として扱い、サーバー内部 ID と分離してよい
- 同じ `product_key` に対しては「最新スナップショット」を上書き保存する運用が安全

## 6. 現行ダウンロード request 仕様

エンドポイント:

- `POST /api/v1/backups/inventories/latest`

現行クライアント request body:

```json
{
  "product_key": "ABCD-EFGH-IJKL-MNOP"
}
```

期待する意味:

- 指定 `product_key` に対応する最新在庫バックアップを 1 件返す

## 7. 現行ダウンロード response 仕様

クライアントはかなり緩く受ける実装になっています。

- ルート直下に `inventories` がある形
- または `data.inventories`
- または `data.items`
- または `data.records`

いずれかの配列があれば読み取ります。

推奨 response 例:

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
    "updated_at": "2026-04-19T12:00:00Z"
  }
}
```

### クライアントが現在読むフィールド

各在庫オブジェクトについて:

- `id`
- `jan_code` または `janCode`
- `quantity`
- `expiration_date` または `expirationDate`
- `registration_date` または `registrationDate`
- `is_archived` または `isArchived`

### クライアントの復元動作

- 返却された在庫一覧でローカル `inventories` テーブルを全置換する
- 復元後、ローカルの inventory sync queue は削除する

つまり、差分マージではなくスナップショット復元として扱われます。

## 8. 疎通確認

設定画面の接続確認では次を順に試します。

- `GET /health`
- 失敗時は `GET /`

したがって、最低でも `/health` または `/` のどちらかで正常応答できると運用しやすいです。

参照:

- [lib/services/backup_server_service.dart](lib/services/backup_server_service.dart)

## 9. バックアップサーバー側で最低限必要なこと

1. `product_key` 単位で最新在庫バックアップを保存できること
2. 同じ `product_key` に対して最新バックアップ 1 件を取得できること
3. `inventories` 配列の JSON を保存・返却できること
4. `JANコード / 賞味期限 / 数量` を少なくとも失わないこと
5. `registration_date` と `is_archived` が来ても拒否しないこと
6. 接続確認用に `/health` または `/` へ応答できること

## 10. サーバー実装の簡略方針

最小実装なら、次のような設計で足ります。

### テーブル例

- `inventory_backups`
  - `id`
  - `product_key`
  - `payload_json`
  - `item_count`
  - `created_at`
  - `updated_at`

### 動作例

- upload:
  - `product_key` をキーに既存レコードを upsert
  - `payload_json` に inventories 配列をそのまま保存
- latest:
  - `product_key` で 1 件返す

これは正規化不足でも、まずクライアント互換を成立させるには十分です。

## 11. 受け入れ基準

バックアップサーバー実装は、少なくとも次を満たしてください。

1. クライアントから `product_key` と `inventories[]` を受け取れる
2. `product_key` を指定すると最新在庫バックアップを返せる
3. 認証成功直後のバックアップ復元でクライアントがエラーにならない
4. 在庫 0 件でも正常応答できる
5. `registration_date` と `is_archived` を含む request を拒否しない
6. 商品マスタ未登録でもクライアントの在庫表示が壊れない前提を理解している

## 12. 補足

- 現在のクライアント実装は、概念上は「在庫情報とプロダクトキーのバックアップ」です。
- ただし厳密には、在庫情報として `registration_date` と `is_archived` も送っています。
- 将来的に送信項目を `JANコード / 賞味期限 / 数量` のみに絞る場合は、クライアント側の [lib/services/inventory_backup_service.dart](lib/services/inventory_backup_service.dart) も合わせて修正が必要です。