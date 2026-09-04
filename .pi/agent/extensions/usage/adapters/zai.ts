/**
 * z.ai (GLM Coding Plan) adapter.
 *
 * `GET https://open.bigmodel.cn/api/monitor/usage/quota/limit` with the
 * zai-coding-cn API key. Verified live: returns a monitor envelope whose
 * `data.limits[]` carries one entry per window:
 *
 *   { type: "CREDIT_LIMIT", unit: 3|6, usage, currentValue, remaining,
 *     percentage, nextResetTime: <epoch ms> }
 *
 * unit 3 = 5-hour rolling window, unit 6 = monthly. `data.level` is the
 * plan tier ("lite", ...).
 *
 * ponytail: China region only (pi stores zai-coding-cn). Add an api.z.ai
 * global variant when a global key actually shows up in auth.
 */

import { getApiKeyCredentials } from "./credentials.ts";
import { fetchJson } from "./http.ts";
import type { ProviderSnapshot, UsageWindow } from "./types.ts";

const USAGE_URL = "https://open.bigmodel.cn/api/monitor/usage/quota/limit";

/** Known unit codes; unknown ones fall back to "unit <n>". */
const UNIT_LABELS: Record<number, string> = {
	3: "5-hour rolling",
	6: "monthly",
};

interface QuotaLimitRaw {
	type?: unknown;
	unit?: unknown;
	percentage?: unknown;
	nextResetTime?: unknown;
}

export async function collectZai(): Promise<ProviderSnapshot> {
	const { key } = await getApiKeyCredentials("zai");
	if (!key) {
		return unavailable('No z.ai API key found in ~/.pi/agent/auth.json (provider "zai-coding-cn" or ZHIPUAI_API_KEY).');
	}

	try {
		const { status, json } = await fetchJson(USAGE_URL, {
			headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
		});
		if (status !== 200) {
			return unavailable(`usage endpoint returned HTTP ${status}`);
		}
		const parsed = parseQuotaLimit(json);
		if (!parsed) return unavailable("usage response contained no window data");
		return { ...parsed, fetchedAt: new Date().toISOString() };
	} catch (error) {
		return unavailable(error instanceof Error ? error.message : String(error));
	}
}

/** Parse the quota/limit envelope. Returns undefined when no windows exist. */
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

function unavailable(message: string): ProviderSnapshot {
	return {
		provider: "zai",
		displayName: "z.ai",
		status: "unavailable",
		message,
		windows: [],
		extra: [],
		fetchedAt: new Date().toISOString(),
	};
}
