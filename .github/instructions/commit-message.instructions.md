Write a concise and descriptive commit message based solely on the provided changes. Follow these strict rules:

- **Use the correct gitmoji** from the provided list to represent the type of change.
- Use the **imperative mood** in the subject line.
- Be **specific** about what was changed:
  - Mention **exact names** of files, variables, functions or settings updated.
  - Include **exact values** or details where applicable.
  - Describe **code changes** precisely.
- **Avoid vague terms** like "update", "enhance", "improve", or "better".
- **Do not include speculative justifications** like "to improve A", "for better B", "for improved C", "to enhance D". Instead, **only describe what was done**.
- If multiple changes are made, pick the most significant one and describe it in detail.

- Be make sure AI commit messages are in English.

## Important: Avoid these patterns at all costs

- "Update settings" → Always describe **what was updated**.
- "Improve formatting" → Always describe the **specific formatting changes**.
- "Add instructions" → Specify **what the instructions are about and where they were added**.

## Rewrite vague messages into specific messages

- **Bad:** 🔧 Update GitHub Copilot settings and instructions for improved code generation and review selection
  **Good:** 🔧 Link to 7 files under `github.copilot.chat` in VSCode's GitHub Copilot settings

- **Bad:** 🔧 Update configuration files for better formatting
  **Good:** 🔧 Set `printWidth` to 80 in `.prettierrc.yaml`

- **Bad:** 🎨 Reformat files for better consistency
  **Good:** 🎨 Reformat `index.html` with tabs instead of 2 spaces

- **Bad:** 🔥 Remove unused variables
  **Good:** 🔥 Remove `unusedHelper` in `utils.js`

## Examples of good commit messages

- ♻️ Refactor `ValidateBlock` in `consensus/congress/congress.go`
- ⚡️ Use `big.Int` instead of `uint64` for gas calculations in `core/types/transaction.go`
- ✨ Add `PosaMergeTime` field to `ChainConfig` in `params/config.go`
- 🎨 Reformat `miner/worker.go` with proper Go formatting
- 🔥 Remove `unusedValidator` from `consensus/congress/congress.go`
- 🔧 Set `Period` to 3 seconds in `MainnetChainConfig`
- 🐛 Fix nil pointer dereference in `blockchain.InsertChain`
- 🔐 Add signature validation in `congress.VerifyHeader`
