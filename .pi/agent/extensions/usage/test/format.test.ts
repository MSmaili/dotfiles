import assert from "node:assert/strict";
import test from "node:test";
import { formatResetTime, formatResetsIn, resolveResetDate } from "../format.ts";
import type { UsageWindow } from "../adapters/types.ts";

const window: UsageWindow = { id: "rolling", label: "rolling", percentUsed: 12 };

test("invalid absolute and relative reset times stay unknown", () => {
	for (const resetsAt of [NaN, Infinity, -Infinity, 1e300, "not a date"]) {
		const invalid = { ...window, resetsAt };
		assert.equal(resolveResetDate(invalid), undefined);
		assert.equal(formatResetTime(invalid), "");
		assert.equal(formatResetsIn(invalid), "reset time unknown");
	}
	for (const resetsInSeconds of [NaN, Infinity, 1e300]) {
		const invalid = { ...window, resetsInSeconds };
		assert.equal(resolveResetDate(invalid), undefined);
		assert.equal(formatResetTime(invalid), "");
		assert.equal(formatResetsIn(invalid), "reset time unknown");
	}
});

test("reset dates support epoch seconds, milliseconds, and ISO strings", () => {
	const milliseconds = Date.parse("2026-10-01T12:00:00Z");
	for (const resetsAt of [milliseconds / 1000, milliseconds, "2026-10-01T12:00:00Z"]) {
		assert.equal(resolveResetDate({ ...window, resetsAt })?.getTime(), milliseconds);
	}
});
