import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext, Skill } from "@earendil-works/pi-coding-agent";
import { filterRootSlashItems } from "./autocomplete.ts";
import { filterSystemPrompt } from "./prompt.ts";
import { showPromptPicker } from "./prompt-picker.ts";

// Keep the default skill metadata small. Other discovered skills remain
// available for explicit invocation through /skill:name.
const MODEL_VISIBLE_SKILL_NAMES = new Set(["mcp-scripting"]);

export default function resourcePickerExtension(pi: ExtensionAPI): void {
	function updateSkillStatus(ctx: ExtensionContext, skills: readonly Skill[]): void {
		const activeSkills = skills.filter(
			(skill) => !skill.disableModelInvocation && MODEL_VISIBLE_SKILL_NAMES.has(skill.name),
		);
		ctx.ui.setStatus(
			"skill-context",
			ctx.ui.theme.fg("muted", `skills ${activeSkills.length}/${skills.length} visible`),
		);
	}

	async function openPromptPicker(args: string, ctx: ExtensionCommandContext): Promise<void> {
		if (ctx.mode !== "tui") {
			ctx.ui.notify("/prompts requires interactive TUI mode", "error");
			return;
		}

		const commands = pi.getCommands();
		if (!commands.some((command) => command.source === "prompt")) {
			ctx.ui.notify("No prompt templates are loaded in this session", "warning");
			return;
		}

		const selected = await showPromptPicker(ctx, commands, args);
		if (!selected) return;
		ctx.ui.setEditorText(`/${selected.name} `);
	}

	pi.registerCommand("prompts", {
		description: "Pick a prompt template and insert it into the editor",
		handler: openPromptPicker,
	});

	pi.on("session_start", (_event, ctx) => {
		ctx.ui.addAutocompleteProvider((current) => ({
			triggerCharacters: current.triggerCharacters,
			async getSuggestions(lines, cursorLine, cursorCol, options) {
				const suggestions = await current.getSuggestions(lines, cursorLine, cursorCol, options);
				if (!suggestions) return null;

				const textBeforeCursor = (lines[cursorLine] ?? "").slice(0, cursorCol);
				const slashCommand = textBeforeCursor.match(/^\/([^\s]*)$/);
				if (!slashCommand || !suggestions.prefix.startsWith("/")) return suggestions;

				const items = filterRootSlashItems(suggestions.items, pi.getCommands(), slashCommand[1] ?? "");
				return items.length > 0 ? { ...suggestions, items } : null;
			},
			applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
				return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
			},
			shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
				return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
			},
		}));
	});

	pi.on("before_agent_start", (event, ctx) => {
		const skills = event.systemPromptOptions.skills ?? [];
		updateSkillStatus(ctx, skills);

		const systemPrompt = filterSystemPrompt(event.systemPrompt, skills, MODEL_VISIBLE_SKILL_NAMES);
		if (systemPrompt === event.systemPrompt) return;
		return { systemPrompt };
	});
}
