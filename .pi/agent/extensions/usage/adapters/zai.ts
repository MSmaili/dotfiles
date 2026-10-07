/**
 * z.ai (GLM Coding Plan) adapter.
 *
 * `GET https://open.bigmodel.cn/api/monitor/usage/quota/limit` with the
 * zai-coding-cn API key. Verified live: returns a monitor envelope whose
 * `data.limits[]` carries one entry per window:
 *
 *   { type: "CREDIT_LIMIT", unit: 3|6, usage, currentValue, remaining,
 *     percentage, nextResetTime: <epoch ms> }
 *
 * unit 3 = 5-hour rolling window, unit 6 = monthly. `data.level` is the
 * plan tier ("lite", ...).
 *
 * ponytail: China region only (pi stores zai-coding-cn). Add an api.z.ai
 * global variant when a global key actually shows up in auth.
 */

import { getApiKeyCredentials } from "./credentials.ts";
import { fetchJson } from "./http.ts";
import type { ProviderSnapshot } from "./types.ts";
import { parseQuotaLimit } from "../parsers/zai.ts";

export { parseQuotaLimit } from "../parsers/zai.ts";

const USAGE_URL = "https://open.bigmodel.cn/api/monitor/usage/quota/limit";

export async function collectZai(): Promise<ProviderSnapshot> {
	const { key } = await getApiKeyCredentials("zai");
	if (!key) {
		return unavailable('No z.ai API key found in ~/.pi/agent/auth.json (provider "zai-coding-cn" or ZHIPUAI_API_KEY).');
	}

	try {
		const { status, json } = await fetchJson(USAGE_URL, {
			headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
		});
		if (status !== 200) {
			return unavailable(`usage endpoint returned HTTP ${status}`);
		}
		const parsed = parseQuotaLimit(json);
		if (!parsed) return unavailable("usage response contained no window data");
		return { ...parsed, fetchedAt: new Date().toISOString() };
	} catch (error) {
		return unavailable(error instanceof Error ? error.message : String(error));
	}
}

function unavailable(message: string): ProviderSnapshot {
	return {
		provider: "zai",
		displayName: "z.ai",
		status: "unavailable",
		message,
		windows: [],
		extra: [],
		fetchedAt: new Date().toISOString(),
	};
}
