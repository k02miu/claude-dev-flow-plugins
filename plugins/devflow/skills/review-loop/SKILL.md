---
name: review-loop
disable-model-invocation: true
argument-hint: "[レビュースコープ（任意）]"
description: "ブランチの変更差分（コミット済み + 未コミット）に対して、dynamic Workflow（利用可環境）または Agent Teams + マルチ LLM（Claude 専門ローカルレビュアー / Codex / Gemini）で回帰的にコードレビュー → 修正 → 再レビューを繰り返すスキル。全レビュアー OK、収束、または 5 反復到達で終了する。コード品質の総点検、PR 提出前の最終確認、リリース前監査など、徹底的にレビューしたい場面で使用すること。"
---

# Regressive Review Loop Skill

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。

> **変数の解決（重要）**: 本スキル内の `{{VARIABLE}}` はプラグイン配布時に自動置換されません。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成を調査して値を解決してください。解決できない場合のみユーザーに確認します。

ブランチの変更差分に対して **並列レビュー → 修正 → 再レビュー** を最大 5 回ループします。
`{{PLUGIN_NAME}}` プラグインの専門エージェント（code-architecture-reviewer / security-reviewer / test-coverage-reviewer / infra-reviewer / review-checklist-advisor）が領域特化の品質を担います。

## 経路（主経路 Workflow / 副経路 Agent Teams）

本スキルは 2 経路を持つ。**主経路は dynamic Workflow**、**副経路は Agent Teams**。
最初に Phase 0-0 で `${CLAUDE_PLUGIN_ROOT}/references/workflow-capability.md` を Read して capability を判定し、分岐する。

- 主経路（Workflow 利用可）: 「主経路: Workflow 仕様」節に従い、評価最適化ループを 1 つの workflow として記述・実行する。中間結果はスクリプト変数が運び、iteration ごとに fresh spawn する。
- 副経路（Workflow 利用不可）: 以降の「ループ構造」「コンテキスト管理戦略」「実行手順（Phase 0〜3）」に従い、Agent Teams で回す。

O 契約（`${CLAUDE_PLUGIN_ROOT}/references/o-contract.md`）と allowlist 制約（`workflow-capability.md` §3）は**両経路で同一**に満たす。

## 🚨 エージェント再利用の絶対原則（副経路 Agent Teams のみ） 🚨

> 本節は副経路（Agent Teams）にのみ適用される。主経路（Workflow）では逆に **iteration ごとに fresh spawn** し、findings はスクリプト変数 / schema 引数が運ぶ（再利用ロジックは持たない）。

毎 iteration で Teammate を起動・解散するのは **コンテキスト・キャッシュ・思考の継続性をすべて捨てる完全な無駄** です。
以下を厳守してください:

- **Claude Teammate は iteration 1 で 1 回だけ Task tool で起動する**。iteration 2 以降は **絶対に新規 Task 起動しない**
- **iteration 間で `shutdown_request` を送らない**。Phase 3（最終報告後）まで全 Teammate を在籍させ続ける
- **iteration 2 以降の指示伝達は `SendMessage` のみ**（`instruct.md` を Write で更新 → SendMessage で「iteration N の指示書を Read してください」と通知）
- **最低 3 回はループする前提**で動作する。1 回目で OK が出ても収束確認のため最低 2 回目を回すこと
- **implement スキルを呼ぶ場合も、implement が立てたチームは review-loop の全 iteration を通じて再利用する**。Phase 1-C の 2 回目以降は implement skill を再呼び出しせず、前回 implement で起動した Teammate に直接 SendMessage で追加修正を依頼する

## 🚨 Low 指摘も必ず対応する 🚨

「Critical/High/Medium がゼロで Low のみ残っている」状態は **Exit 条件ではない**。Low 指摘も等しく対応対象。
ただし「修正コストが効果に見合わないため対応見送り推奨」と判断した Low は、`final-report.html` に
**理由付きで明記**してユーザー判断に委ねる（黙ってスキップしない）。

レビュー対象: $ARGUMENTS
（未指定の場合はブランチとメインブランチ間の全変更差分を対象にします）

**commit & push はユーザーが明示的に指示しない限り絶対に行わないでください。**
**レビューフェーズではコードに手を加えないでください。修正は Phase 1-C でのみ実行します。**

---

## 変数定義

本 SKILL.md で使用する {{VARIABLE}} の一覧（説明・デフォルト例）は `${CLAUDE_SKILL_DIR}/references/variables.md` を Read して確認してください。
`{{N}}`（iteration 番号）、`{{TASK_SUBJECT}}`、`{{TEAMMATE_NAME}}`、`{{ROLE_SPECIFIC_INSTRUCTIONS}}`、`{{CHANGED_FILES}}`、`{{DIFF_SUMMARY}}`、`{{PREV_FINDINGS}}` は実行時に動的置換されるプレースホルダです。

---

## チーム構成（Agent Teams + マルチ LLM）

### {{PLUGIN_NAME}} 専門レビュアー（Agent Teams の Teammate、常時起動）

