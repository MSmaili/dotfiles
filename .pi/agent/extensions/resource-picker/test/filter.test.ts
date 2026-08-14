import assert from "node:assert/strict";
import test from "node:test";
import { filterSkills, fuzzyScore } from "../filter.ts";

const skills = [
	{ name: "search-skills", description: "Find a skill by intent", filePath: "/skills/search-skills/SKILL.md" },
	{ name: "mcp-scripting", description: "Discover and call MCP tools", filePath: "/skills/mcp-scripting/SKILL.md" },
	{ name: "validate-fix", description: "Prove a bug fix works", filePath: "/skills/validate-fix/SKILL.md" },
];

test("fuzzy scoring accepts subsequence matches", () => {
	assert.ok(fuzzyScore("mcpscr", "mcp-scripting") > 0);
	assert.ok(fuzzyScore("xyz", "mcp-scripting") < 0);
});

test("skill filtering ranks the matching name first", () => {
	assert.deepEqual(
		filterSkills(skills, "mcp scr").map((skill) => skill.name),
		["mcp-scripting"],
	);
});

test("skill filtering searches descriptions and supports an empty query", () => {
	assert.equal(filterSkills(skills, "prove bug")[0]?.name, "validate-fix");
	assert.deepEqual(filterSkills(skills, "").map((skill) => skill.name), skills.map((skill) => skill.name));
});
