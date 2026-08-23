/**
 * Minimal JSON fetch helper with timeout. Used by all adapters.
 */

export interface JsonResponse {
	status: number;
	json: unknown;
}

export async function fetchJson(
	url: string,
	init: RequestInit = {},
	timeoutMs = 12_000,
): Promise<JsonResponse> {
	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), timeoutMs);
	try {
		const response = await fetch(url, { ...init, signal: controller.signal });
		const text = await response.text();
		let json: unknown = null;
		if (text) {
			try {
				json = JSON.parse(text);
			} catch {
				json = text;
			}
		}
		return { status: response.status, json };
	} finally {
		clearTimeout(timer);
	}
}