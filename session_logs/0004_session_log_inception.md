# セッションログ #0004

> 日付: 2026-03-25
> セッション種別: AI協働ワークフロー定義（横断的施策）
> 対応フェーズ: 全フェーズ横断
> 開始: 2026-03-25 00:00
> 終了: 2026-03-25 01:00
> 実作業時間: 1h
> 計画時間: 計画外（レトロスペクティブから発生）

---

## 背景（Problem）

AI コーディングエージェント（Cursor Agent モード）にタスク1-4を委任したところ、Dockerfile の作成・ビルド・検証まで全て AI が自律実行した。成果物は正しかったが、学習課題としては **学習者が手を動かしていない** という本質的な問題が発生した。この問題は Inception 課題に限らず、AI を活用するあらゆる学習プロジェクトで再発しうる構造的リスクである。

## 施策（Solution）

AI協働ワークフローの **プロセス定義** と **ガードレールの設定** を行った。具体的には、AI-Navigated Pair Programming with Scaffolding 方式を策定し、以下の2ファイルに成文化した:

- `.cursor/rules/scaffolding-workflow.mdc` — **Policy as Code**。Cursor が新しいチャットを開くたびに自動適用され、AI の役割を Navigator（ヒント・レビュー）に制限する
- `dev_docs/phase_plan.md` — 運用ドキュメント。人間が参照するプロセス定義として、用語・手順・禁止事項を記載

## 効果（Impact）

これは Inception 課題固有の施策ではなく、Cursor + AI を用いる全プロジェクトに適用される **横断的関心事（Cross-cutting Concern）** である。Policy as Code により、ワークフローが個人の記憶や習慣ではなくツール設定として強制されるため、**プロジェクトをまたいでも一貫した運用が保証される**。

## 用語対応表

| 用語 | 分野 | この施策での該当箇所 |
|------|------|---------------------|
| プロセス定義（Process Definition） | PM | Scaffolding 方式の5ステップ |
| ガードレール（Guardrails） | AI Governance | AIの禁止事項リスト |
| Policy as Code | DevOps / Platform Engineering | `.cursor/rules/scaffolding-workflow.mdc` |
| 横断的関心事（Cross-cutting Concern） | ソフトウェアアーキテクチャ | 全プロジェクトへの適用 |
| Scaffolding（足場かけ） | 教育学 | AI がヒントを出し、学習者が実行 |
| Pair Programming（Navigator/Driver） | XP / アジャイル | Navigator=AI、Driver=学習者 |
| Human-in-the-Loop（HITL） | AI運用 | AI が提案し、人間が判断・実行 |

---

## このセッションで完了したこと

- AI Agent モードでの自律実行による学習効果の喪失をアンチパターン（イシュー）として特定
- AI-Navigated Pair Programming with Scaffolding 方式の策定
- `.cursor/rules/scaffolding-workflow.mdc` の作成（Policy as Code）
- `dev_docs/phase_plan.md` への AI 協働ルール追記（運用ドキュメント）

---

## 現在のファイル状態

| ファイル | 変更内容 |
|---------|---------|
| `.cursor/rules/scaffolding-workflow.mdc` | 新規作成 |
| `dev_docs/phase_plan.md` | AI協働ルールセクションを追記 |
| `session_logs/0004_session_log_inception.md` | 新規作成（このセッション） |

---

## 副産物（タスク1-4のやり直しが必要）

このセッションの発端となったタスク1-4（MariaDB Dockerfile 作成）では、AI が以下を自律実行した。これらは学習者本人がやり直す必要がある:

- `srcs/requirements/mariadb/Dockerfile` — AI が作成（上書き済み）
- `srcs/requirements/mariadb/tools/entrypoint.sh` — AI が作成したプレースホルダ
- `srcs/requirements/mariadb/conf/my.cnf` — AI が作成したプレースホルダ

---

## 次のセッションでやること

タスク 1-4: MariaDB Dockerfile を Alpine 3.21 で新規作成（計画: 3h）
- **Scaffolding 方式で実施**（AI は Navigator、学習者が Driver）
- AI が作成した Dockerfile・プレースホルダは学習者自身が書き直す
- セッションログ #0003 の設計方針と未解決事項を引き継ぐ

---

## 未解決事項

- セッションログ #0003 の未解決事項を全て引き継ぐ（タスク1-4で対処）

---

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: タスク1-4（MariaDB Dockerfile を Alpine 3.21 で新規作成）
```
