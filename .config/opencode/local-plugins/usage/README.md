# OpenCode usage

Native OpenCode V2 server + TUI plugin, sharing the Pi extension's usage parsers.

```text
/usage               open the quota dashboard
/usage refresh       bypass the 60-second cache
/usage json          show the normalized JSON in a scrollable dialog
/usage refresh json  refresh and show JSON
```

Inside the dashboard: **r** refreshes; **Esc**, **Enter**, or **q** closes.
The command palette also offers **Show provider usage & credits**. The dashboard
does not add conversation messages or make a model request. The model can use
`usage_check` (optional `refresh: true`) when asked about remaining quota.

## Accounts

Credentials come from OpenCode's active integration connections. OpenCode owns
OAuth resolution/refresh; this plugin never reads or writes Pi's auth store.

| Display | OpenCode integration | Information |
| --- | --- | --- |
| chatgpt | `openai` with ChatGPT OAuth | Five-hour/weekly quotas, reset times, credits |
| go | Active Go provider's integration: shared `opencode` Console OAuth or dedicated `opencode-go` API key | Rolling, weekly, monthly quota |
| opencode / zen | `opencode` Console OAuth or API key | Console credits/available balance; legacy keys probe the Zen balance endpoint |
| z.ai | `zhipuai-coding-plan` (China), otherwise `zai-coding-plan` (global) | Coding-plan windows |

Go follows the provider's actual `integrationID`, so Console-managed Go uses the
same account and workspace as model requests. OAuth requests use the configured
Console server and workspace header. The Go status and billing status endpoints
are the read-only APIs used by the Console dashboard; they are internal APIs
and may change. The Go meters match Console; effective model allowances vary.

Usage belongs to the provider account/plan, not to one session. An
unconnected provider is shown as unavailable. The cache is account-specific and
held only in memory. Provider failures are independent; requests time out after
15 seconds and are cancelled when the dialog closes or the tool is stopped.

These usage endpoints are unofficial and can change. A rejected authorization
asks you to reconnect the relevant account in OpenCode. A workspace permission
error is reported separately. Legacy API-key connections still use the original
Go/Zen endpoints.

## Installation

The global `opencode.json` loads `./local-plugins/usage`. Run `restow` after
adding the files on a fresh machine, then reopen OpenCode if the command has
not appeared. OpenCode resolves the plugin SDK and TUI libraries at runtime.
Keep the dotfiles layout intact: `shared.ts` imports pure parsers and formatting
helpers under `.pi/agent/extensions/usage/`, not Pi's adapters or credential code.
Pi itself need not be installed.

## Code layout

- `index.ts` registers the tool and RPC; `rpc.ts` defines their shared input schema
  and the RPC output contract.
- `providers.ts` selects active accounts and builds provider-specific requests.
- `collector.ts` handles fetching, failure isolation, cancellation, normalization,
  and the account-scoped cache. Older requests cannot overwrite a newer refresh.
- `console.ts` parses Console's Go meters and billing balances.
- `tui.tsx` separates command registration, dashboard state, and snapshot rendering.
- `shared.ts` exposes the host-independent parsers, formatters, and types.

Collected reset timestamps are validated and normalized to epoch milliseconds.
Invalid reset times are omitted and displayed as unknown.

For scripting, the server exposes a read-only RPC:

```sh
opencode api post /api/rpc/dotfiles.usage/check --data '{"input":{"refresh":true}}'
```

For development (tested against OpenCode 2.0.18):

```sh
cd ~/.config/opencode/local-plugins/usage
npm ci --ignore-scripts
npm run check
```
