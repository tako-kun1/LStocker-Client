# LStocker Client

LStocker Client は、店舗向けの商品情報・在庫情報を管理する Flutter アプリです。  
ローカル DB によるオフライン運用と、API サーバーとの同期機能を組み合わせて利用できます。

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
- Android / iOS / Web の各プラットフォームに対応したプロジェクト構成です。
