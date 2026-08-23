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
import type { ProviderSnapshot, UsageWindow } from "./types.ts";

const GO_USAGE_URL = "https://opencode.ai/zen/go/v1/usage";
const ZEN_USAGE_URL = "https://opencode.ai/zen/v1/usage";

interface OpencodeWindowRaw {
	status?: unknown;
	percent?: unknown;
	resetsAt?: unknown;
	used_percent?: unknown;
	reset_at?: unknown;
	[key: string]: unknown;
}

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
		const raw = (json ?? {}) as { usage?: Record<string, OpencodeWindowRaw> };
		const usage = raw.usage ?? {};
		const windows: UsageWindow[] = [];
		const notes: string[] = [];

		for (const [id, label] of [
			["rolling", "5-hour rolling"],
			["weekly", "weekly"],
			["monthly", "monthly"],
		] as const) {
			const window = usage[id];
			if (!window) continue;
			if (window.status !== undefined && window.status !== "ok") {
				notes.push(`${label}: status ${String(window.status)}`);
				continue;
			}
			const percentUsed = toNumber(window.percent) ?? toNumber(window.used_percent);
			if (percentUsed == null) continue;
			windows.push({
				id,
				label,
				percentUsed,
				...(typeof window.resetsAt === "string" ? { resetsAt: window.resetsAt } : {}),
				...(typeof window.reset_at === "string" ? { resetsAt: window.reset_at } : {}),
			});
		}

		if (windows.length === 0) {
			return unavailable("opencode-go", "usage response contained no window data");
		}

		return {
			provider: "opencode-go",
			displayName: "go",
			status: "ok",
			windows,
			extra: notes,
			fetchedAt: new Date().toISOString(),
		};
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
			// opencode shipped an endpoint — parse it with the same logic as go.
			const raw = (json ?? {}) as { usage?: Record<string, OpencodeWindowRaw> };
			const usage = raw.usage ?? {};
			const windows: UsageWindow[] = [];
			for (const [id, label] of [
				["rolling", "5-hour rolling"],
				["weekly", "weekly"],
				["monthly", "monthly"],
			] as const) {
				const window = usage[id];
				if (!window) continue;
				const percentUsed = toNumber(window.percent) ?? toNumber(window.used_percent);
				if (percentUsed == null) continue;
				windows.push({
					id,
					label,
					percentUsed,
					...(typeof window.resetsAt === "string" ? { resetsAt: window.resetsAt } : {}),
					...(typeof window.reset_at === "string" ? { resetsAt: window.reset_at } : {}),
				});
			}
			return {
				provider: "opencode-zen",
				displayName: "zen",
				status: "ok",
				windows,
				extra: [],
				fetchedAt: new Date().toISOString(),
			};
		}

		return unavailable(
			"opencode-zen",
			`no public balance API yet (${status}). Track spend via the dashboard at https://opencode.ai/zen.`,
		);
	} catch (error) {
		return unavailable("opencode-zen", errorMessage(error));
	}
}

function toNumber(value: unknown): number | null {
	if (typeof value === "number" && Number.isFinite(value)) return value;
	if (typeof value === "string" && value.trim() !== "") {
		const numeric = Number(value);
		if (Number.isFinite(numeric)) return numeric;
	}
	return null;
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