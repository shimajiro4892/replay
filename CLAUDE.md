# CLAUDE.md（replay）

macOS 用のオフライン動画キューアプリ Replay のフォーク。利用者はユーザー本人のみ。

## リポジトリ
- `origin`: `shimajiro4892/replay`（自分のフォーク。作業はここにプッシュする）
- `upstream`: `grinich/replay`（取得専用。push URL は `DISABLE` にしてある）
- 上流の取り込みは `git fetch upstream && git merge upstream/main`。取り込んで壊れたら、その時に直す方針。
- 作業は `main` に直接コミットしてよい（PR は必須ではない）。プッシュすると CI が動く。
- README・CONTRIBUTING のリンクと、自動更新の取得先（`Sources/Replay/AppUpdater.swift` の `releaseAPIURL`）は自分のリポジトリを指す。自分のリポジトリにはまだリリースがないので、自動更新は何も見つけない。

## 構成
- SwiftPM のみ（Xcode プロジェクトなし）。Swift 5.9、macOS 13 以上。
- ターゲット: `Replay`（本体、`Sources/Replay`）と `ReplayUpdater`（更新ヘルパー、`Sources/ReplayUpdater`）。
- 大きいファイル: `ContentView.swift`（UI）、`LocalVideoPlayer.swift`（プレーヤー）、`QueueStore.swift`、`DownloadEngine.swift`（yt-dlp・ffmpeg の呼び出し）。
- バージョンは `Resources/Info.plist`（`CFBundleShortVersionString` と `CFBundleVersion`）。

## ビルドとテスト
- ビルド: `swift build -c release`
- アプリの生成: `./scripts/build_app.sh` で `dist/Replay.app` を作る（アドホック署名）。yt-dlp・ffmpeg・deno は同梱されず、Homebrew のパス（`/opt/homebrew/bin`、`/usr/local/bin`）を探す。この Mac には Homebrew で入れてある。普段使いはこの開発ビルド。
- ツールを同梱した自己完結のアプリ: `./scripts/package_release.sh`（署名の環境変数がなければアドホック署名）。
- テスト: `./scripts/test.sh`。XCTest ではなく、`tools/*_check.swift` を `swiftc` でコンパイルして実行する方式。新しいテストを足すときは `scripts/test.sh` にも追記する。
- CI（`.github/workflows/ci.yml`）は `macos-26` でビルドとテストを実行する。手元は macOS 27 なので、OS の挙動の違いに注意する。
  - 例: `NSDataDetector` は `www.example.com` のようなスキームのない URL に、macOS 26 では `http`、macOS 27 では `https` を補う。`URLIntake` では `https` にそろえている。
- リリース（`.github/workflows/release.yml`）は `v*` タグで動く。署名・公証用の secrets はまだ登録していない（Team ID は `D7ZSUP4RL5`）。

## 実データ（壊さない）
- Bundle ID は上流と同じ `com.mg.replay`。開発ビルドも、次の実データをそのまま読み書きする。
  - 動画: `~/Movies/Replay`
  - キュー: `~/Library/Application Support/Replay/queue.json`
  - 設定: `defaults read com.mg.replay`
- キューの形式や保存先、移行処理（`ReplayMigration.swift`）に関わる修正を試す前は、バックアップを取る。
- 2026-11-03 のバックアップ: `~/Backups/Replay-20261103/`（`Movies-Replay`、`Application Support/Replay`、`com.mg.replay.plist`）。設定は `defaults import com.mg.replay <plist>` で戻す。
