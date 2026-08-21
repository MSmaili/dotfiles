import { readFile } from "node:fs/promises";
import { stripVTControlCharacters } from "node:util";
import type { ExtensionContext, Skill, Theme } from "@earendil-works/pi-coding-agent";
import {
	Key,
	type KeybindingsManager,
	matchesKey,
	type TUI,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";
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
} from "../shared/ui.ts";

export interface SkillRecord extends Skill {
	content: string;
	readError?: string;
}

/** Remove terminal control sequences while preserving readable source text. */
export function sanitizeSkillPreview(content: string): string {
	return stripVTControlCharacters(content)
		.replace(/\r\n?/g, "\n")
		.replace(/\t/g, "    ")
		.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g, "");
}

/** Load skill source for the local preview. This content is never sent to the model. */
export async function loadSkillRecords(skills: readonly Skill[]): Promise<SkillRecord[]> {
	return Promise.all(
		[...skills]
			.sort((left, right) => left.name.localeCompare(right.name))
			.map(async (skill) => {
				try {
					const content = sanitizeSkillPreview(await readFile(skill.filePath, "utf8"));
					return { ...skill, content };
				} catch (error) {
					const message = error instanceof Error ? error.message : String(error);
					return {
						...skill,
						content: `Unable to read ${skill.filePath}\n\n${message}`,
						readError: message,
					};
				}
			}),
	);
}

export function buildSkillInvocation(skillName: string): string {
	return `/skill:${skillName} `;
}

export async function showSkillPicker(
	ctx: ExtensionContext,
	skills: readonly Skill[],
	initialSearch = "",
): Promise<SkillRecord | undefined> {
	if (skills.length === 0) return undefined;
	const records = await loadSkillRecords(skills);

	return ctx.ui.custom<SkillRecord | undefined>(
		(tui, theme, keybindings, done) =>
			new SkillPickerOverlay(tui, theme, keybindings, records, initialSearch, done),
		{
			overlay: true,
			overlayOptions: {
				anchor: "top-center",
				width: "94%",
				maxHeight: "90%",
				minWidth: 82,
				margin: { top: 1, right: 2, bottom: 1, left: 2 },
			},
		},
	);
}

export class SkillPickerOverlay {
	private search: string;
	private selectedIndex = 0;
	private previewScroll = 0;
	private previewPageHeight = 1;
	private previewLineCount = 0;
	private previewCache?: { filePath: string; width: number; lines: string[] };
	private readonly tui: TUI;
	private readonly theme: Theme;
	private readonly keybindings: KeybindingsManager;
	private readonly skills: readonly SkillRecord[];
	private readonly done: (skill?: SkillRecord) => void;

	constructor(
		tui: TUI,
		theme: Theme,
		keybindings: KeybindingsManager,
		skills: readonly SkillRecord[],
		initialSearch: string,
		done: (skill?: SkillRecord) => void,
	) {
		this.tui = tui;
		this.theme = theme;
		this.keybindings = keybindings;
		this.skills = skills;
		this.search = initialSearch.trim();
		this.done = done;
	}

	handleInput(data: string): void {
		if (this.keybindings.matches(data, "tui.select.cancel")) {
			this.done();
			return;
		}
		if (this.keybindings.matches(data, "tui.select.confirm")) {
			const selected = this.getSelectedSkill();
			if (selected) this.done(selected);
			return;
		}
		if (this.keybindings.matches(data, "tui.select.up") || matchesKey(data, Key.ctrl("p"))) {
			this.move(-1);
			return;
		}
		if (this.keybindings.matches(data, "tui.select.down") || matchesKey(data, Key.ctrl("n"))) {
			this.move(1);
			return;
		}
		if (this.keybindings.matches(data, "tui.select.pageUp")) {
			this.scrollPreview(-this.previewPageHeight);
			return;
		}
		if (this.keybindings.matches(data, "tui.select.pageDown")) {
			this.scrollPreview(this.previewPageHeight);
			return;
		}
		if (matchesKey(data, Key.home)) {
			this.previewScroll = 0;
			this.tui.requestRender();
			return;
		}
		if (matchesKey(data, Key.end)) {
			this.previewScroll = Math.max(0, this.previewLineCount - this.previewPageHeight);
			this.tui.requestRender();
			return;
		}
		if (matchesKey(data, Key.backspace)) {
			if (this.search.length > 0) {
				this.search = Array.from(this.search).slice(0, -1).join("");
				this.resetSelection();
			}
			return;
		}
		if (isPrintable(data)) {
			this.search += data;
			this.resetSelection();
		}
	}

