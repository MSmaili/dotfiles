/** Pure parser for the legacy OpenCode Go/Zen usage endpoints. */
import type { ProviderSnapshot, UsageWindow } from "../adapters/types.ts";

interface OpencodeWindowRaw {
	status?: unknown;
	percent?: unknown;
	resetsAt?: unknown;
	used_percent?: unknown;
	reset_at?: unknown;
}

export function parseOpencodeUsage(
	json: unknown,
	provider: "opencode-go" | "opencode-zen",
): ProviderSnapshot {
	const raw = (json ?? {}) as { usage?: Record<string, OpencodeWindowRaw> };
	const windows: UsageWindow[] = [];
	const extra: string[] = [];
	for (const [id, label] of [
		["rolling", "5-hour rolling"],
		["weekly", "weekly"],
		["monthly", "monthly"],
	] as const) {
		const window = raw.usage?.[id];
		if (!window) continue;
		if (window.status !== undefined && window.status !== "ok") {
			extra.push(`${label}: status ${String(window.status)}`);
			continue;
		}
		const percentUsed = toNumber(window.percent) ?? toNumber(window.used_percent);
		if (percentUsed == null) continue;
		const reset = window.reset_at ?? window.resetsAt;
		windows.push({
			id,
			label,
			percentUsed,
			...(typeof reset === "string" || typeof reset === "number" ? { resetsAt: reset } : {}),
		});
	}
	return {
		provider,
		displayName: provider === "opencode-go" ? "go" : "zen",
		status: windows.length ? "ok" : "unavailable",
		...(windows.length ? {} : { message: "usage response contained no window data" }),
		windows,
		extra: windows.length ? extra : [],
		fetchedAt: new Date().toISOString(),
	};
}

function toNumber(value: unknown): number | null {
	if (typeof value === "number" && Number.isFinite(value)) return value;
	if (typeof value === "string" && value.trim() !== "") {
		const numeric = Number(value);
		if (Number.isFinite(numeric)) return numeric;
	}
	return null;
}
