/** Pure parser for the z.ai coding-plan quota/limit envelope. */
import type { ProviderSnapshot, UsageWindow } from "../adapters/types.ts";

const UNIT_LABELS: Record<number, string> = { 3: "5-hour rolling", 6: "monthly" };

interface QuotaLimitRaw {
	unit?: unknown;
	percentage?: unknown;
	nextResetTime?: unknown;
}

export function parseQuotaLimit(raw: unknown): Omit<ProviderSnapshot, "fetchedAt"> | undefined {
	const data = (raw as { data?: { limits?: QuotaLimitRaw[]; level?: unknown } } | null)?.data;
	const windows: UsageWindow[] = [];
	for (const limit of data?.limits ?? []) {
		const percentUsed = toNumber(limit.percentage);
		if (percentUsed == null) continue;
		const unit = toNumber(limit.unit) ?? 0;
		windows.push({
			id: `unit-${unit}`,
			label: UNIT_LABELS[unit] ?? `unit ${unit}`,
			percentUsed,
			...(typeof limit.nextResetTime === "number" ? { resetsAt: limit.nextResetTime } : {}),
		});
	}
	if (windows.length === 0) return undefined;
	return {
		provider: "zai",
		displayName: "z.ai",
		...(typeof data?.level === "string" ? { plan: data.level.toUpperCase() } : {}),
		status: "ok",
		windows,
		extra: [],
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
