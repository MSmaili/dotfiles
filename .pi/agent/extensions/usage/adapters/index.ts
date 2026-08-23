/**
 * Adapter registry for the /usage extension.
 *
 * Providers are pluggable: add a file to adapters/ and register it here.
 * The UI (dashboard, card, tool text) only consumes ProviderSnapshot values.
 */

import { collectChatgpt } from "./chatgpt.ts";
import { collectOpencodeGo, collectOpencodeZen } from "./opencode.ts";
import type { Adapter, ProviderId, ProviderSnapshot, UsageSnapshot } from "./types.ts";

const ADAPTERS: Adapter[] = [
	{ id: "chatgpt", displayName: "chatgpt", collect: collectChatgpt },
	{ id: "opencode-go", displayName: "go", collect: collectOpencodeGo },
	{ id: "opencode-zen", displayName: "zen", collect: collectOpencodeZen },
];

const CACHE_TTL_MS = 60_000;
const cache = new Map<ProviderId, { at: number; snapshot: ProviderSnapshot }>();

/** Collect all providers, with a short cache so repeated calls stay cheap. */
export async function runAllAdapters(force = false): Promise<UsageSnapshot> {
	const providers = await Promise.all(
		ADAPTERS.map(async (adapter) => {
			const cached = cache.get(adapter.id);
			if (!force && cached && Date.now() - cached.at < CACHE_TTL_MS) {
				return cached.snapshot;
			}
			const snapshot = await adapter.collect();
			cache.set(adapter.id, { at: Date.now(), snapshot });
			return snapshot;
		}),
	);
	return { generatedAt: new Date().toISOString(), providers };
}

export function registeredProviders(): ProviderId[] {
	return ADAPTERS.map((adapter) => adapter.id);
}

export type { ProviderId, ProviderSnapshot, UsageSnapshot, UsageWindow } from "./types.ts";