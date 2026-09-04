/**
 * Shared types for the /usage extension.
 *
 * Every provider is exposed through an `Adapter` that produces a
 * `ProviderSnapshot`. The UI layer only knows these types — adding a new
 * provider means adding one adapter file, nothing else changes.
 */

export type ProviderId = "chatgpt" | "opencode-go" | "opencode-zen" | "zai";

/** A single usage window (e.g. rolling 5h, weekly, monthly). */
export interface UsageWindow {
	/** Stable id, e.g. "primary", "secondary", "rolling", "weekly", "monthly". */
	id: string;
	/** Short human label, e.g. "weekly". */
	label: string;
	/** Percent of the window already used (0-100). */
	percentUsed: number;
	/** When the window resets: epoch seconds, epoch ms, or ISO-8601 string. */
	resetsAt?: number | string;
	/** Window length in seconds when the API reports it. */
	windowSeconds?: number;
	/** Seconds until reset when the API reports it. */
	resetsInSeconds?: number;
}

export type ProviderStatus = "ok" | "error" | "unavailable";

export interface ProviderSnapshot {
	provider: ProviderId;
	displayName: string;
	/** e.g. "PLUS" for ChatGPT plan type. */
	plan?: string;
	status: ProviderStatus;
	/**
	 * Human-readable note:
	 * - "ok": summary line if any
	 * - "error": why the adapter failed (redacted, no secrets)
	 * - "unavailable": why no data exists (e.g. no public API)
	 */
	message?: string;
	/** Windows with usage data. */
	windows: UsageWindow[];
	/** Extra status lines: credits, spend control, reset credits, ... */
	extra: string[];
	fetchedAt: string;
}

export interface UsageSnapshot {
	generatedAt: string;
	providers: ProviderSnapshot[];
}

export interface Adapter {
	id: ProviderId;
	displayName: string;
	/** Collect a fresh snapshot. Never throw — return an error snapshot instead. */
	collect(): Promise<ProviderSnapshot>;
}