import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import type { Skill, Theme } from "@earendil-works/pi-coding-agent";
import { type KeybindingsManager, type TUI, visibleWidth } from "@earendil-works/pi-tui";
import {
	buildSkillInvocation,
	loadSkillRecords,
	sanitizeSkillPreview,
	SkillPickerOverlay,
	type SkillRecord,
} from "../skill-picker.ts";

function makeSkill(name: string, filePath: string): Skill {
	return {
		name,
		description: `${name} description`,
		filePath,
		baseDir: join(filePath, ".."),
		disableModelInvocation: true,
		sourceInfo: {
			path: filePath,
			source: "test",
			scope: "temporary",
			origin: "top-level",
		},
	};
}

test("loads full skill source for local preview and sorts by name", async (t) => {
	const directory = await mkdtemp(join(tmpdir(), "pi-skill-picker-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	const alphaPath = join(directory, "alpha.md");
	const betaPath = join(directory, "beta.md");
	await writeFile(alphaPath, "---\nname: alpha\n---\n\n# Alpha\n", "utf8");
	await writeFile(betaPath, "# Beta\n", "utf8");

	const records = await loadSkillRecords([
		makeSkill("beta", betaPath),
		makeSkill("alpha", alphaPath),
	]);

	assert.deepEqual(records.map((record) => record.name), ["alpha", "beta"]);
	assert.match(records[0]?.content ?? "", /# Alpha/);
	assert.equal(records[0]?.readError, undefined);
});

test("keeps unreadable skills selectable with a preview error", async () => {
	const missingPath = join(tmpdir(), `missing-skill-${Date.now()}.md`);
	const [record] = await loadSkillRecords([makeSkill("missing", missingPath)]);

	assert.ok(record?.readError);
	assert.match(record?.content ?? "", /Unable to read/);
});

test("sanitizes terminal controls and normalizes preview whitespace", () => {
	const source = "title\r\n\tred: \u001b[31mvalue\u001b[0m\nclipboard\u001b]52;c;SGVsbG8=\u0007\nalert\u0007done";
	const sanitized = sanitizeSkillPreview(source);

	assert.equal(sanitized, "title\n    red: value\nclipboard\nalertdone");
	assert.doesNotMatch(sanitized, /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/);
});

test("loads sanitized content into preview records", async (t) => {
	const directory = await mkdtemp(join(tmpdir(), "pi-skill-picker-controls-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	const skillPath = join(directory, "controlled.md");
	await writeFile(skillPath, "# Controlled\n\u001b]52;c;SGVsbG8=\u0007", "utf8");

	const [record] = await loadSkillRecords([makeSkill("controlled", skillPath)]);
	assert.equal(record?.content, "# Controlled\n");
});

test("renders within the provided width and selects through configured keybindings", () => {
	const theme = {
		fg: (_color: string, text: string) => text,
		bold: (text: string) => text,
	} as unknown as Theme;
	const tui = {
		terminal: { rows: 30 },
		requestRender: () => {},
	} as unknown as TUI;
	const keyMap = new Map([
		["down", "tui.select.down"],
		["enter", "tui.select.confirm"],
	]);
	const keybindings = {
		matches: (data: string, action: string) => keyMap.get(data) === action,
	} as unknown as KeybindingsManager;
	const records: SkillRecord[] = [
		{ ...makeSkill("alpha", "/alpha/SKILL.md"), content: "# Alpha\n\nShort preview." },
		{ ...makeSkill("beta", "/beta/SKILL.md"), content: `# Beta\n\n${"long preview ".repeat(20)}` },
	];
	let selected: SkillRecord | undefined;
	const overlay = new SkillPickerOverlay(tui, theme, keybindings, records, "", (skill) => {
		selected = skill;
	});

	for (const width of [40, 82, 120]) {
		assert.ok(overlay.render(width).every((line) => visibleWidth(line) <= width));
	}
	overlay.handleInput("\x0e"); // Ctrl+N moves down.
	overlay.handleInput("\x10"); // Ctrl+P moves back up.
	overlay.handleInput("down");
	overlay.handleInput("enter");
	assert.equal(selected?.name, "beta");
});

test("builds an explicit skill command without applying it immediately", () => {
	assert.equal(buildSkillInvocation("code-review"), "/skill:code-review ");
});
