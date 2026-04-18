# Product Database Backup Server Spec

この文書は、LStocker Client が扱う商品・在庫データをサーバー側で安全に保存、バックアップ、復旧するための仕様設計書です。

現行クライアントはローカルの Sqflite を正としつつ、業務APIサーバーに対して商品・在庫同期を行います。本仕様は、その業務APIサーバーおよびバックアップ運用基盤の責務を整理したものです。

## 1. 目的

- 商品データ、在庫データ、同期監査情報をサーバー側で保全する
- 障害、誤更新、誤削除、運用ミスから復旧できるようにする
- クライアント既存APIとの整合性を保ちながら運用可能にする
- 本番系とバックアップ系の役割を明確にする

## 2. スコープ

本仕様に含むもの:

- 商品、在庫、部門マスタのサーバー保管
- フルバックアップ、増分バックアップ、世代管理
- 復旧ジョブ、監査ログ、整合性確認
- 管理者向けバックアップ運用API
- クライアント同期APIとの関係整理

本仕様に含まないもの:

- プロダクトキー認証サーバーの仕様
- モバイル端末上の Sqflite ファイルの直接吸い上げ
- OS レベルのディスク暗号化詳細

## 3. 前提

現行クライアントが利用する業務APIは以下です。

- `GET /health`
- `GET /info`
- `POST /activate`
- `GET /products`
- `POST /products/sync`
- `GET /inventories`
- `POST /inventories/sync`
- `GET /departments`

クライアントはローカルDBを保持し、同期時に以下のデータモデルを送受信します。

- 商品
  - `jan_code`
  - `name`
  - `description`
  - `image_path`
  - `dept_number`
  - `sales_period`
  - `operation`
- 在庫
  - `id`
  - `jan_code`
  - `quantity`
  - `expiration_date`
  - `registration_date`
  - `is_archived`
  - `operation`

したがって、サーバー側バックアップは「クライアントが最終的に同期する正規化済み業務データ」を保全対象とするのが基本方針です。

## 4. 全体アーキテクチャ

推奨構成は以下です。

1. 業務APIサーバー
2. 主DB
3. バックアップストレージ
4. 復旧用の管理API
5. 監査ログ保存先

論理構成:

- クライアントは業務APIサーバーにのみ接続する
- 業務APIサーバーは主DBへ書き込みを行う
- バックアップジョブは主DBからスナップショットまたは論理ダンプを取得する
- バックアップ成果物はオブジェクトストレージまたは別ディスクへ保存する
- 復旧処理は管理API経由で明示的に実行する

補足:

- クライアントの設定画面に入れる「サーバー設定」は業務API接続先であり、バックアップストレージ自体を直接指すものではない
- バックアップサーバーを別ホスト化する場合も、クライアント接続先は通常は業務APIの公開URLとする

## 5. データ責務

### 5.1 保全対象

- `products`
- `inventories`
- `departments`
- 同期監査テーブル
- バックアップジョブ管理テーブル
- 復旧ジョブ管理テーブル

### 5.2 非保全対象

- クライアント端末固有の一時状態
- クライアント内の SharedPreferences 一時情報
- モバイル端末内の未同期キューそのもの

ただし、未同期差分と競合解析のため、サーバー側では受信した同期リクエストの要約ログを監査目的で保持することを推奨します。

## 6. 主DBの推奨論理スキーマ

### 6.1 products

- `jan_code` PK
- `name`
- `description`
- `image_path`
- `dept_number`
- `sales_period`
- `is_deleted`
- `server_modified_at`
- `modified_by`
- `created_at`
- `updated_at`

### 6.2 inventories

- `id` PK
- `jan_code` FK -> `products.jan_code`
- `quantity`
- `expiration_date`
- `registration_date`
- `is_archived`
- `server_modified_at`
- `modified_by`
- `created_at`
- `updated_at`

### 6.3 departments

- `dept_number` PK
- `name`
- `updated_at`

### 6.4 sync_audit_logs

- `id` PK
- `entity_type`
- `entity_id`
- `operation`
- `request_id`
- `client_timestamp`
- `server_timestamp`
- `applied`
- `conflict_type`
- `actor_user_id`
- `payload_digest`
- `created_at`

### 6.5 backup_jobs

