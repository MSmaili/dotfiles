import type { ExtensionContext, SlashCommandInfo, Theme } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, type TUI } from "@earendil-works/pi-tui";
import { filterSkills } from "./filter.ts";
import {
	bottomBorder,
	combineColumns,
	divider,
	fit,
	frameLine,
	pad,
	shorten,
	topBorder,
	wrap,
} from "../shared/ui.ts";

interface PromptRecord {
	name: string;
	description: string;
	filePath: string;
	sourceInfo: SlashCommandInfo["sourceInfo"];
}

export async function showPromptPicker(
	ctx: ExtensionContext,
	commands: readonly SlashCommandInfo[],
	initialSearch = "",
): Promise<PromptRecord | undefined> {
	const prompts = commands
		.filter((command) => command.source === "prompt")
		.map((command) => ({
			name: command.name,
			description: command.description ?? "No description",
			filePath: command.sourceInfo.path,
			sourceInfo: command.sourceInfo,
		}))
		.sort((left, right) => left.name.localeCompare(right.name));

	if (prompts.length === 0) return undefined;

	return ctx.ui.custom<PromptRecord | undefined>(
		(tui, theme, _keybindings, done) => new PromptPickerOverlay(tui, theme, prompts, initialSearch, done),
		{
			overlay: true,
			overlayOptions: {
				anchor: "top-center",
				width: "92%",
				maxHeight: "82%",
				minWidth: 82,
				margin: { top: 1, right: 2, bottom: 1, left: 2 },
			},
		},
	);
}

class PromptPickerOverlay {
	private search: string;
	private selectedIndex = 0;

	constructor(
		private readonly tui: TUI,
		private readonly theme: Theme,
		private readonly prompts: readonly PromptRecord[],
		initialSearch: string,
		private readonly done: (prompt?: PromptRecord) => void,
	) {
		this.search = initialSearch.trim();
	}

	handleInput(data: string): void {
		if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
			this.done();
			return;
		}
		if (matchesKey(data, Key.enter)) {
			this.done(this.getSelectedPrompt());
			return;
		}
		if (matchesKey(data, Key.up)) {
			this.move(-1);
			return;
		}
		if (matchesKey(data, Key.down)) {
			this.move(1);
			return;
		}
		if (matchesKey(data, Key.backspace)) {
			if (this.search.length > 0) {
				this.search = Array.from(this.search).slice(0, -1).join("");
				this.selectedIndex = 0;
				this.tui.requestRender();
			}
			return;
		}
		if (isPrintable(data)) {
			this.search += data;
			this.selectedIndex = 0;
			this.tui.requestRender();
		}
	}

	render(width: number): string[] {
		const innerWidth = Math.max(20, width - 2);
		const bodyHeight = Math.max(8, Math.min(28, (this.tui.terminal.rows ?? 30) - 9));
		const leftWidth = innerWidth < 64 ? innerWidth : Math.floor((innerWidth - 1) * 0.48);
		const rightWidth = innerWidth < 64 ? 0 : innerWidth - leftWidth - 1;
		const left = this.renderList(leftWidth, bodyHeight);
		const body = innerWidth < 64
			? left.map((line) => frameLine(this.theme, line, innerWidth))
			: combineColumns(
				left,
				this.renderDetails(rightWidth, bodyHeight),
				leftWidth,
				rightWidth,
				this.theme.fg("borderMuted", "│"),
			).map((line) => frameLine(this.theme, line, innerWidth));

		return [
			topBorder(this.theme, innerWidth),
			frameLine(
				this.theme,
				`${this.theme.fg("accent", this.theme.bold("Prompt Templates"))} ${this.theme.fg("muted", `${this.prompts.length} available`)}`,
				innerWidth,
			),
			frameLine(
				this.theme,
				`${this.theme.fg("muted", "Search:")} ${this.search || this.theme.fg("dim", "(type to fuzzy-filter prompts)")}`,
				innerWidth,
			),
			divider(this.theme, innerWidth),
			...body,
			divider(this.theme, innerWidth),
			frameLine(this.theme, this.theme.fg("dim", "type search · ↑↓ move · enter insert · esc cancel"), innerWidth),
			bottomBorder(this.theme, innerWidth),
		];
	}

	invalidate(): void {}

	private getFilteredPrompts(): PromptRecord[] {
		return filterSkills(this.prompts, this.search);
	}

	private getSelectedPrompt(): PromptRecord | undefined {
		return this.getFilteredPrompts()[this.selectedIndex];
	}

	private move(delta: number): void {
		const filtered = this.getFilteredPrompts();
		if (filtered.length === 0) return;
		this.selectedIndex = clamp(this.selectedIndex + delta, 0, filtered.length - 1);
		this.tui.requestRender();
	}

	private renderList(width: number, height: number): string[] {
		const filtered = this.getFilteredPrompts();
		if (filtered.length === 0) return pad([this.theme.fg("dim", "No matching prompts")], height, width);
		this.selectedIndex = clamp(this.selectedIndex, 0, filtered.length - 1);
		const visible = Math.max(3, Math.floor(height / 2));
		const start = Math.max(0, Math.min(this.selectedIndex - Math.floor(visible / 2), filtered.length - visible));
		const lines: string[] = [];

		for (let index = start; index < Math.min(filtered.length, start + visible); index += 1) {
			const prompt = filtered[index]!;
			const selected = index === this.selectedIndex;
			const marker = selected ? this.theme.fg("accent", "›") : " ";
			const label = `${marker} /${prompt.name}`;
			lines.push(selected ? this.theme.fg("accent", this.theme.bold(fit(label, width))) : fit(label, width));
			lines.push(this.theme.fg("dim", fit(`    ${shorten(prompt.description, width - 4)}`, width)));
		}
		return pad(lines, height, width);
	}

	private renderDetails(width: number, height: number): string[] {
		const prompt = this.getSelectedPrompt();
		if (!prompt) return pad([this.theme.fg("dim", "No prompt selected")], height, width);
		const source = prompt.sourceInfo.source;
		const scope = prompt.sourceInfo.scope ? ` · ${prompt.sourceInfo.scope}` : "";
		const lines = [
			this.theme.fg("accent", this.theme.bold(`/${prompt.name}`)),
			"",
			`${this.theme.fg("muted", "Action:")} insert into editor`,
			`${this.theme.fg("muted", "Source:")} ${source}${scope}`,
			"",
			this.theme.fg("muted", "Path:"),
			...wrap(prompt.filePath, width),
			"",
			this.theme.fg("muted", "Description:"),
			...wrap(prompt.description, width),
		];
		return pad(lines, height, width);
	}
}

function isPrintable(data: string): boolean {
	return data.length > 0 && !data.includes("\x1b") && !data.includes("\r") && !data.includes("\n") && data >= " ";
}

function clamp(value: number, min: number, max: number): number {
	return Math.max(min, Math.min(max, value));
}
