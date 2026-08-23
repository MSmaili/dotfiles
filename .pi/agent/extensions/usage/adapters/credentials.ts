/**
 * Credential resolution for the /usage extension.
 *
 * IMPORTANT (pushing this repo): this file contains NO secrets and NO
 * machine-specific values. All credentials are read at runtime from
 * `~/.pi/agent/auth.json` (pi's own auth store — the same file pi itself
 * uses, which is excluded from this repo) with optional environment
 * variable fallbacks.
 *
 * Secrets are only ever held in memory inside this module. Never log,
 * persist, or include credentials in error messages.
 */

import { homedir } from "node:os";
import { join } from "node:path";
import { readFile, rename, writeFile } from "node:fs/promises";

export const PI_AUTH_FILE = join(homedir(), ".pi", "agent", "auth.json");

export interface ChatgptCredentials {
	access?: string;
	refresh?: string;
	accountId?: string;
}

export interface ApiKeyCredentials {
	key?: string;
}

interface AuthFileShape {
	"openai-codex"?: {
		type?: string;
		access?: string;
		refresh?: string;
		accountId?: string;
		expires?: number;
		[key: string]: unknown;
	};
	opencode?: {
		type?: string;
		key?: string;
		[key: string]: unknown;
	};
	"opencode-go"?: {
		type?: string;
		key?: string;
		[key: string]: unknown;
	};
	[key: string]: unknown;
}

/** Read pi's auth store. Returns {} on any read/parse error. */
export async function readAuthFile(): Promise<AuthFileShape> {
	try {
		const raw = await readFile(PI_AUTH_FILE, "utf8");
		const parsed: unknown = JSON.parse(raw);
		if (parsed && typeof parsed === "object") return parsed as AuthFileShape;
	} catch {
		// Missing or unreadable auth file — treated as "no credentials".
	}
	return {};
}

export async function getChatgptCredentials(): Promise<ChatgptCredentials> {
	const auth = await readAuthFile();
	const entry = auth["openai-codex"];
	const access = entry?.access ?? process.env.OPENAI_CODEX_ACCESS_TOKEN;
	const refresh = entry?.refresh ?? process.env.OPENAI_CODEX_REFRESH_TOKEN;
	const accountId = entry?.accountId ?? process.env.OPENAI_CODEX_ACCOUNT_ID;
	if (!access) return {};
	return { access, refresh, accountId };
}

export async function getApiKeyCredentials(
	provider: "opencode" | "opencode-go",
): Promise<ApiKeyCredentials> {
	const auth = await readAuthFile();
	if (provider === "opencode") {
		return { key: auth.opencode?.key ?? process.env.OPENCODE_ZEN_API_KEY };
	}
	return { key: auth["opencode-go"]?.key ?? process.env.OPENCODE_GO_API_KEY };
}

/** Decode the `client_id` claim from an OpenAI OAuth JWT (public value). */
export function jwtClientId(accessToken: string): string | undefined {
	try {
		const payload = accessToken.split(".")[1];
		if (!payload) return undefined;
		const json = Buffer.from(payload.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8");
		const claims: { client_id?: unknown } = JSON.parse(json);
		return typeof claims.client_id === "string" ? claims.client_id : undefined;
	} catch {
		return undefined;
	}
}

/**
 * Atomically update the openai-codex entry in pi's auth store after an OAuth
 * refresh. Preserves every other key and provider untouched.
 */
export async function persistRefreshedChatgptTokens(
	access: string,
	refresh: string | undefined,
	expiresInSeconds: number | undefined,
): Promise<void> {
	const auth = await readAuthFile();
	const entry = auth["openai-codex"] ?? {};
	auth["openai-codex"] = {
		...entry,
		type: entry.type ?? "oauth",
		access,
		...(refresh ? { refresh } : {}),
		expires: Date.now() + (expiresInSeconds ? expiresInSeconds * 1000 : 0),
	};
	const tmp = `${PI_AUTH_FILE}.tmp-${process.pid}`;
	await writeFile(tmp, JSON.stringify(auth, null, 2), { mode: 0o600 });
	await rename(tmp, PI_AUTH_FILE);
}

/** Strip credential material from error strings (defense in depth). */
export function redact(value: string, secrets: (string | undefined)[]): string {
	let out = value;
	for (const secret of secrets) {
		if (secret && secret.length >= 8) out = out.replaceAll(secret, "***");
	}
	return out;
}