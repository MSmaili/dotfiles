/**
 * ChatGPT plan adapter.
 *
 * Queries OpenAI's (unofficial but widely used) WHAM usage endpoint that the
 * ChatGPT web app and Codex CLI themselves use:
 *
 *   GET https://chatgpt.com/backend-api/wham/usage
 *
 * Returns the plan type, per-window usage percent + reset times, credits
 * balance, spend control status and rate-limit reset credits.
 *
 * Schema is unstable — the parser below handles the known legacy shapes
 * (`percent_left`, `reset_time_ms`, `rate_limits`, `five_hour`/`weekly`)
 * and the current shape (`used_percent`, `reset_at`, `rate_limit`,
 * `primary_window`/`secondary_window`).
 *
 * On HTTP 401 and with a refresh token available, the adapter refreshes the
 * OAuth tokens through auth.openai.com and persists them back into pi's auth
 * store before retrying once.
 */

import { fetchJson } from "./http.ts";
import {
	getChatgptCredentials,
	jwtClientId,
	persistRefreshedChatgptTokens,
	redact,
} from "./credentials.ts";
import type { ProviderSnapshot, UsageWindow } from "./types.ts";

const WHAM_URL = "https://chatgpt.com/backend-api/wham/usage";
const TOKEN_URL = "https://auth.openai.com/oauth/token";

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
	allowed?: unknown;
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
		approx_local_messages?: unknown;
		approx_cloud_messages?: unknown;
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

interface WhamContext {
	access: string;
	refresh?: string;
	accountId?: string;
}

export async function collectChatgpt(): Promise<ProviderSnapshot> {
	const ctx = (await getChatgptCredentials()) as WhamContext;
	if (!ctx.access) {
		return errorSnapshot(
			"No ChatGPT OAuth credentials found. Sign in via pi (/login → openai-codex) or set OPENAI_CODEX_ACCESS_TOKEN / OPENAI_CODEX_ACCOUNT_ID.",
		);
	}
	if (!ctx.accountId) {
		return errorSnapshot(
			"Missing ChatGPT account id. Re-authenticate with pi /login (openai-codex) or set OPENAI_CODEX_ACCOUNT_ID.",
		);
	}

	// First attempt; on 401 with a refresh token, refresh once and retry.
	for (let attempt = 0; attempt < 2; attempt++) {
		const { status, json } = await fetchWham(ctx);
		if (status === 401 && attempt === 0 && ctx.refresh) {
			const refreshed = await refreshTokens(ctx);
			if (!refreshed) break;
			continue;
		}
		if (status !== 200) {
			return errorSnapshot(httpErrorDescription(status, json, [ctx.access, ctx.refresh]));
		}
		return parseWham(json);
	}

	return errorSnapshot(
		"Access token rejected and token refresh failed. Re-run pi /login (openai-codex).",
	);
}

/* ------------------------------------------------------------------ */

async function fetchWham(ctx: WhamContext): Promise<{ status: number; json: unknown }> {
	return fetchJson(
		WHAM_URL,
		{
			headers: {
				Authorization: `Bearer ${ctx.access}`,
				"ChatGPT-Account-Id": ctx.accountId ?? "",
				Accept: "application/json",
				Origin: "https://chatgpt.com",
				Referer: "https://chatgpt.com/",
				"User-Agent": "Mozilla/5.0",
			},
		},
		15_000,
	);
}

async function refreshTokens(ctx: WhamContext): Promise<boolean> {
	const clientId = jwtClientId(ctx.access) ?? process.env.OPENAI_OAUTH_CLIENT_ID;
	if (!clientId || !ctx.refresh) return false;

	try {
		const { status, json } = await fetchJson(
			TOKEN_URL,
			{
				method: "POST",
				headers: { "Content-Type": "application/x-www-form-urlencoded" },
				body: new URLSearchParams({
					grant_type: "refresh_token",
					refresh_token: ctx.refresh,
					client_id: clientId,
				}),
			},
			15_000,
		);
		if (status !== 200) return false;
		const data = json as { access_token?: unknown; refresh_token?: unknown; expires_in?: unknown };
		if (typeof data.access_token !== "string" || !data.access_token) return false;

		ctx.access = data.access_token;
		if (typeof data.refresh_token === "string" && data.refresh_token) {
			ctx.refresh = data.refresh_token;
		}
		const expiresIn = typeof data.expires_in === "number" ? data.expires_in : undefined;
		await persistRefreshedChatgptTokens(ctx.access, ctx.refresh, expiresIn);
		return true;
	} catch {
		return false;
	}
}

function parseWham(raw: unknown): ProviderSnapshot {
	const data = (raw ?? {}) as WhamRaw;
	const rateLimit = data.rate_limit ?? data.rate_limits ?? {};
	const windows: UsageWindow[] = [];

	const primary =
		rateLimit.primary_window ?? rateLimit.five_hour ?? rateLimit.primary;
	if (primary) {
		const parsed = parseWindow(primary, "primary");
		if (parsed) {
			parsed.label =
				parsed.windowSeconds === 300
					? "5-hour rolling"
					: parsed.windowSeconds === 604800
						? "weekly"
						: "primary";
			windows.push(parsed);
		}
	}

	const secondary = rateLimit.secondary_window ?? rateLimit.weekly ?? rateLimit.secondary;
	if (secondary) {
		const parsed = parseWindow(secondary, "secondary");
		if (parsed) {
			parsed.label =
				parsed.windowSeconds === 604800
					? "weekly"
					: parsed.windowSeconds === 300
						? "5-hour rolling"
						: "secondary";
			windows.push(parsed);
		}
	}

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

	const resetCredits = data.rate_limit_reset_credits;
	if (resetCredits && typeof resetCredits.available_count === "number")
		extra.push(`reset credits available: ${resetCredits.available_count}`);

	return {
		provider: "chatgpt",
		displayName: "chatgpt",
		plan: typeof data.plan_type === "string" ? data.plan_type.toUpperCase() : undefined,
		status: "ok",
		windows,
		extra,
		fetchedAt: new Date().toISOString(),
	};
}

function parseWindow(raw: WindowRaw, id: string): UsageWindow | null {
	const used = toNumber(raw.used_percent);
	const left = toNumber(raw.percent_left);
	if (used == null && left == null) return null;
	const percentUsed = used != null ? used : left != null ? 100 - left : 0;

	const resetsAt = pickReset(raw);
	const windowSeconds = toNumber(raw.limit_window_seconds);
	const resetsInSeconds = toNumber(raw.reset_after_seconds);

	return {
		id,
		label: "window",
		percentUsed,
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

function errorSnapshot(message: string): ProviderSnapshot {
	return {
		provider: "chatgpt",
		displayName: "chatgpt",
		status: "error",
		message,
		windows: [],
		extra: [],
		fetchedAt: new Date().toISOString(),
	};
}

function httpErrorDescription(status: number, body: unknown, secrets: (string | undefined)[]): string {
	const raw = typeof body === "string" ? body : JSON.stringify(body ?? "");
	const excerpt = redact(raw, secrets).slice(0, 200);
	return `ChatGPT usage endpoint returned HTTP ${status}${excerpt ? ` (${excerpt})` : ""}`;
}