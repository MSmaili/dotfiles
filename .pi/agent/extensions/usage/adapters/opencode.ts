/**
 * OpenCode adapters.
 *
 * - opencode-go: `GET https://opencode.ai/zen/go/v1/usage` with the go API key.
 *   Verified live: returns { usage: { rolling, weekly, monthly } } where each
 *   window carries { status, percent, resetsAt }.
 *
 * - opencode-zen: no public balance endpoint exists today (open feature
 *   request). The adapter probes `GET https://opencode.ai/zen/v1/usage` and
 *   reports "unavailable" unless opencode ever ships it — the probe makes
 *   this future-proof; nothing else changes when they do.
 */

import { fetchJson } from "./http.ts";
import { getApiKeyCredentials } from "./credentials.ts";
import type { ProviderSnapshot } from "./types.ts";
import { parseOpencodeUsage } from "../parsers/opencode.ts";

export { parseOpencodeUsage } from "../parsers/opencode.ts";

const GO_USAGE_URL = "https://opencode.ai/zen/go/v1/usage";
const ZEN_USAGE_URL = "https://opencode.ai/zen/v1/usage";

export async function collectOpencodeGo(): Promise<ProviderSnapshot> {
	const { key } = await getApiKeyCredentials("opencode-go");
	if (!key) {
		return unavailable("opencode-go", "No opencode-go API key found in ~/.pi/agent/auth.json (or OPENCODE_GO_API_KEY).");
	}

	try {
		const { status, json } = await fetchJson(GO_USAGE_URL, {
			headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
		});
		if (status !== 200) {
			return unavailable("opencode-go", `usage endpoint returned HTTP ${status}`);
		}
		return parseOpencodeUsage(json, "opencode-go");
	} catch (error) {
		return unavailable("opencode-go", errorMessage(error));
	}
}

export async function collectOpencodeZen(): Promise<ProviderSnapshot> {
	const { key } = await getApiKeyCredentials("opencode");
	if (!key) {
		return unavailable("opencode-zen", 'No opencode zen API key found in ~/.pi/agent/auth.json (provider "opencode").');
	}

	try {
		const { status, json } = await fetchJson(ZEN_USAGE_URL, {
			headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
		});
		if (status === 200) {
			return parseOpencodeUsage(json, "opencode-zen");
		}

		return unavailable(
			"opencode-zen",
			`no public balance API yet (${status}). Track spend via the dashboard at https://opencode.ai/zen.`,
		);
	} catch (error) {
		return unavailable("opencode-zen", errorMessage(error));
	}
}

function unavailable(provider: "opencode-go" | "opencode-zen", message: string): ProviderSnapshot {
	return {
		provider,
		displayName: provider === "opencode-go" ? "go" : "zen",
		status: "unavailable",
		message,
		windows: [],
		extra: [],
		fetchedAt: new Date().toISOString(),
	};
}

function errorMessage(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}
