/**
 * The /usage dashboard panel.
 *
 * Rendered as an overlay via ctx.ui.custom() (TUI mode). Frame helpers come
 * from the shared extension UI module so the panel matches pi's own dialogs.
 */

import type { Theme } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, visibleWidth, type Component } from "@earendil-works/pi-tui";
import { bottomBorder, divider, fit, frameLine, topBorder, wrap } from "../shared/ui.ts";
import type { ProviderSnapshot, UsageSnapshot, UsageWindow } from "./adapters/types.ts";
import {
	formatClock,
	formatResetTime,
	formatResetsIn,
	formatWindowLabel,
	remainingPercent,
} from "./format.ts";

/** Total overlay width, including the frame. */
export const PANEL_WIDTH = 84;

type SeverityColor = "success" | "warning" | "error";

/** Overlay component: closes on esc / ctrl+c / enter / q. */
export class UsageDashboard implements Component {
	private readonly snapshot: UsageSnapshot;
	private readonly theme: Theme;
	private readonly onClose: () => void;

	constructor(snapshot: UsageSnapshot, theme: Theme, onClose: () => void) {
		this.snapshot = snapshot;
		this.theme = theme;
		this.onClose = onClose;
	}

	handleInput(data: string): void {
		if (
			matchesKey(data, Key.escape) ||
			matchesKey(data, Key.ctrl("c")) ||
			matchesKey(data, Key.enter) ||
			data === "q"
		) {
			this.onClose();
		}
	}

	invalidate(): void {}

	render(width: number): string[] {
		if (width < 2) return [];
		return buildPanelLines(this.theme, this.snapshot, width - 2);
	}
}

/** Panel lines including the frame. */
export function buildPanelLines(theme: Theme, snapshot: UsageSnapshot, innerWidth: number): string[] {
	const out: string[] = [];
	out.push(topBorder(theme, innerWidth));
	out.push(frameLine(theme, "", innerWidth)); // breathing room inside the frame
	out.push(
		row(
			theme,
			innerWidth,
			`${theme.fg("accent", theme.bold("usage"))} ${theme.fg("dim", "· provider usage & credits")}`,
			theme.fg("dim", formatClock(snapshot.generatedAt)),
		),
	);
	out.push(frameLine(theme, "", innerWidth));

	snapshot.providers.forEach((provider, index) => {
		if (index > 0) out.push(divider(theme, innerWidth));
		out.push(...providerSection(theme, provider, innerWidth));
	});

	out.push(divider(theme, innerWidth));
	out.push(frameLine(theme, "", innerWidth)); // breathing room inside the frame
	out.push(
		row(
			theme,
			innerWidth,
			theme.fg("dim", "esc / enter / q close"),
			theme.fg("dim", "60s cache · /usage refresh"),
		),
	);
	out.push(frameLine(theme, "", innerWidth));
	out.push(bottomBorder(theme, innerWidth));
	return out;
}

/* ------------------------------------------------------------------ */

function providerSection(theme: Theme, provider: ProviderSnapshot, innerWidth: number): string[] {
	const lines: string[] = [];
	const contentWidth = Math.max(0, innerWidth - 2);
	const wrappedWidth = Math.max(1, innerWidth - 4);

	const chip = statusChip(theme, provider.status);
	const heading =
		`${theme.fg("accent", "●")} ${theme.bold(provider.displayName)}` +
		(provider.plan ? ` ${theme.fg("muted", `· ${provider.plan}`)}` : "");
	lines.push(row(theme, innerWidth, heading, chip));

	if (provider.status === "ok") {
		for (const window of provider.windows) {
			lines.push(frameLine(theme, windowRow(theme, window, contentWidth), innerWidth));
		}
	}

	for (const extra of provider.extra) {
		for (const line of wrap(extra, wrappedWidth)) {
			lines.push(frameLine(theme, `${theme.fg("dim", "  ")}${theme.fg("muted", line)}`, innerWidth));
		}
	}

	if (provider.message) {
		const color = provider.status === "error" ? "error" : "dim";
		for (const line of wrap(provider.message, wrappedWidth)) {
			lines.push(frameLine(theme, `${theme.fg("dim", "  ")}${theme.fg(color, line)}`, innerWidth));
		}
	}

	return lines;
}

function windowRow(theme: Theme, window: UsageWindow, width: number): string {
	const label = fit(theme.fg("muted", formatWindowLabel(window)), 14);
	const left = remainingPercent(window);
	const bar = usageBar(theme, left / 100, 12);
	const percent = fit(theme.fg(severityColor(left), `${left}% left`), 8);
	const reset = theme.fg("dim", formatResetsIn(window));
	const resetTime = formatResetTime(window);
	const time = resetTime ? theme.fg("dim", `(${resetTime})`) : "";
	const content = `  ${label} ${bar} ${percent} ${reset}${time ? ` ${time}` : ""}`;
	return fit(content, width);
}

function usageBar(theme: Theme, fraction: number, width: number): string {
	const clamped = Math.min(1, Math.max(0, fraction));
	let filled = Math.round(clamped * width);
	// A tiny sliver keeps a nearly-exhausted window visible in the bar.
	if (filled === 0 && clamped > 0) filled = 1;
	return (
		theme.fg(severityColor(clamped * 100), "█".repeat(filled)) +
		theme.fg("dim", "░".repeat(width - filled))
	);
}

function severityColor(remainingPercentValue: number): SeverityColor {
	return remainingPercentValue >= 40 ? "success" : remainingPercentValue >= 20 ? "warning" : "error";
}

function statusChip(theme: Theme, status: ProviderSnapshot["status"]): string {
	if (status === "ok") return theme.fg("success", "● ok");
	if (status === "unavailable") return theme.fg("warning", "● n/a");
	return theme.fg("error", "● error");
}

function row(theme: Theme, width: number, left: string, right: string): string {
	const rightWidth = visibleWidth(right);
	// Same 2-col inset on both sides: right content also gets trailing padding.
	return frameLine(theme, `${fit(`  ${left}`, Math.max(0, width - rightWidth - 2))}${right}`, width);
}