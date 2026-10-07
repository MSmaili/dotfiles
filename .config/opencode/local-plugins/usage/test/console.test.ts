import assert from "node:assert/strict";
import { test } from "node:test";
import { parseConsoleGo, parseConsoleBilling } from "../console.ts";

const consoleGo = {
  product: "go-plus",
  useBalance: false,
  cancelAtPeriodEnd: true,
  access: {
    endsAt: "2026-10-01T00:00:00Z",
    meters: {
      fiveHour: { limitMicroCents: "1200000000", usedMicroCents: "300000000", resetsAt: "2026-09-28T00:00:00Z" },
      week: { limitMicroCents: "3000000000", usedMicroCents: "1500000000", resetsAt: "2026-09-28T00:00:00Z" },
      month: { limitMicroCents: "6000000000", usedMicroCents: "4500000000" },
    },
  },
};

test("Console Go meters become the same dashboard windows as legacy Go", () => {
  const result = parseConsoleGo(consoleGo);
  assert.equal(result.status, "ok");
  assert.equal(result.plan, "GO PLUS");
  assert.deepEqual(result.windows.map((window) => [window.id, window.percentUsed]), [
    ["rolling", 25], ["weekly", 50], ["monthly", 75],
  ]);
  assert.equal(result.windows[2]?.resetsAt, consoleGo.access.endsAt);
  assert.ok(result.extra.includes("use balance beyond limits: off"));
  assert.ok(result.extra.includes("cancels at the end of the paid period"));
});

test("Console Go handles unused rolling windows and over-limit usage", () => {
  const raw = structuredClone(consoleGo);
  const meters = raw.access.meters;
  const result = parseConsoleGo({ ...raw, access: { ...raw.access, meters: {
    ...meters,
    fiveHour: { ...meters.fiveHour, usedMicroCents: "0", resetsAt: null },
    week: { ...meters.week, usedMicroCents: "3300000000" },
  } } });
  assert.equal(result.windows[0]?.resetsAt, undefined);
  assert.equal(result.windows[1]?.percentUsed, 110);
  assert.ok(result.extra.includes("5-hour window starts on first use"));
});

test("missing subscriptions, expired access, and invalid meters stay unavailable", () => {
  assert.match(parseConsoleGo(null).message!, /No Go subscription/);
  assert.match(parseConsoleGo({ access: null, renewalPending: true }).message!, /renewal is pending/);
  for (const raw of [{}, { access: {} }, { access: { meters: { week: { limitMicroCents: "0", usedMicroCents: "0" } } } }]) {
    assert.equal(parseConsoleGo(raw).status, "unavailable");
  }
});

test("Console billing preserves negative balances and formats microcents exactly", () => {
  const result = parseConsoleBilling({ balanceMicroCents: "-123456789", availableMicroCents: "0", creditLimitMicroCents: "2000000000" });
  assert.equal(result.status, "ok");
  assert.equal(result.displayName, "opencode");
  assert.deepEqual(result.extra, ["credits balance: -$1.23", "available balance: $0.00", "credit limit: $20.00"]);
  assert.deepEqual(parseConsoleBilling({ balanceMicroCents: "100500000", availableMicroCents: "100500000" }).extra, ["credits balance: $1.01"]);
  assert.equal(parseConsoleBilling({ balanceMicroCents: "oops" }).status, "unavailable");
});
