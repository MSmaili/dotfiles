import type { SlashCommandInfo } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";

/**
 * Keep the root slash palette focused on real commands.
 *
 * Prompt templates live in /prompts. Skill commands stay hidden at the root,
 * but become discoverable once the user explicitly types /skill:.
 */
export function filterRootSlashItems(
	items: readonly AutocompleteItem[],
	commands: readonly SlashCommandInfo[],
	typedCommand: string,
): AutocompleteItem[] {
	const resourceSources = new Map(commands.map((command) => [command.name, command.source]));
	const showSkills = typedCommand.startsWith("skill:");

	return items.filter((item) => {
		const source = resourceSources.get(item.value);
		if (source === "prompt") return false;
		if (source === "skill" && !showSkills) return false;
		return true;
	});
}
