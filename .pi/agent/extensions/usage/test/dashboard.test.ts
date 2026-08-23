import assert from "node:assert/strict";
import test from "node:test";
import type { Theme } from "@earendil-works/pi-coding-agent";
import { stripTerminalSequences, visibleWidth } from "@earendil-works/pi-tui";
import type { UsageSnapshot } from "../adapters/types.ts";
import { PANEL_WIDTH, UsageDashboard } from "../dashboard.ts";

const theme = {
	fg: (_color: string, text: string) => `\x1b[36m${text}\x1b[39m`,
	bold: (text: string) => `\x1b[1m${text}\x1b[22m`,
} as unknown as Theme;

const snapshot: UsageSnapshot = {
	generatedAt: "2026-08-23T15:27:04Z",
	providers: [
		{
			provider: "opencode-go",
			displayName: "go",
			status: "ok",
			windows: [{ id: "rolling", label: "5-hour rolling", percentUsed: 13 }],
			extra: [],
			fetchedAt: "2026-08-23T15:27:04Z",
		},
		{
			provider: "opencode-zen",
			displayName: "zen",
			status: "unavailable",
			message: "No public balance API. Track spend at https://opencode.ai/zen.",
			windows: [],
			extra: [],
			fetchedAt: "2026-08-23T15:27:04Z",
		},
	],
};

test("dashboard keeps every framed row aligned to the render width", () => {
	const dashboard = new UsageDashboard(snapshot, theme, () => {});

	for (const width of [48, PANEL_WIDTH, 100]) {
		const lines = dashboard.render(width);
		assert.ok(lines.length > 0);
		assert.ok(lines.every((line) => visibleWidth(line) === width));
	}
});

test("dashboard separates labels from bars and omits empty reset times", () => {
	const output = stripTerminalSequences(
		new UsageDashboard(snapshot, theme, () => {}).render(PANEL_WIDTH).join("\n"),
	);

	assert.match(output, /5-hour rolling █/);
	assert.doesNotMatch(output, /\(\)/);
});
