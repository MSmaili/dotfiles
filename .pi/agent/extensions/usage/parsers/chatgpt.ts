/** Pure parser for the current and legacy ChatGPT WHAM response shapes. */
import type { ProviderSnapshot, UsageWindow } from "../adapters/types.ts";

interface WindowRaw {
	used_percent?: unknown;
	percent_left?: unknown;
	limit_window_seconds?: unknown;
	reset_after_seconds?: unknown;
	reset_at?: unknown;
	reset_time_ms?: unknown;
	resetsAt?: unknown;
}

interface RateLimitRaw {
	limit_reached?: unknown;
	five_hour?: WindowRaw;
	weekly?: WindowRaw;
	primary_window?: WindowRaw | null;
	secondary_window?: WindowRaw | null;
	primary?: WindowRaw;
	secondary?: WindowRaw;
}

interface WhamRaw {
	plan_type?: unknown;
	rate_limit?: RateLimitRaw | null;
	rate_limits?: RateLimitRaw | null;
	credits?: {
		has_credits?: unknown;
		unlimited?: unknown;
		overage_limit_reached?: unknown;
		balance?: unknown;
	};
	spend_control?: {
		reached?: unknown;
		individual_limit?: unknown;
	};
	rate_limit_reset_credits?: {
		available_count?: unknown;
		applicable_available_count?: unknown;
	};
}

export function parseWham(raw: unknown): ProviderSnapshot {
	const data = (raw ?? {}) as WhamRaw;
	const rateLimit = data.rate_limit ?? data.rate_limits ?? {};
	const windows: UsageWindow[] = [];
	const primary = rateLimit.primary_window ?? rateLimit.five_hour ?? rateLimit.primary;
	const secondary = rateLimit.secondary_window ?? rateLimit.weekly ?? rateLimit.secondary;
	for (const [rawWindow, id] of [[primary, "primary"], [secondary, "secondary"]] as const) {
		if (!rawWindow) continue;
		const window = parseWindow(rawWindow, id);
		if (window) windows.push(window);
	}

	return {
		provider: "chatgpt",
		displayName: "chatgpt",
		plan: typeof data.plan_type === "string" ? data.plan_type.toUpperCase() : undefined,
		status: "ok",
		windows,
		extra: parseExtras(data, rateLimit),
		fetchedAt: new Date().toISOString(),
	};
}

function parseExtras(data: WhamRaw, rateLimit: RateLimitRaw): string[] {
	const extra: string[] = [];
	if (rateLimit.limit_reached === true || rateLimit.limit_reached === "true") {
		extra.push("rate limit REACHED");
	}
	const credits = data.credits;
	if (credits) {
		if (credits.has_credits === true || credits.has_credits === "true") {
			extra.push(`credits balance $${String(credits.balance ?? "?")}`);
			if (credits.unlimited === true) extra.push("credits unlimited");
		}
		if (credits.overage_limit_reached === true) extra.push("overage limit reached");
	}
	const spend = data.spend_control;
	if (spend) {
		if (spend.reached === true) extra.push("spend control REACHED");
		else if (spend.individual_limit != null)
			extra.push(`spend control: $${String(spend.individual_limit)} limit`);
		else extra.push("spend control: off");
	}
	const available = toNumber(data.rate_limit_reset_credits?.available_count);
	const applicable = toNumber(data.rate_limit_reset_credits?.applicable_available_count);
	if (available != null) {
		extra.push(
			applicable != null && applicable !== available
				? `reset credits: ${available} banked, ${applicable} applicable now`
				: `reset credits available: ${available}`,
		);
	}
	return extra;
}

function parseWindow(raw: WindowRaw, id: string): UsageWindow | null {
	const used = toNumber(raw.used_percent);
	const left = toNumber(raw.percent_left);
	if (used == null && left == null) return null;
	const windowSeconds = toNumber(raw.limit_window_seconds);
	const resetsAt = pickReset(raw);
	const resetsInSeconds = toNumber(raw.reset_after_seconds);
	return {
		id,
		label: windowSeconds === 18_000 ? "5-hour" : windowSeconds === 604_800 ? "weekly" : id,
		percentUsed: used ?? 100 - left!,
		...(resetsAt !== undefined ? { resetsAt } : {}),
		...(windowSeconds != null ? { windowSeconds } : {}),
		...(resetsInSeconds != null ? { resetsInSeconds } : {}),
	};
}

function pickReset(raw: WindowRaw): number | string | undefined {
	for (const candidate of [raw.reset_at, raw.reset_time_ms, raw.resetsAt]) {
		if (candidate == null) continue;
		if (typeof candidate === "number") return candidate;
		if (typeof candidate === "string" && candidate.length > 0) {
			const numeric = Number(candidate);
			return Number.isFinite(numeric) ? numeric : candidate;
		}
	}
	return undefined;
}

function toNumber(value: unknown): number | null {
	if (typeof value === "number" && Number.isFinite(value)) return value;
	if (typeof value === "string" && value.trim() !== "") {
		const numeric = Number(value);
		if (Number.isFinite(numeric)) return numeric;
	}
	return null;
}