| Teammate 名                   | `subagent_type`                                      | 担当領域                                       |
| ----------------------------- | ---------------------------------------------------- | ---------------------------------------------- |
| `code-architecture-reviewer`  | `code-architecture-reviewer`                         | コード品質・可読性・保守性、パフォーマンス（DB/N+1/RSC境界/バンドル）、Clean Arch / DDD / SOLID / レイヤー境界 |
| `security-reviewer`           | `security-reviewer`                                  | OWASP / 認証認可 / STRIDE                      |
| `testing-reviewer`            | `test-coverage-reviewer`                             | テスト網羅性 / 境界値                          |
| `codex-independent-reviewer`  | `codex:codex-rescue`                                 | Codex の独立視点（TS/Node 固有バグ・型安全性） |
| `checklist-advisor`           | `review-checklist-advisor`                           | `{{REVIEW_CHECKLIST_PATH}}` を上から全件走査し、差分が各教訓を遵守しているか点検 |

`codex-independent-reviewer` は **`codex:codex-rescue` agent を Teammate として起動**することで、
他の Claude レビュアーと同じ枠組み（Task tool 起動 → SendMessage で再利用）でコンテキストを引き継ぎます。
Codex CLI 自体はステートレスですが、**Claude ラッパー側に「読んだファイル・前回の分析・指摘の経緯」が残る**ため、
毎 iteration ゼロから始まる無駄を避けられます。codex CLI 未導入の環境では起動をスキップ（Phase 0-4 でチェック）。

### {{PLUGIN_NAME}} 専門レビュアー（条件付き起動）

- `infra-reviewer`（`subagent_type: infra-reviewer`）: 変更差分に {{IAC_TOOL}} / CI/CD / Docker / {{CLOUD_PROVIDER}} 関連ファイルを含む場合のみ起動（判定パターンは Phase 0-1 参照）。
  該当しない場合は起動せず `exit-decision.md` にスキップ記録を残す。判定が曖昧な場合は **起動する側に倒す**（過剰にレビューしても害がない）。

### マルチ LLM 独立レビュアー（Bash 経由 / ステートレス）

- `gemini-independent-reviewer`: `agy` CLI (Antigravity)、agy CLI 利用可時のみ。
  Gemini はラッパー agent が存在しないため、毎 iteration `agy -p` を Bash バックグラウンドで起動する**ステートレス方式**を維持します。コンテキスト継続は prompt.txt 内の `{{PREV_FINDINGS}}` セクション経由。

---

## 参照すべき外部 skill（プロセス知識ベース）

本 SKILL.md は「何をするか」のみを定義します。**「どうやるか」の詳細は外部 skill に委譲**してください。
トピック別の参照先一覧は `${CLAUDE_SKILL_DIR}/references/external-skills.md` を Read で確認し、
各フェーズで必要になった時点で該当 skill を Skill ツールで参照すること。

**中〜大規模修正が必要になった場合は `implement` スキル**を Skill ツールで起動してください（Phase 1-C で判定）。

---

## Phase 0-0: 経路判定（両経路共通・最初に実施）

`${CLAUDE_PLUGIN_ROOT}/references/workflow-capability.md` を Read し、§1 の bash probe を実行して判定する:

- `WORKFLOW_CANDIDATE` → 「主経路: Workflow 仕様」へ。Workflow ツールが利用不可と判明したら副経路に切替（同ファイル §2）。
- `WORKFLOW_UNAVAILABLE` → 副経路（「副経路: ループ構造」以降）に直行。

---

## 主経路: Workflow 仕様

`WORKFLOW_CANDIDATE` のとき、以下の仕様を満たす dynamic Workflow を Workflow ツールで authoring・実行する。
プラグインは workflow スクリプトを同梱できないため、**下記の仕様と骨格に従ってあなたがその場で JS を書き、run する**。

下記 API 表面（`agent(prompt, {schema, agentType, model, effort, label})` / `parallel([fn])` / `phase()` / `budget.total` / `export const meta` / `return`）は本環境で実機検証済み。`agentType` にプラグイン名前空間（`devflow:*`）を渡してカスタム subagent を解決でき、`schema` とも合成される。

### フェーズ構成（評価最適化ループ）

| フェーズ | 役割 | モデル目安 |
|---|---|---|
| Context | I の pre-stage。`${CLAUDE_SKILL_DIR}/scripts/diff-summary.sh` 実行、`{{CHANGED_FILES}}` / `{{DIFF_SUMMARY}}` 取得、規約解決、infra 要否判定を 1 エージェントに集約 | 安価（`sonnet` / `effort:'low'`） |
| Review | レビュアー次元ごとに `agent({agentType, schema})` を並列 fan-out。`prevFindings` を引数で渡す | 判断系（既定モデル継承） |
| Verify | 1 verifier が**全 finding をバッチで** refute し、各件を defect（客観的欠陥・要修正）/ judgment（妥当だが裁量）/ spurious（誤検出）に分類（自己採点バイアスを別エージェントで潰す。バッチ=1エージェントなので全件でもコスト一定） | 判断系 |
| Fix | implementer エージェントが修正適用。単一ライターなので worktree 不要 | 既定継承 |
| Report | O 契約（findings + criticalDecisions）を schema 出力 | 安価 |

### レビュアー次元（Review フェーズの fan-out 対象）

副経路の「チーム構成」表と同じ agent を `agentType` に使う:
`devflow:code-architecture-reviewer` / `devflow:security-reviewer` / `devflow:test-coverage-reviewer` / `devflow:review-checklist-advisor`、
infra 要時のみ `devflow:infra-reviewer`、Codex CLI 利用可時のみ `codex:codex-rescue`。
Gemini（`agy`）は主経路では**同期呼び出し**（`&` なし・stdout 捕捉）の review source とし、利用不可ならスキップ（副経路の `&`+ポーリング方式は workflow agent に乗らないため変更）。

### ループと Exit（構造で保証する不変条件）

