export interface PromptSkill {
	name: string;
	description: string;
	filePath: string;
	disableModelInvocation?: boolean;
}

const SKILLS_INTRO = "The following skills provide specialized instructions for specific tasks.";
const SKILLS_INSTRUCTION = "Use the read tool to load a skill's file when the task matches its description.";
const SKILLS_PATH_INSTRUCTION =
	"When a skill file references a relative path, resolve it against the skill directory (parent of SKILL.md / dirname of the path) and use that absolute path in tool commands.";

/**
 * Keep only the session-selected skills in Pi's available_skills section.
 *
 * This intentionally operates on the prompt produced by Pi instead of
 * changing SKILL.md frontmatter or settings.json. The resource loader keeps
 * every skill available for explicit /skill:name invocation, while this
 * extension controls which descriptions the agent sees automatically.
 */
export function filterSystemPrompt(
	systemPrompt: string,
	skills: readonly PromptSkill[],
	activeSkillNames: ReadonlySet<string>,
): string {
	const openTag = systemPrompt.indexOf("<available_skills>");
	const closeTag = systemPrompt.indexOf("</available_skills>", openTag + 1);
	if (openTag === -1 || closeTag === -1) return systemPrompt;

	const visibleSkills = skills.filter(
		(skill) => activeSkillNames.has(skill.name) && !skill.disableModelInvocation,
	);
	const sectionEnd = closeTag + "</available_skills>".length;
	const introStart = systemPrompt.lastIndexOf(`\n\n${SKILLS_INTRO}`, openTag);

	if (visibleSkills.length === 0 && introStart !== -1) {
		return `${systemPrompt.slice(0, introStart)}${systemPrompt.slice(sectionEnd)}`;
	}

	const replacement = formatSkillsForPrompt(visibleSkills);
	if (introStart !== -1) {
		return `${systemPrompt.slice(0, introStart)}${replacement}${systemPrompt.slice(sectionEnd)}`;
	}

	return `${systemPrompt.slice(0, openTag)}${replacement.trimStart()}${systemPrompt.slice(sectionEnd)}`;
}

export function formatSkillsForPrompt(skills: readonly PromptSkill[]): string {
	if (skills.length === 0) return "";

	const lines = [
		`\n\n${SKILLS_INTRO}`,
		SKILLS_INSTRUCTION,
		SKILLS_PATH_INSTRUCTION,
		"",
		"<available_skills>",
	];

	for (const skill of skills) {
		lines.push("  <skill>");
		lines.push(`    <name>${escapeXml(skill.name)}</name>`);
		lines.push(`    <description>${escapeXml(skill.description)}</description>`);
		lines.push(`    <location>${escapeXml(skill.filePath)}</location>`);
		lines.push("  </skill>");
	}

	lines.push("</available_skills>");
	return lines.join("\n");
}

function escapeXml(value: string): string {
	return value
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/\"/g, "&quot;")
		.replace(/'/g, "&apos;");
}
