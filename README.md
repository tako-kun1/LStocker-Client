# LStocker Client

LStocker Client は、店舗向けの商品情報・在庫情報を管理する Flutter アプリです。  
ローカル DB によるオフライン運用と、API サーバーとの同期機能を組み合わせて利用できます。

## リリース情報

- 現在バージョン: `1.0.5-dev7+13`
- 主要追加機能:
	- プロダクトキー認証
	- 認証サーバー連携 (`https://auth.nazono.cloud:8443`)
	- 設定画面からのライセンス状態確認

## 主な機能

- 商品登録・編集
	- JAN コード入力 / バーコードスキャン
	- 商品画像のカメラ撮影
	- DEPT 番号、販売許容期間、商品説明の登録
- 在庫登録
	- JAN コード検索またはスキャンで商品特定
	- 賞味期限・数量の登録
- 在庫状況確認
	- 登録済み在庫の一覧確認
- 通知
	- 販売制限開始日が近い在庫を通知一覧で確認
- 設定
	- サーバー URL 設定
	- 同期タイミング・通知設定
	- プロダクトキー再登録
	- ライセンス状態確認 (heartbeat)

## 技術スタック

- Flutter / Dart (SDK: `^3.11.3`)
- 状態管理: Provider
- ローカル DB: sqflite
- HTTP 通信: dio
- 永続化設定: shared_preferences
- バーコードスキャン: mobile_scanner
- カメラ撮影: camera

## セットアップ

1. Flutter SDK をインストール
2. 依存関係を取得

```bash
flutter pub get
```

3. 実行

```bash
flutter run
```

## 環境変数 (dart-define)

必要に応じて `--dart-define` で接続先を上書きできます。

- `APP_ENV` (`dev` / `stg` / `prod`)
- `API_BASE_URL_DEV`
- `API_BASE_URL_STG`
- `API_BASE_URL_PROD`
- `LICENSE_AUTH_SERVER_BASE_URL` (既定: `https://auth.nazono.cloud:8443`)

例:

```bash
flutter run \
	--dart-define=APP_ENV=prod \
	--dart-define=API_BASE_URL_PROD=https://api.example.com \
	--dart-define=LICENSE_AUTH_SERVER_BASE_URL=https://auth.nazono.cloud:8443
```

## 開発でよく使うコマンド

- 解析

```bash
flutter analyze
```

- テスト

```bash
flutter test
```

- `json_serializable` のコード生成

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 画面遷移の概要

- 起動時: `StartupScreen`
	- 初回起動時に既存オフライン DB の取り込み確認
	- 未認証時はライセンス認証画面へ遷移
	- 商品・在庫データの初期読み込み
- ホーム: `HomeScreen`
	- 商品登録
	- 登録商品一覧
	- 在庫登録
	- 在庫状況確認
	- 通知
	- 設定

## API / 同期について

- 設定画面でサーバー URL を保存すると、起動時に API クライアントが初期化されます。
- 同期処理はローカルの同期キューを使って、商品・在庫を個別に同期します。
- JWT アクセストークンの更新 (refresh) に対応しています。

## ライセンス認証について

- 起動時にライセンス未認証の場合、`LicenseActivationScreen` でプロダクトキー認証が必要です。
- 認証 API:
	- `POST /api/v1/license/activate`
	- `POST /api/v1/license/heartbeat`
- 端末識別子 (`device_id`) とライセンス情報はローカルに保存されます。
- 詳細プロトコルは `docs/license-protocol.md` を参照してください。

## ディレクトリ構成 (抜粋)

```text
lib/
	main.dart
	models/
	providers/
	services/
	views/
assets/
	dept.txt
```

## 補足

- `assets/dept.txt` の DEPT 定義を読み込んで DEPT 入力を検証します。
- Android / iOS / Windows の各プラットフォームに対応したプロジェクト構成です。