- `for` ループで最大 5 iteration。`prevFindings` は変数で次 iteration に渡す（ファイル IPC 不要）。
- **Exit / Fix の軸は severity ではなく defect / judgment**: typo は low でも客観的欠陥＝必ず直す。severity で fix を gate しない。Exit 条件は JS で判定: (1) defect が 0（残るのは judgment と見送り項目だけ）、(2) defect が前 iteration から減らず judgment だけが揺れている＝収束、(3) `iteration == 5`。
- **「Low も必ず対応」「件数で打ち切らない」はプロンプト祈願でなく構造で保証する**: Fix は severity 不問で全 defect を対象にする。fresh-spawn のたびに別の主観 nitpick が湧くが、それは Verify で spurious として落ちるので収束を妨げない（severity ヒストグラム一致による収束判定は fresh-spawn の非決定性で機能しないことを試走で確認済み）。「対応見送り推奨」と判断した defect のみ理由付きで report に記録し、黙って捨てない。
- `token budget`（`budget.total`）で run 全体の上限を設ける。非エンジニア利用も想定し保守的に。

### 実行制約（workflow 固有・副経路と異なる点）

- **mid-run でユーザーに問わない**: workflow 中の agent に `AskUserQuestion` を呼ばせない（workflow は実行中の対話ができない）。曖昧さは Context pre-stage で前倒しに解決し、残余は「質問」ではなく **finding か `criticalDecisions`** に落とす（副経路の `questions.md` 往復は主経路には無い）。
- **Gemini は同期**: 上記のとおり `agy` を同期 review source にするか落とす。`&`+ポーリングは使わない。
- **Verify はバッチで全件**: finding ごとに verifier を spawn すると反復数×件数で agent が膨らむ（1 agent ≈ 20k トークンの固定費を実測）。1 verifier が**全 finding を一括** refute し、各件を defect / judgment / spurious に分類する。バッチなので件数が増えてもエージェント数は 1（severity で絞らない。typo のような客観 low も verify を通って defect として残り、Fix で直る）。

### O 契約

Review / Report の schema は `${CLAUDE_PLUGIN_ROOT}/references/o-contract.md` に従う。
findings は `${CLAUDE_SKILL_DIR}/references/phase-output-templates.md` の aggregated-findings 形式を schema 化したもの（`severity` に加え、Verify が `kind: defect | judgment | spurious` を付与する）。最終 report は同 `criticalDecisions` を含む。

### 骨格（helper / schema は authoring 時にインラインで定義する。下記は形だけ示す）

```js
export const meta = {
  name: 'review-loop',
  description: 'Regressive multi-dimension code review -> fix -> re-review (max 5 iterations)',
  phases: [
    { title: 'Context' }, { title: 'Review' }, { title: 'Verify' },
    { title: 'Fix' }, { title: 'Report' },
  ],
}

// 実 API 確定済み: agent(prompt,{schema,agentType,model,effort,label}) / parallel([fn]) / phase() / budget.total / return。
// schema / helper (dedupe, applyKinds, sameDefects, *Prompt) は authoring 時にインライン定義する。
// 注意: workflow 内 agent に AskUserQuestion を呼ばせない（「実行制約」参照）。
const RANK = { low: 0, medium: 1, high: 2, critical: 3 }   // fix の優先順位付け用（exit gate には使わない）

phase('Context')                       // I の pre-stage（安価モデル）。曖昧さはここで前倒しに潰す
const ctx = await agent(contextPrompt(), { schema: CTX_SCHEMA, model: 'sonnet', effort: 'low' })

const DIMENSIONS = [
  { key: 'arch',      agentType: 'devflow:code-architecture-reviewer' },
  { key: 'security',  agentType: 'devflow:security-reviewer' },
  { key: 'testing',   agentType: 'devflow:test-coverage-reviewer' },
  { key: 'checklist', agentType: 'devflow:review-checklist-advisor' },
  // ctx.infraRequired なら devflow:infra-reviewer、codex 利用可なら codex:codex-rescue を push
]

let prev = [], prevDefects = [], exitReason = null
const history = []
for (let n = 1; n <= 5; n++) {
  phase('Review')
  const reviews = await parallel(DIMENSIONS.map(d => () =>
    agent(reviewPrompt(d, ctx, prev, n), { agentType: d.agentType, schema: FINDINGS_SCHEMA, label: `review:${d.key}` })))
  // Gemini を使うなら同期 source を1つ追加: agent が Bash で `agy -p`（`&` なし）を実行し stdout を捕捉
  let findings = dedupe(reviews.filter(Boolean).flatMap(r => r.findings))

  phase('Verify')                      // バッチ refute: 1 agent が全 finding を defect/judgment/spurious に分類
  if (findings.length) {
    const verdicts = await agent(batchClassifyPrompt(findings), { schema: VERDICTS_SCHEMA })  // 各 id に kind を付与
    findings = applyKinds(findings, verdicts).filter(f => f.kind !== 'spurious')  // 誤検出を落とす
  }
  const defects = findings.filter(f => f.kind === 'defect')   // severity 不問。typo(low) もここに入る
  history.push({ n, findings, defects })

  if (defects.length === 0) { exitReason = 'all-clear'; break }              // 残るは judgment と見送りのみ
  if (sameDefects(defects, prevDefects)) { exitReason = 'converged'; break } // defect が減らず judgment だけ揺れる

  phase('Fix')
  await agent(fixPrompt(defects, ctx), { agentType: 'devflow:implementer' })  // 全 defect を修正。allowlist は push 非含
  prev = findings; prevDefects = defects
}
if (!exitReason) exitReason = 'max-iterations'

phase('Report')
return await agent(reportPrompt(history, exitReason), { schema: REPORT_SCHEMA })  // criticalDecisions 必須
```

