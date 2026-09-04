import assert from "node:assert/strict";
import test from "node:test";
import { parseQuotaLimit } from "../adapters/zai.ts";
import { formatWindowLabel, remainingPercent } from "../format.ts";

test("parses z.ai quota/limit envelope (live shape)", () => {
	const snapshot = parseQuotaLimit({
		code: 200,
		msg: "操作成功",
		success: true,
		data: {
			limits: [
				{
					type: "CREDIT_LIMIT",
					unit: 3,
					number: 5,
					usage: 2000,
					currentValue: 442,
					remaining: 1557,
					percentage: 22,
					nextResetTime: 1787877214433,
				},
				{
					type: "CREDIT_LIMIT",
					unit: 6,
					number: 1,
					usage: 10000,
					currentValue: 442,
					remaining: 9557,
					percentage: 4,
					nextResetTime: 1788463852998,
				},
			],
			level: "lite",
		},
	});

	assert.ok(snapshot);
	assert.equal(snapshot.provider, "zai");
	assert.equal(snapshot.plan, "LITE");
	assert.deepEqual(
		snapshot.windows.map((window) => [formatWindowLabel(window), remainingPercent(window)]),
		[
			["5-hour rolling", 78],
			["monthly", 96],
		],
	);
	assert.deepEqual(
		snapshot.windows.map((window) => window.resetsAt),
		[1787877214433, 1788463852998],
	);
});

test("returns undefined when the envelope has no limits", () => {
	assert.equal(parseQuotaLimit({ code: 200, success: true, data: { limits: [], level: "lite" } }), undefined);
	assert.equal(parseQuotaLimit(null), undefined);
});