- `job_id` PK
- `backup_type` (`full`, `incremental`, `schema_only`)
- `status` (`queued`, `running`, `succeeded`, `failed`, `expired`)
- `started_at`
- `completed_at`
- `snapshot_time`
- `artifact_uri`
- `artifact_checksum`
- `artifact_size_bytes`
- `retention_until`
- `error_message`

### 6.6 restore_jobs

- `job_id` PK
- `backup_job_id`
- `restore_mode` (`full_replace`, `point_in_time`, `dry_run`)
- `status`
- `requested_at`
- `started_at`
- `completed_at`
- `requested_by`
- `target_environment`
- `validation_summary`
- `error_message`

## 7. 同期APIとの整合ルール

既存クライアント互換性のため、以下を守る必要があります。

- `/products/sync` と `/inventories/sync` のレスポンス形式は維持する
- `server_timestamp` はサーバー正時刻の ISO8601 を返す
- `server_modified_at` は変更行ごとに必須管理する
- 競合時はクライアントが解釈可能な `conflicts` 配列を返す
- 在庫新規作成時は `created_ids` マッピングを返す

バックアップ設計上の重要点:

- バックアップ復元後も `server_modified_at` が単調に壊れないこと
- 復元したデータが次回同期時に全件競合を起こしにくいこと
- `modified_by` と監査ログが可能な限り保全されること

## 8. バックアップ方針

### 8.1 バックアップ種別

- 日次フルバックアップ
- 15分ごとの増分バックアップ
- スキーマバックアップ
- 重要操作前のオンデマンドバックアップ

### 8.2 保存形式

推奨優先順位:

1. DBネイティブな物理バックアップ
2. 論理ダンプ JSONL/CSV/SQL
3. スキーマダンプ

最低要件:

- 復元可能性が検証済みであること
- チェックサムを持つこと
- 作成時刻と対象DB識別子が埋め込まれること

### 8.3 保持期間

- 日次フル: 35日
- 週次フル: 12週
- 月次フル: 12か月
- 増分: 14日
- 監査ログ: 365日以上

## 9. バックアップ実行要件

- 実行中も業務APIは原則継続提供する
- スナップショット整合性が担保される方式を採用する
- バックアップ開始と終了は監査ログに必ず残す
- 同時実行制御を行い、同一対象への重複実行を防ぐ
- 成果物のチェックサムを計算して保存する
- 完了後に簡易検証を行う

簡易検証の最低項目:

- ダンプファイルが開ける
- products 件数取得に成功する
- inventories 件数取得に成功する
- checksum が一致する

## 10. 復旧要件

### 10.1 復旧モード

- `dry_run`
  - 実際には反映せず、件数差分と実行可否だけ返す
- `full_replace`
  - 対象DBをバックアップ時点の内容で全置換する
- `point_in_time`
  - フル + 増分から指定時刻へ戻す

### 10.2 復旧前チェック

- 対象環境が正しいこと
- 実行者が管理権限を持つこと
- 現行DBの緊急退避バックアップを取得すること
- 復旧対象バックアップの checksum が一致すること

### 10.3 復旧後チェック

- products 件数
- inventories 件数
- departments 件数
- 主要インデックス存在確認
- `/health` 正常応答
- `/products` と `/inventories` の基本取得が成功すること

## 11. 管理API仕様

これらはクライアント公開APIではなく、管理者または内部運用用APIです。

### 11.1 バックアップ作成

- `POST /admin/backups`

Request:

```json
{
  "backup_type": "full",
  "reason": "pre-maintenance",
  "requested_by": "admin@example.com"
}
```

Response:

```json
{
  "status": "success",
  "data": {
    "job_id": "bkp_20260418_0001",
    "status": "queued"
  },
  "timestamp": "2026-04-18T10:00:00Z"
}
```

### 11.2 バックアップ一覧取得

- `GET /admin/backups?status=succeeded&limit=50`

Response:

```json
{
  "status": "success",
  "data": {
    "items": [
      {
        "job_id": "bkp_20260418_0001",
        "backup_type": "full",
        "status": "succeeded",
        "snapshot_time": "2026-04-18T10:00:10Z",
        "artifact_uri": "s3://bucket/backups/prod/full/bkp_20260418_0001.dump",
        "artifact_checksum": "sha256:...",
        "artifact_size_bytes": 10485760,
        "retention_until": "2026-05-23T00:00:00Z"
      }
    ]
  },
  "timestamp": "2026-04-18T10:01:00Z"
}
```