workflow 完了後、返り値（O 契約）を Phase 2 と同じ要領で `final-report.html` に materialize し、ユーザーに要点提示する（非ブロッキングの出力アーティファクト）。

---

## 副経路: ループ構造（Agent Teams）

> 以降の「ループ構造」「コンテキスト管理戦略」「実行手順（Phase 0〜3）」は副経路（Agent Teams）の手順。主経路では上記 Workflow 仕様に従う。

```
Phase 0: 準備（ブランチ差分取得、infra 要否判定、タスクスラッグ生成、キャッシュクリーンアップ）
   ※ Teammate は iteration 1 でだけ Task tool で起動し、以降は SendMessage で再利用する
       ↓
┌─ Phase 1: レビューループ（最大 5 反復）─────────────────────────────────────┐
│ Phase 1-A: レビュー指示伝達                                                  │
│   iteration 1: Claude Teammate (5〜6 種) を Task tool で並列起動 /           │
│   iteration 2+: 既存 Teammate に SendMessage で再指示 /                      │
│   gemini CLI のみ Bash バックグラウンドで毎 iteration 起動 → 全通知待ち      │
│ Phase 1-B: 結果集約と Exit 判定                                              │
│   全 report.md を Read → 重複排除・severity較正 → Exit 条件判定              │
│   （条件成立 → Phase 2 へ / 未成立 → Phase 1-C へ）                          │
│ Phase 1-C: 修正実行                                                          │
│   軽微（1-2 ファイル、severity ≤ medium）→ リーダーが直接 Edit /             │
│   中〜大規模・インフラ含む → implement スキル（初回のみ起動、2 回目以降は    │
│   既存 implement チームに SendMessage で追加修正依頼）                       │
│   → 修正完了後、iteration++ して Phase 1-A へ戻る                            │
└──────────────────────────────────────────────────────────────────────────────┘
       ↓
Phase 2: 最終報告（ユーザーへ提示）
       ↓
Phase 2.9: レビュー指摘チェックリストの最新化（今ループの findings から教訓を抽出・統合）
       ↓
Phase 3: Teammate シャットダウン（review-loop + implement の Teammate をまとめて）
```

### Exit 条件（いずれかを満たしたら Phase 2 へ）

1. **全レビュアー OK**: 全ロールが「問題なし」と報告（Critical / High / Medium / Low **すべて 0 件**）
2. **収束判定**: 前 iteration と比較して severity 構成がまったく変わらず、修正しても減らない（技術判断分かれ目で reviewer 間の見解が固定化した状態）
3. **反復上限到達**: iteration が 5 に達した
4. **ユーザーキャンセル**: ユーザーから中断指示

**「Low (軽微) のみ残存」は Exit 条件ではない**（冒頭の 🚨 Low 原則を参照。黙ってスキップしたり、軽微を理由にループを早期終了することは禁止）。

---

## コンテキスト管理戦略

リーダーと Teammate 間の通信は **すべてファイルベース** で行い、コンテキストウィンドウの圧迫を防ぎます。

```
{{CACHE_DIR}}/review-loop/
└── {task-slug}/
    ├── target-files.md                  # Phase 0: レビュー対象ファイル + infra 判定結果
    ├── iteration-01/
    │   ├── {teammate-name}/             # Claude Teammate 各ロール（infra-reviewer は INFRA_REQUIRED=true のみ）
    │   │   ├── instruct.md / report.md / questions.md / answers.md
    │   ├── gemini-independent-reviewer/ # gemini CLI (Bash 経由、ステートレス)
    │   │   ├── prompt.txt / report.md
    │   ├── aggregated-findings.md       # Phase 1-B: 統合済み findings
    │   ├── exit-decision.md             # Phase 1-B: Exit 判定結果
    │   └── fix-plan.md                  # Phase 1-C: 修正計画（継続時のみ）
    ├── iteration-02/ ...
    └── final-report.html                # Phase 2: ユーザー向け最終レポート
```

通信フロー: 指示はリーダーが `instruct.md` に Write → Teammate が Read。結果は Teammate が `report.md` に Write → SendMessage で「レビュー完了」通知。質問は `questions.md` → SendMessage → リーダーが AskUserQuestion → `answers.md` に回答。

### スキル同梱リソース（実行時に Read / 実行する）

- `${CLAUDE_SKILL_DIR}/references/variables.md` — 変数定義の一覧
- `${CLAUDE_SKILL_DIR}/references/external-skills.md` — 参照すべき外部 skill 一覧
- `${CLAUDE_SKILL_DIR}/references/instructs/common.md`, `instructs/<role>.md` — instruct.md の冒頭/末尾共通テンプレと、各ロールの固有観点 + 起動プロンプト追加指示
- `${CLAUDE_SKILL_DIR}/references/launch-prompt-template.md` — Claude Teammate 共通起動プロンプト
- `${CLAUDE_SKILL_DIR}/references/gemini-prompt-template.txt` — Gemini 用 prompt.txt テンプレ
- `${CLAUDE_SKILL_DIR}/references/phase-output-templates.md` — target-files / aggregated-findings / exit-decision / fix-plan / implement 依頼・再依頼 / final-report 等の各テンプレ
- `${CLAUDE_SKILL_DIR}/scripts/diff-summary.sh` — CHANGED_FILES / DIFF_SUMMARY の取得スクリプト

