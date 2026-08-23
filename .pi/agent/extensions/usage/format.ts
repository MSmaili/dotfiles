/**
 * Formatting helpers shared by all renderers (overlay, card, text summary).
 */

import type { UsageWindow } from "./adapters/types.ts";

/** Percent of the window that is still left, 0-100 rounded. */
export function remainingPercent(window: UsageWindow): number {
	const used = Number.isFinite(window.percentUsed) ? window.percentUsed : 0;
	return Math.min(100, Math.max(0, Math.round(100 - used)));
}

/** Interpret resetsAt (epoch seconds, epoch ms, or ISO string). */
export function resolveResetDate(window: UsageWindow): Date | undefined {
	const raw = window.resetsAt;
	if (raw == null) {
		if (typeof window.resetsInSeconds === "number") {
			return new Date(Date.now() + window.resetsInSeconds * 1000);
		}
		return undefined;
	}
	if (typeof raw === "number") {
		return new Date(raw > 1e12 ? raw : raw * 1000);
	}
	const date = new Date(raw);
	return Number.isNaN(date.getTime()) ? undefined : date;
}

/** "in 5d 2h", "in 12m", "in 20s", or "now". */
export function formatResetsIn(window: UsageWindow): string {
	if (typeof window.resetsInSeconds === "number") {
		return formatDuration(window.resetsInSeconds);
	}
	const date = resolveResetDate(window);
	if (!date) return "reset time unknown";
	return formatDuration(Math.max(0, Math.round((date.getTime() - Date.now()) / 1000)));
}

export function formatDuration(totalSeconds: number): string {
	const seconds = Math.max(0, Math.round(totalSeconds));
	if (seconds < 60) return "now";
	const minutes = Math.floor(seconds / 60);
	if (minutes < 60) return `in ${minutes}m`;
	const hours = Math.floor(minutes / 60);
	if (hours < 24) return `in ${hours}h ${minutes % 60}m`;
	const days = Math.floor(hours / 24);
	return `in ${days}d ${hours % 24}h`;
}

/** Local wall-clock time for a reset, e.g. "Tue, Aug 26 08:35". */
export function formatResetTime(window: UsageWindow): string {
	const date = resolveResetDate(window);
	if (!date) return "";
	return new Intl.DateTimeFormat(undefined, {
		weekday: "short",
		month: "short",
		day: "numeric",
		hour: "2-digit",
		minute: "2-digit",
		hour12: false,
	}).format(date);
}
/** Full label for a window. */
export function formatWindowLabel(window: UsageWindow): string {
	if (window.windowSeconds === 300) return "5-hour rolling";
	if (window.windowSeconds === 604800) return "weekly";
	if (window.windowSeconds === 2_592_000) return "monthly";
	return window.label;
}

export function formatClock(iso: string): string {
	const date = new Date(iso);
	if (Number.isNaN(date.getTime())) return "";
	return new Intl.DateTimeFormat(undefined, {
		hour: "2-digit",
		minute: "2-digit",
		second: "2-digit",
		hour12: false,
	}).format(date);
}