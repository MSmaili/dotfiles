/**
 * Durable "usage card" rendered in the transcript (custom entry, not sent
 * to the LLM). When PI_USAGE_SHOW_CARD=1, /usage appends one after each run;
 * collapsed it shows one line per provider, expanded it shows every window and note.
 * The same line builder powers the usage_check tool's result rendering.
 */

import type { EntryRenderer, Theme } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";
import type { ProviderSnapshot } from "./adapters/types.ts";
import {
	formatClock,
	formatResetTime,
	formatResetsIn,
	formatWindowLabel,
	remainingPercent,
} from "./format.ts";

export interface UsageCardData {
	at: string;
	providers: ProviderSnapshot[];
}

export const usageCardRenderer: EntryRenderer<UsageCardData> = (entry, { expanded }, theme) => {
	const data = entry.data ?? { at: "", providers: [] };
	const lines = buildCardLines(theme, data.providers, expanded, data.at);
	const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
	box.addChild(new Text(lines.join("\n"), 0, 0));
	return box;
};

/** Shared by the entry renderer and the usage_check tool result. */
export function buildCardLines(
	theme: Theme,
	providers: readonly ProviderSnapshot[],
	expanded: boolean,
	at = "",
): string[] {
	const lines: string[] = [];
	lines.push(
		`${theme.fg("accent", theme.bold("usage"))} ${theme.fg("dim", at ? `· ${formatClock(at)}` : "")}`,
	);
	for (const provider of providers) {
		lines.push(...providerCardLines(theme, provider, expanded));
	}
	return lines;
}

function providerCardLines(theme: Theme, provider: ProviderSnapshot, expanded: boolean): string[] {
	const heading =
		`${theme.fg("accent", "●")} ${theme.bold(provider.displayName)}` +
		(provider.plan ? ` ${theme.fg("muted", `· ${provider.plan}`)}` : "");

	if (provider.status !== "ok") {
		const note = (provider.message ?? provider.status).replace(/\s+/g, " ");
		const clipped = note.length > 96 ? `${note.slice(0, 93)}…` : note;
		return [`${heading} ${theme.fg("warning", `— ${clipped}`)}`];
	}

	const windows = provider.windows.map((window) => {
		const left = remainingPercent(window);
		const base = `${formatWindowLabel(window)} ${left}%`;
		return expanded
			? `${base} · resets ${formatResetsIn(window)}${formatResetTime(window) ? ` (${formatResetTime(window)})` : ""}`
			: `${base} left`;
	});

	const extras = provider.extra.slice(0, expanded ? provider.extra.length : 2);
	const suffix = extras.length > 0 ? ` · ${extras.join(" · ")}` : "";
	return [`${heading} ${theme.fg("text", windows.join(" · "))}${theme.fg("dim", suffix)}`];
}