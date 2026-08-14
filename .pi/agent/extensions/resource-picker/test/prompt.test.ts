import assert from "node:assert/strict";
import test from "node:test";
import { filterSystemPrompt, formatSkillsForPrompt } from "../prompt.ts";

const skills = [
	{ name: "mcp-scripting", description: "Work with MCP tools", filePath: "/mcp/SKILL.md" },
	{ name: "search-skills", description: "Find matching skills", filePath: "/search/SKILL.md" },
	{ name: "deploy", description: "Deploy an application", filePath: "/deploy/SKILL.md", disableModelInvocation: true },
];

const basePrompt = [
	"You are an assistant.",
	"",
	"The following skills provide specialized instructions for specific tasks.",
	"Use the read tool to load a skill's file when the task matches its description.",
	"When a skill file references a relative path, resolve it against the skill directory (parent of SKILL.md / dirname of the path) and use that absolute path in tool commands.",
	"",
	"<available_skills>",
	"  <skill>",
	"    <name>old</name>",
	"  </skill>",
	"</available_skills>",
	"",
	"Current working directory: /tmp/project",
].join("\n");

test("formats skill metadata as XML", () => {
	const formatted = formatSkillsForPrompt([{ name: "a&b", description: "x < y", filePath: "/tmp/a\"b" }]);
	assert.match(formatted, /<name>a&amp;b<\/name>/);
	assert.match(formatted, /<description>x &lt; y<\/description>/);
	assert.match(formatted, /<location>\/tmp\/a&quot;b<\/location>/);
});

test("filters the prompt to the session-selected skills", () => {
	const filtered = filterSystemPrompt(basePrompt, skills, new Set(["mcp-scripting", "search-skills"]));
	assert.match(filtered, /<name>mcp-scripting<\/name>/);
	assert.match(filtered, /<name>search-skills<\/name>/);
	assert.doesNotMatch(filtered, /<name>deploy<\/name>/);
	assert.match(filtered, /Current working directory: \/tmp\/project/);
});

test("removes native manual-only skills even when the session selects them", () => {
	const filtered = filterSystemPrompt(basePrompt, skills, new Set(["deploy"]));
	assert.doesNotMatch(filtered, /<name>deploy<\/name>/);
});

test("removes the skills section when the session selects none", () => {
	const filtered = filterSystemPrompt(basePrompt, skills, new Set());
	assert.doesNotMatch(filtered, /available_skills/);
	assert.match(filtered, /Current working directory: \/tmp\/project/);
});
