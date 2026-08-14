import assert from "node:assert/strict";
import test from "node:test";
import type { SlashCommandInfo } from "@earendil-works/pi-coding-agent";
import { filterRootSlashItems } from "../autocomplete.ts";

const sourceInfo = {
	path: "/tmp/resource.md",
	source: "test-package",
	scope: "user",
	origin: "package",
} as const;

const commands: SlashCommandInfo[] = [
	{ name: "agents", source: "extension", sourceInfo },
	{ name: "plan-work", source: "prompt", sourceInfo },
	{ name: "skill:plan-work", source: "skill", sourceInfo },
];

const items = [
	{ value: "model", label: "model" },
	{ value: "agents", label: "agents" },
	{ value: "plan-work", label: "plan-work" },
	{ value: "skill:plan-work", label: "skill:plan-work" },
];

test("root slash completion shows only built-in and extension commands", () => {
	assert.deepEqual(
		filterRootSlashItems(items, commands, "").map((item) => item.value),
		["model", "agents"],
	);
});

test("explicit skill completion still shows skill commands", () => {
	assert.deepEqual(
		filterRootSlashItems(items, commands, "skill:").map((item) => item.value),
		["model", "agents", "skill:plan-work"],
	);
});

test("prompt templates stay hidden for direct slash searches", () => {
	assert.equal(filterRootSlashItems(items, commands, "plan").some((item) => item.value === "plan-work"), false);
});
