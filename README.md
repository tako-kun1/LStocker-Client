# LStocker Client

LStocker Client は、店舗で使う商品情報と在庫情報を端末内で管理するアプリです。ネットワークが不安定でもローカルDBで運用を続けられ、必要に応じてライセンス認証やアップデート確認を行えます。

## このアプリでできること

- 商品マスタの登録・編集
- 在庫の登録・一覧確認
- 期限が近い在庫の通知確認
- 登録済み商品一覧の検索・DEPT絞り込み
- CSVからの商品マスタ取り込み
- ライセンス状態の確認と再登録
- アプリの更新確認

## 現在のバージョン

- `1.1.0+21`

## 使い始める手順

1. アプリを起動する
2. 必要に応じてプロダクトキーを認証する
3. 商品登録で商品マスタを整備する
4. 在庫登録で賞味期限・数量を登録する
5. 在庫状況確認や通知画面で日々の状態を確認する
6. 必要なときに設定画面からCSV取込や更新確認を実行する

## 画面ごとの使い方

### ホーム画面

- 商品登録
- 登録商品一覧
- 在庫登録
- 在庫状況確認
- 通知
- 設定

各機能への入口として使います。

### 商品登録

- JANコードを入力して商品を登録できます
- 商品名、DEPT番号、許容期間、説明、画像を設定できます
- 既存商品の編集にも使えます

### 登録商品一覧

- 登録済み商品の一覧を確認できます
- 右上の更新ボタンでローカルデータを再読み込みできます
- 検索欄で以下を対象に絞り込みできます
  - 商品名
  - JANコード
  - 商品説明
  - DEPT名
  - DEPT番号
- DEPT単位での表示絞り込みもできます

### 在庫登録

- 商品を選んで在庫を登録できます
- 数量、賞味期限、登録日などを保存できます

### 在庫状況確認

- 現在の在庫状況を確認できます
- 期限が近い在庫の確認や運用判断に使います

### 通知

- 販売制限開始日が近い在庫を確認できます
- Androidではローカル通知も利用します

### 設定

#### バックアップサーバー設定

- 接続先URLを保存できます
- 接続確認ボタンで疎通確認ができます

#### 通知設定

- プッシュ通知の有効・無効を切り替えられます

#### ライセンス設定

- 登録済みプロダクトキーの確認
- 再登録
- ライセンス状態確認

#### アップデート設定

- 起動時の自動確認を切り替えられます
- 手動でアップデート確認を実行できます

#### CSV商品取込設定

- 取込元は `https://lsdb.nazono.cloud/db.csv` 固定です
- 起動時に1回、以後は1日ごとに自動取込します
- 手動で今すぐCSV取込を実行できます
- 取込中は全画面のプログレス表示が出て、他操作は一時的に受け付けません
- CSVが `404` の場合は、取込をスキップしてアプリはそのまま継続します

#### 在庫バックアップ設定

- 現在、在庫バックアップ機能は一時的に無効化中です

## CSV取込の使い方

### 文字コード

- `UTF-8` を使用してください
- 推奨は `UTF-8 BOMなし` です

### 対応ヘッダー

利用できるヘッダー名は以下です。大文字小文字は区別されません。

| 項目 | 利用できるヘッダー |
|---|---|
| JANコード | `jancode` / `jan_code` / `jan` |
| 商品名 | `name` / `product_name` |
| DEPT番号 | `deptnumber` / `dept_number` / `dept` |
| 許容期間 | `salesperiod` / `sales_period` |
| 商品説明 | `description` / `detail` |
| 画像パス | `imagepath` / `image_path` |

### 注意点

- JAN列は必須です
- 未知の追加列は無視されます
- 日本語ヘッダーには未対応です
- 既に登録済みのJANコードは更新せずスキップします

## 利用時の注意

- ライセンス未認証のままでは継続利用できません
- オフライン時もローカルDBで操作できます
- 商品マスタはCSV取込または手動登録で管理します
- 現在、在庫バックアップは停止中です

## 開発環境での実行

### 前提

- Flutter SDK `^3.11.3`
- Android Studio または同等のFlutter開発環境

### 初期セットアップ

```bash
flutter pub get
```

### 実行

```bash
flutter run
```

### 解析

```bash
flutter analyze
```

### テスト

```bash
flutter test
```

### APKビルド

```bash
flutter build apk --release
```

生成先:

- `build/app/outputs/flutter-apk/app-release.apk`

## 環境変数

必要に応じて `--dart-define` で接続先を上書きできます。

- `APP_ENV`
- `API_BASE_URL_DEV`
- `API_BASE_URL_STG`
- `API_BASE_URL_PROD`
- `LICENSE_AUTH_SERVER_BASE_URL`
- `UPDATE_METADATA_URL`
- `UPDATE_FALLBACK_PAGE_URL`

例:

```bash
flutter run \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL_PROD=https://api.example.com \
  --dart-define=UPDATE_METADATA_URL=https://updates.example.com/api/mobile/latest \
  --dart-define=UPDATE_FALLBACK_PAGE_URL=https://updates.example.com/downloads \
  --dart-define=LICENSE_AUTH_SERVER_BASE_URL=https://auth.nazono.cloud:8443
```

## 関連ドキュメント

- `docs/license-protocol.md`
- `docs/product-key-auth-spec-share.md`
- `docs/product-backup-server-spec.md`
- `docs/backup-server-compatibility-fix-instructions.md`
- `docs/inventory-backup-server-handoff.md`