### 11.3 復旧ドライラン

- `POST /admin/restores`

Request:

```json
{
  "backup_job_id": "bkp_20260418_0001",
  "restore_mode": "dry_run",
  "target_environment": "staging",
  "requested_by": "admin@example.com"
}
```

Response:

```json
{
  "status": "success",
  "data": {
    "job_id": "rst_20260418_0001",
    "status": "queued"
  },
  "timestamp": "2026-04-18T10:05:00Z"
}
```

### 11.4 復旧結果取得

- `GET /admin/restores/{job_id}`

Response:

```json
{
  "status": "success",
  "data": {
    "job_id": "rst_20260418_0001",
    "status": "succeeded",
    "restore_mode": "dry_run",
    "validation_summary": {
      "products_before": 5230,
      "products_after": 5230,
      "inventories_before": 24118,
      "inventories_after": 24118,
      "warnings": []
    }
  },
  "timestamp": "2026-04-18T10:06:00Z"
}
```

## 12. エラー仕様

管理APIも業務API同様、共通 envelope を推奨します。

```json
{
  "status": "error",
  "error": {
    "code": "BACKUP_JOB_FAILED",
    "message": "backup process failed"
  },
  "timestamp": "2026-04-18T10:07:00Z"
}
```

代表エラーコード:

- `BACKUP_ALREADY_RUNNING`
- `BACKUP_TARGET_UNAVAILABLE`
- `BACKUP_ARTIFACT_CORRUPTED`
- `RESTORE_PRECHECK_FAILED`
- `RESTORE_FORBIDDEN`
- `RESTORE_TARGET_MISMATCH`
- `RETENTION_POLICY_VIOLATION`

## 13. セキュリティ要件

- 管理APIは一般クライアント用アクセストークンと分離する
- 管理APIは管理者ロールまたは内部ネットワークからのみ許可する
- バックアップ成果物は保存時暗号化を行う
- 署名付き URL を使う場合は短命にする
- 監査ログに実行者、理由、対象、結果を残す
- 復旧は多要素承認または二段階承認を推奨する

## 14. 可観測性

最低限のメトリクス:

- 最終成功バックアップ時刻
- 直近バックアップ所要時間
- 直近バックアップサイズ
- バックアップ失敗回数
- 復旧試行回数
- 復旧失敗回数
- products 件数
- inventories 件数

最低限のログ:

- バックアップ開始
- バックアップ完了
- バックアップ失敗
- 復旧開始
- 復旧完了
- 復旧失敗
- 監査イベント

## 15. 運用ルール

- 本番復旧の前に必ず dry-run を行う
- 本番復旧の前に現行DBの退避バックアップを取得する
- 定期的に staging へ復元訓練を行う
- バックアップの checksum 検証を定期実行する
- 保存期限切れデータの削除も監査対象にする

## 16. クライアント影響範囲

この仕様によりクライアントへ直接要求する変更は原則ありません。

ただし、以下は将来的にクライアント変更候補です。

- `/info` にバックアップ世代や保守モード情報を出す
- 同期エラー時に「サーバー復旧中」を判別できるコードを増やす
- 復旧直後の強制再同期フラグを受け取る

## 17. 実装優先順位

Phase 1:

- 主DBの正規化保存
- 日次フルバックアップ
- バックアップ一覧 API
- 監査ログ

Phase 2:

- 増分バックアップ
- dry-run restore
- 復旧結果検証

Phase 3:

- point-in-time restore
- 自動整合性検証
- 世代最適化と長期保管

## 18. 受け入れ基準

- 商品と在庫のバックアップが日次で自動成功する
- 直近バックアップ成果物の checksum を検証できる
- staging で dry-run と実復旧が成功する
- 復旧後に `/health`, `/products`, `/inventories` が正常応答する
- クライアントの既存同期契約を壊さない

## 19. 共有時の要点

サーバー実装担当へ伝えるべき要点は以下です。

- クライアントはローカル Sqflite を持つが、サーバーは同期後の業務データの保全責任を持つ
- クライアント設定のサーバーURLは業務API接続先であり、バックアップストレージ接続先ではない
- バックアップ設計で最重要なのは、復旧後も同期契約を壊さないこと
- `server_modified_at`, `server_timestamp`, `created_ids`, `conflicts` の整合性は特に重要