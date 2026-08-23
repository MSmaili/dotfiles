/**
 * Plain-text rendering of a UsageSnapshot.
 *
 * Used for the usage_check tool result (sent to the LLM) and for the
 * non-TUI fallback of the /usage command. No ANSI codes — the model and
 * terminals see clean text.
 */

import type { ProviderSnapshot, UsageSnapshot } from "./adapters/types.ts";
import { formatResetTime, formatResetsIn, formatWindowLabel, remainingPercent } from "./format.ts";

export function formatSummaryText(snapshot: UsageSnapshot): string {
	const parts: string[] = [];
	for (const provider of snapshot.providers) {
		parts.push(providerText(provider));
	}
	return parts.join("\n");
}

export function oneLineSummary(snapshot: UsageSnapshot): string {
	return snapshot.providers
		.map((provider) => {
			if (provider.status === "ok" && provider.windows.length > 0) {
				const best = provider.windows[0]!;
				const rest = provider.windows
					.slice(1)
					.map((window) => `${formatWindowLabel(window)} ${remainingPercent(window)}%`)
					.join(", ");
				return `${provider.displayName}: ${remainingPercent(best)}% left of ${formatWindowLabel(best)}${rest ? ` (${rest})` : ""}`;
			}
			return `${provider.displayName}: ${provider.status}`;
		})
		.join(" · ");
}

function providerText(provider: ProviderSnapshot): string {
	// Prefix flexibility for grepping; labels are stable across renders.
	const heading = provider.plan
		? `${provider.provider} (${provider.displayName}, ${provider.plan})`
		: `${provider.provider} (${provider.displayName})`;

	if (provider.status !== "ok") {
		return `${heading}: ${provider.status} — ${provider.message ?? "no information"}`;
	}

	const lines: string[] = [];
	for (const window of provider.windows) {
		const reset = formatResetsIn(window);
		const time = formatResetTime(window);
		lines.push(
			`  - ${formatWindowLabel(window)}: ${remainingPercent(window)}% left (${Math.round(window.percentUsed)}% used) · resets ${reset}${time ? ` (${time})` : ""}`,
		);
	}
	for (const extra of provider.extra) {
		lines.push(`  - ${extra}`);
	}
	if (lines.length === 0) lines.push("  - no window data");

	return [`${heading}:`, ...lines].join("\n");
}