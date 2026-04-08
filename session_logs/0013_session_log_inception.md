# セッションログ #0013

> 日付: 2026-04-09
> セッション種別: フェーズ3 事前クイズ（`quizzes/0300_wordpress_alpine_pre_quiz_inception.md`）
> 対応フェーズ: 3
> 開始: 2026-04-07 01:58（AIが `date` コマンドで取得）
> 終了: 2026-04-09 03:02（AIが `date` コマンドで取得）
> 実作業時間: 9.0h（ドライバー申告）
> 計画時間: フェーズ3事前クイズ（計画外時間枠、クイズセッション独立扱い）

---

## このセッションで完了したこと

- **`quizzes/0300_wordpress_alpine_pre_quiz_inception.md` 新規作成**（全16問）:
  - PHP-FPM・FastCGI・www.conf・wp-cli・entrypoint.sh 設計・Alpine PHP パッケージ名・通信経路等、フェーズ3の全タスクを見越した設問（記述15問、選択1問）。
  - ドライバーが全問回答後にチャットに貼り、採点・正解・解説を追記。
- **採点結果**: 正解10 / ほぼ正解2 / 部分正解3 / 不正解1。
- **採点後の議論で AI の解説を3箇所修正**:
  1. **Q5（PHP-FPM パス）**: 一次資料を `pkgs.alpinelinux.org/packages`（パッケージ検索）→ `pkgs.alpinelinux.org/contents`（ファイル一覧）に訂正。AI の `find` コマンドにタイポ（`/etc/name` → `/etc -name`）があり、ドライバーの再実行で正解（選択肢2）を実機確認。
  2. **Q7（wp core download のタイミング）**: AI が「方針 A（Dockerfile 内）が無条件に優れている」と採点したが、ドライバーが `0102` クイズの「ビルド時データが bind mount で消える」記述との矛盾を指摘。`driver_opts: type: none, o: bind`（bind mount 相当）では named volume の初回コピー動作が発生しないため、方針 A のみでは不十分。❌ → ⚠️ 部分正解に修正。
  3. **Q7 一次資料**: `docker-compose volumes/#driver_opts` は NFS の例のみで `type: none, o: bind` の根拠にならないことをドライバーが別 AI（Opus 4.6）で検証し指摘。`type: none, o: bind` → bind mount は Linux `mount(2)` の仕様に由来し、Docker 公式ドキュメントには明示なし。一次資料を修正。

---

## 採点サマリ

| Q | テーマ | 判定 | 要点 |
|---|--------|------|------|
| Q1 | PHP-FPM の役割 | ✅ 正解 | インタプリタ未内蔵、PHP-FPM が実行して返す |
| Q2 | fastcgi_pass | ✅ 正解 | compose / 手動ネットワーク両方の DNS 解決を説明。秀逸 |
| Q3 | listen ディレクティブ | ✅ 正解 | TCP vs Unix ソケット、NGINX 側の書き換え、パフォーマンス差 |
| Q4 | Alpine PHP パッケージ名 | ⚠️ 部分正解 | 命名規則は理解。コマンド例が途中で中断 |
| Q5 | PHP-FPM パス | ❌ 不正解 | 4番を選んだが正解は2番。実機再検証で確定 |
| Q6 | wp-cli インストール | ✅ 正解 | 公式ガイド準拠。`--info` 検証ステップも良い |
| Q7 | wp core download の場所 | ⚠️ 部分正解 | bind mount での挙動を考慮すると B の根拠も一部正しい |
| Q8 | wp config create | ✅ ほぼ正解 | 各引数正確。ポート明示は不要 |
| Q9 | wp core install vs download | ✅ 正解 | 違いを正確に説明 |
| Q10 | --allow-root | ✅ 正解 | 3根拠 + 実機テスト |
| Q11 | 待機ループ設計 | ✅ ほぼ正解 | B 選択は正しい。「未定義動作」→「無限ハング」 |
| Q12 | exec php-fpm83 -F | ✅ 正解 | PID 1 + フォアグラウンド |
| Q13 | pm 設定 | ✅ 正解 | dynamic vs static を正確に説明 |
| Q14 | ユーザーロール | ✅ 正解 | 5ロール列挙、editor 推奨理由 |
| Q15 | 冪等性ガード | ⚠️ 部分正解 | 2>/dev/null は正確。ガードなし = エラー発生 |
| Q16 | 通信経路 | ✅ 正解 | 全経路正解。OSI レイヤー補足も適切 |

**弱点（フェーズ3開始前に重点復習）:**
- **Q5**: Alpine PHP パッケージのパス確認方法（`pkgs.alpinelinux.org/contents` or 実機 `find`）
- **Q7**: `driver_opts: type: none, o: bind` 時の volume 初期化動作の違い（named volume vs bind mount）
- **Q15**: 冪等性ガードの目的は「時間短縮」ではなく「エラー防止」

---

## 運用ルール更新

| 更新先 | 内容 |
|--------|------|
| なし | 今回は運用ルールの変更なし |

---

## 現在のファイル状態

| ファイル | 変更内容 |
|---------|---------|
| `quizzes/0300_wordpress_alpine_pre_quiz_inception.md` | 新規作成（全16問、採点・正解・解説追記済み、採点後3箇所修正） |
| `session_logs/0013_session_log_inception.md` | 本ファイル |

---

## 次のセッションでやること

- **フェーズ3 タスク 3-1**: 参考実装の WordPress 精読（Dockerfile + www.conf + entrypoint.sh 全行理解）
- 一次資料の完全な確認は **フェーズ8 タスク 8-4**（参考文献リスト整理）のタイミングで実施予定
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録（上記「開始」欄やチャットへの貼り付けに用いる）

---

## 未解決事項

- Q7 の volume 初期化動作: `driver_opts: type: none, o: bind` の場合に方針 A（ビルド時ダウンロード）のみでは WordPress ソースが volume に入らない問題。タスク 3-4（entrypoint.sh 作成）で entrypoint.sh 側の補完ガードを設計する際に解決する。

---

## 今日のセッションのまとめ

- 16問中、正解10・ほぼ正解2・部分正解3・不正解1。PHP-FPM・FastCGI・wp-cli の基本概念は十分に理解できています。
- AI の解説に対して一次資料の裏取りを行い、3箇所の誤りを発見・修正した点が特に優れています。特に Q7 の bind mount と named volume の挙動の違いは、フェーズ4（compose 統合）で直接関わる重要な知見です。
- 実作業9時間のうち、かなりの時間が回答後の検証・議論に使われており、「解いて終わり」ではなく理解を深める姿勢が見えます。

---

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録（上記「開始」欄やチャットへの貼り付けに用いる）
今日やること: フェーズ3 タスク 3-1（参考実装の WordPress 精読）
```