---

## 実行手順

### Phase 0: 準備

#### 0-1. レビュー対象の特定 & infra 要否判定

引数があればそれを優先。未指定の場合は同梱スクリプトで変更差分（コミット済み: マージベースから / 未コミット: staged + unstaged + untracked）を取得します:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/diff-summary.sh            # ベースブランチは origin/HEAD から自動検出
# bash ${CLAUDE_SKILL_DIR}/scripts/diff-summary.sh origin/develop   # ベースブランチを明示する場合
```

出力の `## CHANGED_FILES` / `## DIFF_SUMMARY` セクションをそのまま `{{CHANGED_FILES}}` / `{{DIFF_SUMMARY}}` として使用します。

CHANGED_FILES に対して **infra-reviewer 適用可否判定**を行います。以下のパターンで 1 件でもマッチすれば `INFRA_REQUIRED=true`:

```
{{IAC_PATH}}/**, **/*.{{IAC_EXT}}, **/*.{{IAC_VARS_EXT}}
.github/workflows/**
docker-compose*.yml, **/Dockerfile, .dockerignore
{{FRONTEND_CONFIG_PATTERN}}
{{CLOUD_PACKAGE_PATH}}/**
.env.example（の変更、主要環境変数の追加）
```

結果を `phase-output-templates.md` の「target-files.md テンプレ」に従って `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/target-files.md` に Write。

**重要**: 変更差分がない場合は、ユーザーに通知して終了してください。

#### 0-2. タスクスラッグの生成

ブランチ名または引数内容から kebab-case のスラッグ `{{TASK_SLUG}}` を生成（英小文字・数字・ハイフンのみ、2〜4 語程度。例: `sprint-8-review`, `feat-cloud-armor-review`）。

#### 0-3. キャッシュクリーンアップ

```bash
find {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/ -name "*.md" -type f -delete 2>/dev/null || true
mkdir -p {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}
```

#### 0-4. CLI 可用性チェック

```bash
which codex || echo "CODEX_UNAVAILABLE"
which agy   || echo "GEMINI_UNAVAILABLE"
```

- **codex CLI 利用不可、または `codex` プラグイン（`codex:codex-rescue` agent）未導入** → `codex-independent-reviewer` Teammate の起動をスキップ。`codex` は本プラグインのハード依存ではないため、未導入環境でも review-loop 全体は成立する。判定は `which codex`（CLI バイナリ）と `codex:codex-rescue` agent の解決可否（`/agents` 等で `codex:` 名前空間が見当たらない、または Task 起動が解決失敗する場合は `CODEX_UNAVAILABLE` 扱い）の両方を確認すること
- **agy CLI 利用不可** → `gemini-independent-reviewer` の Bash 起動をスキップ
- 利用不可のロールは `exit-decision.md` にスキップ記録を残す。両方とも利用不可でも Claude 専門レビュアーのみで継続可能

#### 0-5. iteration カウンタ初期化

`iteration = 1` でループを開始します。以降 Phase 1 のたびに +1。

---

### Phase 1: レビューループ

以下を iteration が 5 に達するまで、または Exit 条件が成立するまで繰り返します。

#### Phase 1-A: レビュー指示伝達（iteration ごとに実施）

##### 1-A-0. サブディレクトリの作成

```bash
mkdir -p {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{code-architecture-reviewer,security-reviewer,testing-reviewer,codex-independent-reviewer,gemini-independent-reviewer,checklist-advisor}
# INFRA_REQUIRED=true のときのみ
mkdir -p {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/infra-reviewer
```

##### 1-A-1. 各 Teammate の instruct.md を準備

各ロールの instruct.md を以下の手順で生成し、`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{teammate-name}/instruct.md` に Write してください:

1. `${CLAUDE_SKILL_DIR}/references/instructs/common.md` を Read し、「共通部分（冒頭）」を取り出す
2. `${CLAUDE_SKILL_DIR}/references/instructs/<role>.md` を Read し、「instruct.md ロール固有の観点」を続ける
3. common.md の「全ロール共通（末尾）」（出力フォーマット）を続ける
4. `{{TASK_SLUG}}`, `{{N}}`, `{{CHANGED_FILES}}`, `{{DIFF_SUMMARY}}`, `{{PREV_FINDINGS}}`（2 周目以降のみ）を置換する
   - `{{CHANGED_FILES}}` / `{{DIFF_SUMMARY}}` は毎 iteration `bash ${CLAUDE_SKILL_DIR}/scripts/diff-summary.sh` を実行して取得する（修正で差分が変わるため）

**全ファイルの保存が完了してから、Phase 1-A-2 に進みます。**

**重要**: 2 周目以降（iteration ≥ 2）は、instruct.md の「前回反復での指摘」セクションに
前 iteration の `aggregated-findings.md` を要約して含めること。これにより同じ指摘を繰り返す無限ループを防ぎます。

##### 1-A-2. Teammate の起動 / 再利用（Claude）

**iteration の値で動作を分岐させる。**

###### Case A: `iteration == 1` の場合（初回のみ：並列起動）

Claude Teammate を **1 メッセージで並列に** Task tool で起動してください
（常時 3 ロール + checklist-advisor 1 ロール + Codex 1 ロール + 条件付き infra 1 ロール、合計最大 6 ロール）。
Task tool パラメータ: `subagent_type: "devflow:{チーム構成表の subagent_type}"`（codex-independent-reviewer のみ `"codex:codex-rescue"`）、
`name: "{Teammate 名}"`、`description: "{担当領域} (iteration N)"`。

