# /usage — provider usage & credits extension

Shows remaining usage and credits for your AI providers as a TUI dashboard
and a tool the model can call mid-task. A durable transcript card is optional.

```
┌─────────────────────────────────────────────────────────────────┐
│  usage · provider usage & credits                      15:27:04 │
├─────────────────────────────────────────────────────────────────┤
│ ● chatgpt · PLUS                                        ● ok    │
│   weekly      ████████████████  40% left · in 5d 2h (Fri 20:28) │
│   spend control: off · reset credits available: 1               │
├─────────────────────────────────────────────────────────────────┤
│ ● go                                                      ● ok  │
│   5-hour rolling  ████████████████  89% left · in 3h 4m         │
│   weekly          █████████░░░░░░░  45% left · in 8h 32m        │
│   monthly         ███░░░░░░░░░░░░░   3% left · in 8d 4h         │
├─────────────────────────────────────────────────────────────────┤
│ ● zen                                                      ● n/a│
│   no public balance API yet (404). Track spend via the          │
│   dashboard at https://opencode.ai/zen.                         │
├─────────────────────────────────────────────────────────────────┤
│ esc / enter / q close                60s cache · /usage refresh │
└─────────────────────────────────────────────────────────────────┘
```

Bars are colored green/amber/red by how much is left (≥40% green, ≥20% amber,
else red).

## Usage

```
/usage              show the dashboard overlay
/usage refresh      bypass the 60s in-memory cache
/usage json         print raw JSON for scripting
```

The TUI is overlay-only by default. To also append a durable transcript card,
set `PI_USAGE_SHOW_CARD=1` before starting pi. The card remains local and is
never sent to the LLM.

The LLM can also call the `usage_check` tool — e.g. "how much usage do I have
left?" — and gets a plain-text summary with exact numbers and reset times.

## Architecture: providers are adapters

```
usage/
  index.ts            command (/usage) + tool (usage_check) + card renderer
  adapters/
    types.ts          ProviderSnapshot / UsageWindow — the render contract
    credentials.ts    runtime credential resolution (never stored in repo)
    http.ts           JSON fetch with timeout
    chatgpt.ts        ChatGPT plan (WHAM usage endpoint + OAuth refresh)
    opencode.ts       OpenCode Go usage + OpenCode Zen (probe)
    index.ts          adapter registry + cache
  dashboard.ts        overlay panel components + line builders
  card.ts             transcript card renderer
  summary.ts          plain-text rendering (tool result / non-TUI)
  format.ts           resets-in / clock formatters
```

Adding a provider = one adapter file + one line in `adapters/index.ts`.
The UI never changes; it only consumes `ProviderSnapshot`.

### What each adapter queries

| Adapter | Endpoint | Auth | Status |
|---|---|---|---|
| `chatgpt` | `GET https://chatgpt.com/backend-api/wham/usage` | Bearer access token + `ChatGPT-Account-Id` | Returns plan type, per-window used %, reset times, credits balance, spend-control state, reset credits. Also does OAuth refresh via `auth.openai.com/oauth/token` on 401 and persists tokens back into pi's auth store. **Unofficial endpoint — schema may change; the parser handles legacy + current shapes.** |
| `opencode-go` | `GET https://opencode.ai/zen/go/v1/usage` | Bearer API key | Rolling (5h) / weekly / monthly used % + reset times (same data opencode's TUI shows). |
| `opencode-zen` | `GET https://opencode.ai/zen/v1/usage` (probe) | Bearer API key | No public balance API exists today (open feature request). The adapter probes the endpoint so it lights up automatically if opencode ships it; until then it reports `unavailable` with a pointer to the dashboard. |

## Security — safe to push this repo

- **No secrets, tokens, account IDs, or personal values exist in this code.**
  Everything is resolved at runtime by `adapters/credentials.ts`:
  - primary source: `~/.pi/agent/auth.json` (pi's own auth store — excluded
    from this repo via `.gitignore`)
  - env fallbacks: `OPENAI_CODEX_ACCESS_TOKEN`, `OPENAI_CODEX_REFRESH_TOKEN`,
    `OPENAI_CODEX_ACCOUNT_ID`, `OPENAI_OAUTH_CLIENT_ID`,
    `OPENCODE_ZEN_API_KEY`, `OPENCODE_GO_API_KEY`
- Tokens are only held in memory; errors are redacted before display.
- The OAuth `client_id` for refresh is decoded from the access token's JWT at
  runtime, not hardcoded.
- Only three hosts are ever contacted: `chatgpt.com`, `opencode.ai`,
  `auth.openai.com` (refresh only, on 401).

## Setup on a fresh machine

```bash
ln -s ../../../dotfiles/.pi/agent/extensions/usage ~/.pi/agent/extensions/usage
cd ~/.pi/agent/extensions && npm install   # pulls typebox (tool schema)
```

Then `/reload` in pi (extensions in `~/.pi/agent/extensions/` hot-reload).
Sign in with pi's `/login` → `openai-codex` for the ChatGPT adapter; the
opencode keys come from the same auth store.

## Notes

- Responses are cached 60s in-memory; `/usage refresh` bypasses.
- Transcript cards are disabled by default; set `PI_USAGE_SHOW_CARD=1` to enable them.
- The WHAM endpoint and the go usage endpoint are unofficial; if parsing
  breaks after an OpenAI/opencode update, check `adapters/chatgpt.ts` /
  `adapters/opencode.ts` and the shape comments there.
- Typecheck/tests: `npm run check` from `~/.pi/agent/extensions/`.