	render(width: number): string[] {
		const innerWidth = Math.max(1, width - 2);
		const bodyHeight = Math.max(8, Math.min(36, (this.tui.terminal.rows ?? 30) - 9));
		const showPreview = innerWidth >= 70;
		const leftWidth = showPreview ? Math.max(30, Math.floor((innerWidth - 1) * 0.36)) : innerWidth;
		const rightWidth = showPreview ? innerWidth - leftWidth - 1 : 0;
		const left = this.renderList(leftWidth, bodyHeight);
		const body = showPreview
			? combineColumns(
					left,
					this.renderDetails(rightWidth, bodyHeight),
					leftWidth,
					rightWidth,
					this.theme.fg("borderMuted", "│"),
				).map((line) => frameLine(this.theme, line, innerWidth))
			: left.map((line) => frameLine(this.theme, line, innerWidth));
		const matchCount = this.getFilteredSkills().length;

		return [
			topBorder(this.theme, innerWidth),
			frameLine(
				this.theme,
				`${this.theme.fg("accent", this.theme.bold("Skills"))} ${this.theme.fg("muted", `${matchCount}/${this.skills.length} matching`)}`,
				innerWidth,
			),
			frameLine(
				this.theme,
				`${this.theme.fg("muted", "Search:")} ${this.search || this.theme.fg("dim", "(type to fuzzy-filter skills)")}`,
				innerWidth,
			),
			divider(this.theme, innerWidth),
			...body,
			divider(this.theme, innerWidth),
			frameLine(
				this.theme,
				this.theme.fg("dim", "type search · ↑↓/ctrl-n/ctrl-p skill · pgup/pgdn preview · enter insert · esc cancel"),
				innerWidth,
			),
			bottomBorder(this.theme, innerWidth),
		];
	}

	invalidate(): void {
		this.previewCache = undefined;
	}

	private getFilteredSkills(): SkillRecord[] {
		return filterSkills(this.skills, this.search);
	}

	private getSelectedSkill(): SkillRecord | undefined {
		return this.getFilteredSkills()[this.selectedIndex];
	}

	private move(delta: number): void {
		const filtered = this.getFilteredSkills();
		if (filtered.length === 0) return;
		this.selectedIndex = clamp(this.selectedIndex + delta, 0, filtered.length - 1);
		this.previewScroll = 0;
		this.tui.requestRender();
	}

	private resetSelection(): void {
		this.selectedIndex = 0;
		this.previewScroll = 0;
		this.tui.requestRender();
	}

	private scrollPreview(delta: number): void {
		const maxScroll = Math.max(0, this.previewLineCount - this.previewPageHeight);
		this.previewScroll = clamp(this.previewScroll + delta, 0, maxScroll);
		this.tui.requestRender();
	}

	private renderList(width: number, height: number): string[] {
		const filtered = this.getFilteredSkills();
		if (filtered.length === 0) return pad([this.theme.fg("dim", "No matching skills")], height, width);
		this.selectedIndex = clamp(this.selectedIndex, 0, filtered.length - 1);
		const visible = Math.max(3, Math.floor(height / 2));
		const start = Math.max(0, Math.min(this.selectedIndex - Math.floor(visible / 2), filtered.length - visible));
		const lines: string[] = [];

		for (let index = start; index < Math.min(filtered.length, start + visible); index += 1) {
			const skill = filtered[index]!;
			const selected = index === this.selectedIndex;
			const marker = selected ? this.theme.fg("accent", "›") : " ";
			const manual = skill.disableModelInvocation ? this.theme.fg("warning", " [manual]") : "";
			const label = `${marker} ${skill.name}${manual}`;
			lines.push(selected ? this.theme.fg("accent", this.theme.bold(fit(label, width))) : fit(label, width));
			lines.push(this.theme.fg("dim", fit(`   ${shorten(skill.description, width - 3)}`, width)));
		}
		return pad(lines, height, width);
	}

	private renderDetails(width: number, height: number): string[] {
		const skill = this.getSelectedSkill();
		if (!skill) return pad([this.theme.fg("dim", "No skill selected")], height, width);

		const source = skill.sourceInfo.source;
		const scope = skill.sourceInfo.scope ? ` · ${skill.sourceInfo.scope}` : "";
		const mode = skill.disableModelInvocation
			? "manual-only (disable-model-invocation)"
			: "explicit picker invocation";
		const contentLines = this.getPreviewLines(skill, width);
		const headerHeight = 7;
		const contentHeight = Math.max(1, height - headerHeight);
		this.previewPageHeight = contentHeight;
		this.previewLineCount = contentLines.length;
		this.previewScroll = clamp(
			this.previewScroll,
			0,
			Math.max(0, this.previewLineCount - this.previewPageHeight),
		);
		const end = Math.min(contentLines.length, this.previewScroll + contentHeight);
		const position = contentLines.length === 0
			? "empty"
			: `${Math.min(this.previewScroll + 1, contentLines.length)}-${end}/${contentLines.length}`;
		const errorLabel = skill.readError ? this.theme.fg("error", "read error") : position;
		const header = [
			this.theme.fg("accent", this.theme.bold(skill.name)),
			`${this.theme.fg("muted", "Source:")} ${source}${scope}`,
			`${this.theme.fg("muted", "Mode:")} ${mode}`,
			this.theme.fg("muted", "Path:"),
			shorten(skill.filePath, width),
			"",
			`${this.theme.fg("muted", "Full SKILL.md")} ${this.theme.fg("dim", `[${errorLabel}]`)}`,
		];
		return pad([...header, ...contentLines.slice(this.previewScroll, end)], height, width);
	}

	private getPreviewLines(skill: SkillRecord, width: number): string[] {
		if (this.previewCache?.filePath === skill.filePath && this.previewCache.width === width) {
			return this.previewCache.lines;
		}
		const lines = wrapTextWithAnsi(skill.content, Math.max(1, width));
		this.previewCache = { filePath: skill.filePath, width, lines };
		return lines;
	}
}

function isPrintable(data: string): boolean {
	return data.length > 0 && !data.includes("\x1b") && !data.includes("\r") && !data.includes("\n") && data >= " ";
}

function clamp(value: number, min: number, max: number): number {
	return Math.max(min, Math.min(max, value));
}
