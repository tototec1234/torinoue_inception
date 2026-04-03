# セッションログ #0007

> 日付: 2026-03-26
> セッション種別: フェーズ1 事後クイズ
> 対応フェーズ: 1
> 開始: 2026-03-26 07:00
> 終了: 2026-03-26 11:00
> 実作業時間: 4.0h
> 計画時間: （事後クイズは phase_plan.md に明記なし）

---

## このセッションで完了したこと

- フェーズ1 事後クイズ実施 → `quizzes/0100_alpine_mariadb_post_quiz_inception.md` 作成
  - 全18問の問題に回答
  - AI が正解・解説・一次資料を追記
  - 「今日詰まったポイント」セクションにセッションログ #0006 の Spike 記録を反映
  - 「レビュー想定問答集」セクションに弱点を中心とした問答を追加

---

## クイズ結果サマリー

### 正確に理解できていた項目
- Q1: Alpine と Debian のパッケージマネージャの違い（`apk --no-cache` の利点）
- Q3: `mariadb-install-db` を entrypoint.sh で実行する理由（volume マウントとの関係）
- Q4: 一時起動 → シャットダウン → 本番起動の3段階の理由（セキュリティ、プロセス管理、データ整合性）
- Q5: `--skip-networking` の意味と一時起動時の用途
- Q6: 初期化ガード `if [ ! -d "/var/lib/mysql/mysql" ]` の役割
- Q9: `mariadb-admin ping` の役割とループの理由
- Q10: ping ループのタイムアウト設計（無限ループ禁止、起動失敗検出）
- Q13: 設定ファイルの読み込み順（アルファベット順、`zaphod-` prefix の意図）
- Q18: Alpine 3.21 を選んだ理由（penultimate stable version）

### 部分的に誤解があった項目
- Q2: Alpine のデフォルトシェル（ash の確認方法が不明だった）
- Q7: `IF NOT EXISTS` と初期化ガードの違い（「冗長性」だけでなく多層防御の観点）
- Q8: PID 1 と `exec` の関係（「`exec` なしで `mariadbd` を実行すると entrypoint.sh が終了する」は誤解）
- Q11: `bind-address = 0.0.0.0` の意味（「`127.0.0.1` でも問題ない」は誤り）
- Q17: `ENTRYPOINT` と `CMD` の違い（「PID 1 を譲れるかどうか」は誤解）

### 新たに学んだこと
- `exec` コマンドは現在のプロセスを置き換える（PID を継承する）
- `exec` なしで子プロセスを起動すると、親プロセスは待機し続ける（終了しない）
- `bind-address = 127.0.0.1` だと Docker network 経由の接続を受け付けない
- `ENTRYPOINT` と `CMD` の違いは「上書きのしやすさ」と「意図の明示」

---

## Spike記録

（このセッションでは新規の Spike なし。セッションログ #0006 の Spike を参照）

---

## PoC記録

（このセッションでは新規の PoC なし。セッションログ #0006 の PoC を参照）

---

## 現在のファイル状態

| ファイル | 変更内容 |
|---------|---------|
| `quizzes/0100_alpine_mariadb_post_quiz_inception.md` | 新規作成（フェーズ1 事後クイズ、全18問） |
| `session_logs/0007_session_log_inception.md` | 新規作成（このセッションログ） |

---

## 次のセッションでやること

**フェーズ2 開始**: NGINX コンテナ構築
- タスク 2-0: フェーズ2 事前クイズ → `quizzes/0200_nginx_pre_quiz_inception.md`
  - TLS とは何か、SSL との違い
  - TLSv1.2 と TLSv1.3 の違い
  - 自己署名証明書とは何か
  - リバースプロキシとは何か
  - `fastcgi_pass` とは何か
  - NGINX の設定ファイル構造（events, http, server, location）

---

## 未解決事項

（なし）

---

## 新しいチャット開始時のコピペ用指示文
```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: フェーズ2 事前クイズ（quizzes/0200_nginx_pre_quiz_inception.md）
```
