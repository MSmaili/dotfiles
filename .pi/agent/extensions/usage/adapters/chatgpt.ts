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
import type { ProviderSnapshot } from "./types.ts";
import { parseWham } from "../parsers/chatgpt.ts";

export { parseWham } from "../parsers/chatgpt.ts";

const WHAM_URL = "https://chatgpt.com/backend-api/wham/usage";
const TOKEN_URL = "https://auth.openai.com/oauth/token";

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

	try {
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
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		return errorSnapshot(redact(message, [ctx.access, ctx.refresh]));
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
