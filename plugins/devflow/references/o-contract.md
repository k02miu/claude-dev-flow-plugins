# O 契約: 意思決定 report のスキーマ（共有）

オーケストレーション skill の「意思決定チェックポイント」出力（実装プラン / レビュー最終 findings 等）が満たす出力契約。
**機械検証可能な構造**（JSON Schema）と**その人間可読レンダリング**の両方を O に含める。

参照: `${CLAUDE_PLUGIN_ROOT}/references/o-contract.md`

主経路（workflow）では `agent({schema})` の検証済み返り値として、副経路（Agent Teams）では teammate の `report.md` 出力フォーマットとして、**同一の契約**を両経路で使う。

---

## 1. criticalDecisions（クリティカル判断の構造的強制）

「下した重要判断を列挙せよ」と緩く書くとモデルは自分の判断を過小報告する（self-preferential bias）。
対策として**報告カテゴリを名前付き必須フィールドで強制する**。該当なしでも省略は許さず、`notApplicable` + 理由を明示させる。

```jsonc
{
  "criticalDecisions": {
    "backwardCompatibility": {            // 必須キー（省略不可）
      "status": "decided | notApplicable",
      "decision": "string",               // 下した判断（notApplicable なら空可）
      "rationale": "string",              // notApplicable でも理由必須
      "rejectedAlternatives": ["string"], // 検討して棄却した代替案
      "confidence": "high | medium | low",
      "reversibility": "reversible | costly | irreversible"
    },
    "securityTradeoff":   { /* 同形 */ },
    "irreversibleAction": { /* 同形。該当ありなら status=decided 必須 */ },
    "dataModelChange":    { /* 同形。DB スキーマ・マイグレーション判断 */ }
  }
}
```

ルール:

- 4 カテゴリは**キーの存在自体が必須**。`notApplicable` を選ぶにも `rationale` を要求する。
- `reversibility` は全カテゴリに持たせる（allowlist 封じ込め判断と連動。`irreversible` なものは `workflow-capability.md` §3 に従い allowlist から外す）。
- workflow 主経路では、この構造を `agent({schema})` の JSON Schema として渡す（不一致は自動 retry）。空の `criticalDecisions: {}` は schema 違反として弾く。

---

## 2. 人間可読レンダリング

schema に通った構造データを、最終 report（`final-report.html` / `report.md`）の「下した重要判断」セクションへレンダリングする。

- `status: decided` のカテゴリ: 判断 / 根拠 / 棄却した代替案 / confidence / reversibility を表示。
- `status: notApplicable` のカテゴリ: 「該当なし」と理由を 1 行で表示（黙って省略しない）。
- `reversibility: irreversible | costly` の項目は視覚的に強調し、人間が事後に必ず目を通せるようにする。

この report は**同期ゲートではない**。実行をブロックして承認を待つものではなく、決定して進んだ結果の監査面を出力アーティファクトとして残すもの。
