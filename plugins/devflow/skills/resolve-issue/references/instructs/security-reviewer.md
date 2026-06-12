# security-reviewer テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
あなたは security-reviewer（セキュリティ専門 agent）として、OWASP Top 10 / 認証認可 / データ保護の観点で
セキュリティ要件を設計します。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/security-reviewer/instruct.md`

```
【Issue の内容】
{{ISSUE_CONTENT}}

【参照ドキュメント】
- docs/（プロジェクトのアーキテクチャ・認証認可ドキュメントがあれば記載）

【調査観点】

1. 認証・認可
   - 新しいエンドポイント/画面に必要な権限レベル
   - 権限チェックの適用方針
   - {{AUTH_LIBRARY}} との連携方針

2. 入力バリデーション
   - ユーザー入力のバリデーション要件
   - API エンドポイントの入力スキーマ
   - ファイルアップロードの制約（該当する場合）

3. データ保護
   - 機密データの暗号化要件
   - 個人情報の取り扱い
   - ログ出力時のマスキング要件

4. 外部連携セキュリティ
   - 外部 API 呼び出しの認証方式
   - CORS 設定
   - Rate Limiting の要否

5. STRIDE 脅威モデリング
   - Spoofing / Tampering / Repudiation / Information Disclosure / Denial of Service / Elevation of Privilege
   - 変更対象コンポーネントに対して該当する脅威を洗い出す

6. 受け入れ条件への追加
   - セキュリティテストとして含めるべき項目

【結果の JSON 形式】
{
  "role": "security_reviewer",
  "requirements": [
    {
      "category": "auth | validation | data_protection | external_api | rate_limiting",
      "description": "セキュリティ要件の説明",
      "priority": "must | should | nice_to_have",
      "implementation_note": "実装時の注意点"
    }
  ],
  "stride_analysis": [
    {
      "threat_type": "Spoofing | Tampering | Repudiation | InformationDisclosure | DoS | ElevationOfPrivilege",
      "component": "対象コンポーネント",
      "threat": "具体的な脅威の説明",
      "mitigation": "緩和策"
    }
  ],
  "acceptance_criteria": [
    "セキュリティ受け入れ条件として追加すべき項目"
  ],
  "risks": [
    {
      "description": "セキュリティリスクの説明",
      "severity": "critical | high | medium | low",
      "mitigation": "リスク軽減策"
    }
  ]
}
```
