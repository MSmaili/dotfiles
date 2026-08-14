import type { Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export function fit(text: string, width: number): string {
	const safeWidth = Math.max(0, width);
	const truncated = truncateToWidth(text, safeWidth, "…");
	return `${truncated}${" ".repeat(Math.max(0, safeWidth - visibleWidth(truncated)))}`;
}

export function pad(lines: readonly string[], height: number, width: number): string[] {
	const output = lines.map((line) => fit(line, width));
	while (output.length < height) output.push(" ".repeat(Math.max(0, width)));
	return output.slice(0, height);
}

export function shorten(text: string, width: number): string {
	return truncateToWidth(text.replace(/\s+/g, " "), Math.max(0, width), "…");
}

export function wrap(text: string, width: number): string[] {
	if (width <= 0) return [];
	const words = text.split(/\s+/).filter(Boolean);
	if (words.length === 0) return [""];

	const lines: string[] = [];
	let current = "";
	for (const word of words) {
		if (visibleWidth(word) > width) {
			if (current) {
				lines.push(current);
				current = "";
			}
			let remaining = word;
			while (remaining) {
				const chunk = truncateToWidth(remaining, width, "");
				if (!chunk) break;
				lines.push(chunk);
				remaining = remaining.slice(chunk.length);
			}
			continue;
		}

		const candidate = current ? `${current} ${word}` : word;
		if (visibleWidth(candidate) <= width) current = candidate;
		else {
			lines.push(current);
			current = word;
		}
	}
	if (current) lines.push(current);
	return lines;
}

export function frameLine(theme: Theme, content: string, innerWidth: number): string {
	return `${theme.fg("borderAccent", "│")}${fit(content, innerWidth)}${theme.fg("borderAccent", "│")}`;
}

export function divider(theme: Theme, innerWidth: number): string {
	return theme.fg("borderMuted", `├${"─".repeat(Math.max(0, innerWidth))}┤`);
}

export function topBorder(theme: Theme, innerWidth: number): string {
	return theme.fg("borderAccent", `┌${"─".repeat(Math.max(0, innerWidth))}┐`);
}

export function bottomBorder(theme: Theme, innerWidth: number): string {
	return theme.fg("borderAccent", `└${"─".repeat(Math.max(0, innerWidth))}┘`);
}

export function combineColumns(
	left: readonly string[],
	right: readonly string[],
	leftWidth: number,
	rightWidth: number,
	separator: string,
): string[] {
	const rows = Math.max(left.length, right.length);
	return Array.from(
		{ length: rows },
		(_, index) => `${fit(left[index] ?? "", leftWidth)}${separator}${fit(right[index] ?? "", rightWidth)}`,
	);
}