起動プロンプトは `${CLAUDE_SKILL_DIR}/references/launch-prompt-template.md` を Read し、
`{{ROLE_SPECIFIC_INSTRUCTIONS}}` に各ロールの `references/instructs/<role>.md` の「起動プロンプト追加指示」を挿入して生成します。
テンプレには「あなたはこの後 iteration 2, 3, ... と繰り返し指示を受ける可能性があり、SendMessage で通知されたら
新しい instruct.md を読み込み、同じ JSON フォーマットで report.md に Write する」旨が含まれています（削らないこと）。

###### Case B: `iteration >= 2` の場合（既存 Teammate を再利用）

**🚨 絶対に Task tool で再起動しない。** iteration 1 で起動した Teammate は team "review-loop" に在籍したまま、
次の指示を待っています。SendMessage のみで再指示してください。
`phase-output-templates.md` の「iteration 2 以降の再指示 SendMessage テンプレ」を使い、
全 Claude Teammate（code-architecture-reviewer / security-reviewer / testing-reviewer / checklist-advisor / codex-independent-reviewer / 該当時のみ infra-reviewer）に 1 メッセージで並列送信します。
`codex-independent-reviewer` も Claude ラッパー (`codex:codex-rescue`) であるため同じ手順で再指示できます（前 iteration の文脈はラッパー側に保持される）。

**禁止事項**（違反するとコンテキスト・キャッシュ・思考過程をすべて捨てることになり、ループ継続の意義が失われる）:
- iteration 2 以降で同名の Teammate を Task tool で再起動すること（`Cannot spawn duplicate name` エラーまたは context 破棄が発生）
- iteration 間で `shutdown_request` を送ること

##### 1-A-3. Gemini CLI を Bash でバックグラウンド起動

Codex は Phase 1-A-2 で Teammate として既に起動・指示済みなのでここでは扱いません。
Gemini のみ毎 iteration、`${CLAUDE_SKILL_DIR}/references/gemini-prompt-template.txt` を Read して
`{{CHANGED_FILES}}` / `{{DIFF_SUMMARY}}` / `{{PREV_FINDINGS}}` / `{{N}}` を置換した prompt.txt を Write した上で、
Bash tool の `run_in_background: true` で起動:

```bash
# Gemini = agy (利用可能時のみ)
agy --dangerously-skip-permissions -p \
  "$(cat {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/gemini-independent-reviewer/prompt.txt)" \
  > "{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/gemini-independent-reviewer/report.md" \
  2>&1 &
```

`report.md` が作成されたら完了とみなします（ポーリング判定）。

##### 1-A-4. 完了通知の待ち受けと質問対応

- Claude Teammate（codex-independent-reviewer 含む）からの SendMessage（「レビュー完了」通知）を待ち受け
- Gemini は `report.md` の出現をチェック

**質問対応**: Teammate から SendMessage で「質問があります」と通知を受けた場合:

1. `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{teammate-name}/questions.md` を Read
2. AskUserQuestion でユーザーに確認
3. 回答を `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{teammate-name}/answers.md` に Write
4. SendMessage で Teammate に「回答しました」と通知

---

#### Phase 1-B: 結果集約と Exit 判定

##### 1-B-1. 全 report.md を Read

`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{teammate-name}/report.md` を全ロール分 Read で読み込みます
（code-architecture-reviewer / security-reviewer / testing-reviewer / checklist-advisor、条件付きで infra-reviewer / codex-independent-reviewer / gemini-independent-reviewer。INFRA_REQUIRED / CODEX_UNAVAILABLE / GEMINI_UNAVAILABLE に応じて数が変動）。

##### 1-B-2. findings の統合

`agent-teams:multi-reviewer-patterns` skill を Skill ツールで参照し、以下を実施:

- **重複排除**: 同一箇所への同一指摘を統合（reviewer 名を複数明記）
- **severity 較正**: 過大/過小評価の補正
- **矛盾検出**: reviewer 間で判断が分かれる箇所の明確化
- **見落とし検出**: 対象ファイルに対する調査カバレッジの評価

結果を `phase-output-templates.md` の「aggregated-findings.md 統合フォーマット」（ID 体系含む）に従って
`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/aggregated-findings.md` に Write。

##### 1-B-3. Exit 判定

Exit 条件（本 SKILL.md「Exit 条件」節）を評価し、`phase-output-templates.md` の「exit-decision.md テンプレ」に従って
`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/exit-decision.md` に Write:

- いずれかの条件成立 → **Phase 2 へ進む**（Phase 1-C はスキップ）
- どの条件も不成立 → **Phase 1-C へ**

---

#### Phase 1-C: 修正実行

**Exit 判定で CONTINUE だった場合のみ実施。**

##### 1-C-1. 修正規模の判定

`aggregated-findings.md` から修正計画を作成し、`phase-output-templates.md` の「fix-plan.md テンプレ」に従って
`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/fix-plan.md` に Write。

**判定ルール**:

| 条件 | 実行方針 |
|------|---------|
| ファイル 1-2 かつ severity ≤ medium かつ機能変更なし | `SMALL_FIX_DIRECT`（リーダーが直接修正） |
| ファイル 3 以上 / severity ≥ high の構造変更 / DB・インフラ変更を含む | `LARGE_FIX_IMPLEMENT`（implement スキル起動 or 既存 implement チーム再利用） |

