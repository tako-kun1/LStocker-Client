# LStocker Client

LStocker Client は、店舗で扱う商品情報と在庫情報を端末ローカルに保持しつつ、バックアップサーバーと同期して運用する Flutter アプリです。オフライン運用を前提にしながら、商品マスタ・在庫・通知・ライセンス認証を 1 つのクライアントで扱う構成になっています。

## リリース情報

- 現在バージョン: `1.0.5-dev9+15`
- 対応プラットフォーム: Android / iOS / Windows
- 現行の主要要素:
	- 商品・在庫のローカル DB 運用
	- プロダクトキー単位の在庫バックアップ保存・復元
	- プロダクトキー認証とライセンス状態確認
	- 販売制限開始日が近い在庫の通知
	- バックアップサーバー接続先の保持と接続確認

## ソフトウェア仕様

### 目的

- 店舗端末で商品情報と在庫情報を登録・更新する
- ネットワーク未接続時でもローカル DB を使って継続運用する
- プロダクトキー認証時に、同じキーに紐づく最新の在庫バックアップを取得する
- ライセンス認証済み端末のみ利用可能にする

### 構成の考え方

- ローカル DB:
	- `sqflite` を使用し、商品・在庫・同期キューを端末内へ保存します。
- バックアップ同期 API:
	- 在庫バックアップのアップロード、最新バックアップのダウンロード、疎通確認を扱う API です。
	- 接続先は設定画面のバックアップサーバー URL を優先し、未設定時は `dart-define` と `AppConfig` の既定値を使います。
- ライセンス認証サーバー:
	- プロダクトキー有効化と heartbeat を担当します。
- バックアップサーバー設定:
	- 設定画面で保持する在庫バックアップ先の接続先です。
	- 接続確認 UI とバックアップ送信先として使用します。

### 主な機能

- 商品登録・編集
	- JAN コード入力またはバーコードスキャン
	- 商品画像の撮影と保存
	- DEPT 番号、販売許容期間、商品説明の保持
- 在庫登録・管理
	- 商品検索またはスキャンによる在庫追加
	- 賞味期限、登録日、数量の保存
	- 完売または対応済み在庫のアーカイブ
- 通知
	- 販売制限開始日が近い在庫を抽出
	- Android ローカル通知を表示
	- ホーム画面の通知ボタンに赤バッジを表示
- バックアップ同期
	- バックアップ対象は在庫状況データのみ
	- 手動で最新の在庫スナップショットをサーバーへ保存
	- プロダクトキー認証成功時に同じキーの最新バックアップを自動復元
- ライセンス管理
	- 未認証時は起動を停止してプロダクトキー入力を要求
	- 設定画面から再登録と状態確認が可能
- 更新確認
	- 更新メタデータ API または GitHub Releases ベースの更新確認
	- 必須更新時は起動継続を止めることが可能

### 起動シーケンス

1. DEPT 定義、設定、同期サービスを初期化
2. 旧オフライン DB の移行確認
3. ライセンス状態を確認
4. 更新情報のキャッシュを確認
5. 商品・在庫をローカル DB から読み込み
6. プロダクトキー認証直後に在庫バックアップを自動復元

### 画面構成

- `StartupScreen`
	- 初期化、移行確認、ライセンス確認、更新確認
- `HomeScreen`
	- 商品登録、商品一覧、在庫登録、在庫状況、通知、設定への導線
- `NotificationScreen`
	- 期限間近在庫の一覧表示
- `SettingsScreen`
	- バックアップサーバー設定、通知、ライセンス、アップデート、在庫バックアップ設定

## 使い方

### 基本運用

1. アプリ起動後、必要ならプロダクトキーを認証する
2. 商品登録画面で商品マスタを登録する
3. 在庫登録画面で商品を選び、賞味期限と数量を登録する
4. 在庫状況確認画面で登録済み在庫を確認する
5. 必要に応じて設定画面からバックアップサーバーとの手動同期を実行する
5. 必要に応じて設定画面から現在の在庫状況を手動バックアップする

### 設定画面の見方

- バックアップサーバー設定:
	- バックアップ用接続先 URL を保存します。
	- 「接続確認」ボタンで `/health` または `/` への応答を確認します。
- 通知設定:
	- プッシュ通知の有効・無効を切り替えます。
- ライセンス設定:
	- 登録済みキーの確認、再登録、状態確認を行います。
	- 認証成功時に、そのプロダクトキーに紐づく最新の在庫バックアップを自動取得します。
- アップデート設定:
	- 起動時の自動確認を切り替え、手動確認もできます。
	- `UPDATE_METADATA_URL` が設定されていればその JSON を優先し、未設定時は GitHub Releases を参照します。
- 在庫バックアップ設定:
	- 現在の在庫状況をバックアップサーバーへ手動送信します。

### 利用上の注意

- バックアップサーバー URL を設定すると、同期先としてその URL が優先されます。
- バックアップサーバー URL を設定すると、在庫バックアップ先としてその URL が優先されます。
- バックアップサーバー URL 未設定時は、`APP_ENV` と `API_BASE_URL_*` の `dart-define` 既定値を使用します。
- ライセンス未認証のままではアプリを継続利用できません。
- プロダクトキー認証時に取得できるのは、そのキーに紐づく最新の在庫バックアップのみです。
- 通知は Android ローカル通知を使用するため、端末側の通知許可が必要です。
- オフライン時はローカル DB に保存されますが、サーバー反映には後続の同期が必要です。
- 商品マスタはバックアップ対象外のため、在庫バックアップ復元後に未登録商品として表示される場合があります。

## セットアップ

### 前提

- Flutter SDK `^3.11.3`
- Android Studio または同等の Flutter 開発環境

### 開発環境準備

```bash
flutter pub get
```

### 実行

```bash
flutter run
```

### リリースビルド

```bash
flutter build apk --release
```

## 環境変数

必要に応じて `--dart-define` で接続先や環境を上書きできます。

- `APP_ENV` (`dev` / `stg` / `prod`)
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

更新メタデータ API の想定 JSON 例:

```json
{
	"latest_version": "1.0.5",
	"min_supported_version": "1.0.4",
	"force_update": false,
	"release_notes": "在庫同期と更新処理を改善しました。",
	"apk_url": "https://updates.example.com/downloads/lstocker-1.0.5.apk",
	"page_url": "https://updates.example.com/downloads",
	"published_at": "2026-04-19T09:00:00Z"
}
```

## 開発コマンド

### 解析

```bash
flutter analyze
```

### テスト

```bash
flutter test
```

### コード生成

```bash
dart run build_runner build --delete-conflicting-outputs
```

## ドキュメント

- ライセンスプロトコル: `docs/license-protocol.md`
- プロダクトキー認証仕様: `docs/product-key-auth-spec-share.md`
- バックアップサーバー仕様: `docs/product-backup-server-spec.md`
- バックアップサーバー互換修正指示: `docs/backup-server-compatibility-fix-instructions.md`
- 在庫バックアップ実装引き継ぎ: `docs/inventory-backup-server-handoff.md`

## ディレクトリ構成

```text
lib/
	main.dart
	models/
	providers/
	services/
	views/
assets/
	dept.txt
docs/
	license-protocol.md
	product-backup-server-spec.md
```

## 補足

- `assets/dept.txt` を読み込み、DEPT 入力の検証に利用します。
- 起動時に旧ローカル DB が見つかった場合、移行確認ダイアログを表示します。
- リリース APK は `build/app/outputs/flutter-apk/app-release.apk` に生成されます。
