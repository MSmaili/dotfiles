/**
 * /usage — remaining usage & credits for your AI providers.
 *
 * Providers are pluggable adapters (see adapters/). Each adapter knows how
 * to talk to one account service; the renderers (overlay dashboard, transcript
 * card, tool text) only consume the shared ProviderSnapshot shape.
 *
 *   /usage             overlay dashboard
 *   /usage json        dump raw JSON (scripting)
 *   /usage refresh     bypass the 60s cache
 *
 * The LLM can also call the usage_check tool mid-task ("how much usage is
 * left?"). No secrets live in this code: credentials are read at runtime
 * from ~/.pi/agent/auth.json (or OPENAI_CODEX_* / OPENCODE_*_API_KEY env
 * vars) and are never logged.
 */

import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { runAllAdapters } from "./adapters/index.ts";
import type { ProviderSnapshot, UsageSnapshot } from "./adapters/types.ts";
import { buildCardLines, usageCardRenderer, type UsageCardData } from "./card.ts";
import { PANEL_WIDTH, UsageDashboard } from "./dashboard.ts";
import { formatSummaryText, oneLineSummary } from "./summary.ts";
import { Text } from "@earendil-works/pi-tui";

const SHOW_CARD_IN_TRANSCRIPT = process.env.PI_USAGE_SHOW_CARD === "1";

export default function (pi: ExtensionAPI): void {
	pi.registerCommand("usage", {
		description: "Show remaining usage & credits for AI providers (chatgpt, go, zen)",
		handler: async (args, ctx) => {
			const arg = args.trim().toLowerCase();
			const force = arg.includes("refresh") || arg.includes("force");
			const snapshot = await runAllAdapters(force);

			if (arg === "json" || arg === "--json") {
				console.log(JSON.stringify(snapshot, null, 2));
				return;
			}

			if (SHOW_CARD_IN_TRANSCRIPT) {
				// Durable transcript card — never sent to the LLM.
				pi.appendEntry<UsageCardData>("usage-card", {
					at: snapshot.generatedAt,
					providers: snapshot.providers,
				});
			}

			if (ctx.mode === "tui") {
				await ctx.ui.custom<void>(
					(_tui, theme, _keybindings, done) =>
						new UsageDashboard(snapshot, theme, () => done()),
					{
						overlay: true,
						overlayOptions: { anchor: "center", width: PANEL_WIDTH, margin: 1 },
					},
				);
			} else if (ctx.hasUI) {
				ctx.ui.notify(oneLineSummary(snapshot), "info");
			}
		},
	});

	pi.registerTool({
		name: "usage_check",
		label: "Usage Check",
		description:
			"Check remaining usage and credits for the connected AI providers (ChatGPT plan, OpenCode Go, OpenCode Zen). Returns percent remaining per usage window, reset times, credits and spend-control status. Use when the user asks about remaining quota, usage, or credits.",
		promptSnippet: "Check remaining quota/credits for connected AI providers",
		parameters: Type.Object({}),
		async execute() {
			const snapshot = await runAllAdapters();
			return {
				content: [{ type: "text", text: formatSummaryText(snapshot) }],
				details: { providers: snapshot.providers, generatedAt: snapshot.generatedAt },
			};
		},
		renderResult(
			result: { details?: { providers?: unknown } },
			options: { expanded: boolean },
			theme: Theme,
		) {
			const providers = result.details?.providers;
			if (!Array.isArray(providers)) return new Text("", 0, 0);
			return new Text(
				buildCardLines(theme, providers as ProviderSnapshot[], options.expanded).join("\n"),
				0,
				0,
			);
		},
	});

	pi.registerEntryRenderer<UsageCardData>("usage-card", usageCardRenderer);
}

export type { UsageSnapshot } from "./adapters/types.ts";