**Low 指摘も修正対象**: ファイル数が少なく軽微な Low なら SMALL_FIX_DIRECT で対応する。
「対応見送り推奨」と判断した Low のみ、`fix-plan.md` に理由付きで明記して残す（黙って無視しない）。

##### 1-C-2-A. SMALL_FIX_DIRECT の場合

リーダー自身が Edit ツールで対象ファイルを修正します:

1. Critical → High → Medium → Low の順
2. 各修正後、コード全体の整合性を簡易確認
3. 修正内容を `fix-plan.md` の末尾に追記（どの finding をどう修正したか）

修正完了後、iteration++ して Phase 1-A に戻ります（iteration が 6 になったら Phase 2 へ）。

##### 1-C-2-B. LARGE_FIX_IMPLEMENT の場合

**初回（implement チーム未起動の場合）**: `implement` スキルを Skill ツールで起動します。
引数は `phase-output-templates.md` の「implement スキル起動引数テンプレ」を使用してください
（findings / 影響ファイル / 制約 — 特に「commit & push しない」「作業完了後 Teammate を解散しない」を必ず含める）。

**🚨 implement チーム再利用の原則 🚨**: implement スキルが立ち上げた Teammate（implementer-leader / frontend / backend / infra / qa など）も、
review-loop の **全 iteration を通じて再利用**します。**毎 iteration で立て直さない**（解散させると次 iteration でゼロから設計理解し直す無駄が発生する。**Phase 3 まで在籍させ続けること**）。
implement チームの Teammate name は initial 起動時に確認し、`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/implement-team-roster.md` に記録しておくこと。

**2 回目以降の LARGE_FIX_IMPLEMENT（implement チーム起動済み）**: implement skill を再呼び出しせず、
前回 implement で起動した Teammate に **直接 SendMessage で追加修正を依頼**してください
（`phase-output-templates.md` の「implement チームへの追加修正依頼テンプレ」を使用）。

implement 関連の作業完了後、iteration++ して Phase 1-A に戻ります（iteration が 6 になったら Phase 2 へ）。

---

### Phase 2: 最終報告

ループを抜けたら、最終レポートを作成してユーザーに提示します。

#### 2-1. final-report.html の生成

**Step 2-1-a: final-report.md（MD ソース）を Write**

トークン節約のため、リーダーはまず **コンパクトな Markdown** で内容を
`phase-output-templates.md` の「final-report.md テンプレ」に従って
`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/final-report.md` に Write します。HTML 化は後段の {{REPORT_GENERATOR}} に委譲します。

**Step 2-1-b: {{REPORT_GENERATOR}} 委譲で HTML 生成を試みる**

```bash
bash {{TEMPLATE_DIR}}/generate-report-with-{{REPORT_GENERATOR}}.sh \
  --source-md   "{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/final-report.md" \
  --output-html "{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/final-report.html" \
  --title       "Review Loop 最終レポート - {{TASK_SLUG}}" \
  --context     "対象: {対象ファイル数} ファイル / ブランチ: {ブランチ名} / 反復: {N} 回"
```

スクリプト終了コード: **0** = HTML 生成成功 → Step 2-2 へ / **1** = {{REPORT_GENERATOR}} CLI 未インストール → Step 2-1-c へ / **2** = 実行失敗 → ログ確認後 Step 2-1-c へ。

**Step 2-1-c: フォールバック（リーダーが直接 HTML 生成）**

{{REPORT_GENERATOR}} が利用できない場合のみ実施。
`phase-output-templates.md` の「final-report.html フォールバック構造」に従って、
`{{TEMPLATE_DIR}}/report-template.html` をベースに Step 2-1-a の MD を HTML 化し、Write で出力する
（HTML 特殊文字のエスケープ必須）。

#### 2-2. ユーザーへの提示

リーダーは `final-report.html` の内容を要約してユーザーに報告してください。
レポート全文を貼り付けるのではなく、**以下の要点を抜き出してコンパクトに提示**:

1. **終了理由**（Exit Decision）
2. **反復サマリー表**
3. **残存指摘**（Critical / High / Medium のみ、Low は件数のみ）
4. **推奨次アクション**
5. **🔗 詳細レポート**: `[最終レポートを開く]({{EDITOR_URI_PREFIX}}{{WORKSPACE_ROOT}}/{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/final-report.html)` の形式で Markdown リンクとして提示。
   （クリックでエディタに HTML が開く。エディタ右上の **「Show Preview」ボタン**（Live Preview 拡張）でレンダリング表示できる旨を併記すること）

#### 2-3. commit 提案はしない

review-loop スキル自体は commit しません。ユーザーが明示的に指示した場合のみ commit 操作を行ってください。

---

### Phase 2.9: レビュー指摘チェックリストの最新化

最終報告後、**今回のループで蓄積した findings から再利用可能な教訓を抽出し**、
`{{REVIEW_CHECKLIST_PATH}}` に反映します。これにより、本ループの指摘が将来の実装・レビューに活きます。

#### 2-9-1. 教訓の抽出元

各 iteration の `aggregated-findings.md`（特に複数 reviewer が一致した指摘、繰り返し出た指摘）を教訓の源とします。
**1 回限りのこの差分でしか通用しない指摘は対象外**。汎用的に再利用できる教訓のみ拾います。

#### 2-9-2. 抽象化と統合

