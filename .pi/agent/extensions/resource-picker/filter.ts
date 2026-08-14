export interface SearchableSkill {
	name: string;
	description: string;
	filePath: string;
	sourceInfo?: {
		source?: string;
		scope?: string;
		origin?: string;
	};
}

interface ScoredSkill<T> {
	skill: T;
	score: number;
}

/**
 * Return a fuzzy score for a query against text.
 *
 * Matching is subsequence-based rather than substring-only, with bonuses for
 * prefixes, word boundaries, and consecutive characters. A negative score
 * means that the query does not match.
 */
export function fuzzyScore(query: string, text: string): number {
	const needle = query.trim().toLocaleLowerCase();
	const haystack = text.toLocaleLowerCase();
	if (needle.length === 0) return 0;
	if (haystack.length === 0) return -1;
	if (haystack === needle) return 10_000;
	if (haystack.startsWith(needle)) return 8_000 - haystack.length;
	if (haystack.includes(needle)) return 7_000 - haystack.indexOf(needle);

	let score = 0;
	let cursor = 0;
	let previousIndex = -2;
	let firstMatch = -1;

	for (const character of needle) {
		const index = haystack.indexOf(character, cursor);
		if (index === -1) return -1;
		if (firstMatch === -1) firstMatch = index;

		if (index === previousIndex + 1) score += 24;
		if (index === 0 || " -_/.".includes(haystack[index - 1] ?? "")) score += 18;
		score += 10;

		previousIndex = index;
		cursor = index + 1;
	}

	// Prefer matches that begin earlier and use less of the candidate string.
	return score + Math.max(0, 40 - firstMatch * 2) - Math.max(0, haystack.length - needle.length) * 0.05;
}

/**
 * Fuzzy-filter skills by name, description, path, and package/source metadata.
 * Every query token must match at least one field.
 */
export function filterSkills<T extends SearchableSkill>(skills: readonly T[], query: string): T[] {
	const tokens = query.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
	if (tokens.length === 0) return [...skills];

	const scored: ScoredSkill<T>[] = [];
	for (const skill of skills) {
		const fields = [
			skill.name,
			skill.description,
			skill.filePath,
			skill.sourceInfo?.source ?? "",
			skill.sourceInfo?.scope ?? "",
		];

		let total = 0;
		let matched = true;
		for (const token of tokens) {
			const tokenScore = Math.max(...fields.map((field) => fuzzyScore(token, field)));
			if (tokenScore < 0) {
				matched = false;
				break;
			}
			total += tokenScore;
		}

		if (matched) {
			// Skill names are the primary search surface.
			total += fuzzyScore(tokens.join(" "), skill.name) * 2;
			scored.push({ skill, score: total });
		}
	}

	return scored
		.sort((left, right) => right.score - left.score || left.skill.name.localeCompare(right.skill.name))
		.map(({ skill }) => skill);
}
