import assert from "node:assert/strict";
import test from "node:test";
import { parseWham } from "../adapters/chatgpt.ts";
import { formatWindowLabel, remainingPercent } from "../format.ts";

test("parses ChatGPT's current five-hour and weekly limits", () => {
	const snapshot = parseWham({
		plan_type: "plus",
		rate_limit: {
			primary_window: { used_percent: 3, limit_window_seconds: 18_000 },
			secondary_window: { used_percent: 1, limit_window_seconds: 604_800 },
		},
		spend_control: { reached: false, individual_limit: null },
		rate_limit_reset_credits: { available_count: 1, applicable_available_count: 0 },
	});

	assert.equal(snapshot.plan, "PLUS");
	assert.deepEqual(
		snapshot.windows.map((window) => [formatWindowLabel(window), remainingPercent(window)]),
		[
			["5-hour", 97],
			["weekly", 99],
		],
	);
	assert.deepEqual(snapshot.extra, [
		"spend control: off",
		"reset credits: 1 banked, 0 applicable now",
	]);
});

test("keeps legacy percent-left windows compatible", () => {
	const snapshot = parseWham({
		rate_limits: {
			five_hour: { percent_left: "87", limit_window_seconds: "18000" },
			weekly: { percent_left: 42, limit_window_seconds: 604_800 },
		},
	});

	assert.deepEqual(snapshot.windows.map(remainingPercent), [87, 42]);
});