`review-checklist-update` スキルの **Phase 3（抽象化）と Phase 4（既存との突合・統合）のロジックを適用**してください
（本ループの findings を「指摘」の入力源として扱う）。要点:
`{{REVIEW_CHECKLIST_PATH}}` 冒頭の「設計方針」を Read して厳守（一過性情報を書かない / 類似は新規追加せず既存更新 / ライブラリ固有情報は残す）。
カテゴリ判定 → 既存と類似なら更新（`updated` を今日に）、新規なら該当カテゴリ末尾に追記。抽象化できない指摘は不採用。

#### 2-9-3. 反映（commit しない）

review-loop は **commit / push を行わない**スキルなので、ここでも `{{REVIEW_CHECKLIST_PATH}}` の
**ローカル編集のみ**を行い、変更点を Phase 2 の報告に「チェックリスト更新」として併記してください。
commit はユーザーが明示的に指示した場合のみ。該当する教訓が無ければ「チェックリスト更新: なし」と報告してスキップします。

---

### Phase 3: Teammate シャットダウン（review-loop の最終段階でのみ実施）

**🚨 Phase 2 の最終報告まで完了してから、はじめてシャットダウンする。** 途中の iteration では絶対にシャットダウンしない。

最終報告後、以下の順序でシャットダウンします（チームは implicit のため解体操作は不要）:

1. **review-loop の Teammate**（レビュアー全員）に `SendMessage` の `shutdown_request` を送信
2. **implement の Teammate**（implement skill が立てた Teammate がいる場合）にも同様に `shutdown_request`

**または** `agent-teams:team-shutdown` コマンドが利用可能な場合、そちらを優先して使用すること
（cleanup 漏れ防止のため）。implement チームについては、implement skill 側のシャットダウン手順に従うこと。

---

## 注意事項

- **🚨 cwd をワークスペースルート (`{{WORKSPACE_ROOT}}`) から動かさない**: 設定系ファイル（`{{AGENT_CONFIG_DIR}}/settings.json`、hooks、tool 許可ルール、CLAUDE.md、AGENTS.md など）は**ワークスペースルートにしか存在しない**。サブエージェントや Codex/agy (Gemini) CLI は**起動時の cwd に基づいて設定を探索する**ため、cwd がサブディレクトリ等に汚染された状態でチームを起動すると、settings が読まれず tool 許可・hooks が全て無効化されユーザー運用負荷が激増する。必ず以下を守ること:
  - Phase 1-A で Agent tool / codex / agy を起動する直前に `pwd` で cwd を確認し、`{{WORKSPACE_ROOT}}` 以外なら `cd {{WORKSPACE_ROOT}}` で戻してから起動する
  - Bash 内で `cd apps/web && ...` のような書き方をしない。代わりに `{{PACKAGE_MANAGER}} {{MONOREPO_FILTER_FLAG}} <pkg> ...` を使う（cd 汚染の根本原因を排除）
  - codex CLI は `codex exec --cd {{WORKSPACE_ROOT}} ...` で明示的に cwd 指定する
  - 違反の典型例: iteration の途中で `cd {{FRONTEND_PATH}} && {{TYPE_CHECK_COMMAND}}` を実行 → shell cwd が {{FRONTEND_PATH}} のまま → 次の iteration の Agent tool / codex が {{FRONTEND_PATH}} で起動し settings 無効化
- **🚨 Teammate（review-loop / implement とも）は iteration を跨いで再利用する**: 冒頭の「エージェント再利用の絶対原則」を厳守。implement skill を 2 回以上呼び出さない（毎回新しいチームができてしまう）。implement は独自の Phase を持つため iteration が長引く可能性があるが、implement 完了後は必ず review-loop 側に戻って再レビューすること
- **🚨 Low (軽微) 指摘も対応対象**: 冒頭の Low 原則を厳守。対応見送りする場合は理由付きで `final-report.html` に明記する
- **レビューフェーズでは絶対にコードに手を加えない**: Phase 1-A, 1-B は read-only。修正はリーダー（Edit）または implement チーム（既存または新規）に限定し、Teammate（レビュアー）には書き込みを行わせない
- **iteration 上限は厳守**: 5 反復に達したら無条件で Phase 2 へ（無限ループ防止）。収束判定は、同じ severity 構成が 2 iteration 連続で続き、修正してもこれ以上減らない場合に Phase 2 へ
- **Codex は Teammate として再利用、Gemini はステートレス**: Codex は `codex:codex-rescue` ラッパー側にコンテキストが残る。Gemini は毎 iteration `agy -p` を Bash バックグラウンドで再起動（prompt.txt 内の `{{PREV_FINDINGS}}` で文脈を運ぶ）
- **CLI 不在時の挙動**: Phase 0-4 で `which codex` / `which agy` を確認し、不在なら該当ロールをスキップ
- **infra-reviewer は条件付き起動**: Phase 0-1 で判定。判定が曖昧なら起動する側に倒す。初回起動以降は他と同様 SendMessage で再利用する
- **修正後の再レビューは必須**: Phase 1-C で修正したら iteration++ で必ず Phase 1-A に戻る
- **commit & push は明示的にユーザーから指示がない限り行わないこと**
- **対象差分が大きい場合**: 変更差分が 50 ファイル超になる場合は、レビュー対象をサブディレクトリ単位で分割して複数回 review-loop を実行することを検討
- **指示は `instruct.md` 経由、結果は `report.md` 経由でファイルベース通信を行うこと**。Teammate 間の直接通信は禁止（すべてリーダーが仲介）
- **Teammate からのメッセージは自動配信**されるため、手動ポーリング不要。Teammate が idle になるのは正常な動作（メッセージ送信後の待機状態。次 iteration の SendMessage を待っている）
