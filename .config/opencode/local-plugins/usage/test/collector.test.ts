import assert from "node:assert/strict";
import { test } from "node:test";
import type { IntegrationDomain } from "@opencode/plugin/promise/integration";
import { createCollector } from "../collector.ts";
import { chatgptAccountID } from "../providers.ts";
import { formatSummaryText, parseOpencodeUsage } from "../shared.ts";

type Connections = IntegrationDomain["connection"];
type Credential = NonNullable<Awaited<ReturnType<Connections["resolve"]>>>;

function accounts(values: Record<string, Credential>): Connections {
  return {
    async active(id) {
      return values[id] ? { type: "env", name: id } : undefined;
    },
    async resolve(connection) {
      assert.equal(connection.type, "env");
      return structuredClone(values[(connection as { name: string }).name]);
    },
  };
}

function oauth(metadata: Record<string, unknown> = { accountId: "test-account" }): Credential {
  return {
    type: "oauth",
    methodID: "chatgpt-browser" as Extract<Credential, { type: "oauth" }>["methodID"],
    access: "test-access-token",
    refresh: "test-refresh-token",
    expires: Date.now() + 60_000,
    metadata,
  };
}

const go = { usage: { rolling: { status: "ok", percent: 25, resetsAt: "2026-10-01T00:00:00Z" } } };
const wham = { plan_type: "plus", rate_limit: { primary_window: { used_percent: 12, limit_window_seconds: 18_000, reset_after_seconds: 120 } } };

test("native credentials, per-provider endpoints, and partial failures", async () => {
  const seen: string[] = [];
  const collect = createCollector(accounts({
    openai: oauth(),
    "opencode-go": { type: "key", key: "test-go-key" },
    opencode: { type: "key", key: "test-zen-key" },
    "zhipuai-coding-plan": { type: "key", key: "test-cn-key" },
  }), {
    fetch: async (input, init) => {
      const url = String(input);
      seen.push(url);
      assert.equal(init?.redirect, "error");
      assert.ok(init?.signal);
      const headers = new Headers(init?.headers);
      if (url.includes("chatgpt.com")) {
        assert.equal(headers.get("authorization"), "Bearer test-access-token");
        assert.equal(headers.get("chatgpt-account-id"), "test-account");
        return Response.json(wham);
      }
      if (url.includes("/go/")) return Response.json(go);
      if (url.includes("/zen/")) return new Response("Not found", { status: 404 });
      throw new Error("failed with test-cn-key");
    },
  });
  const result = await collect();
  assert.equal(seen.length, 4);
  assert.ok(seen.includes("https://open.bigmodel.cn/api/monitor/usage/quota/limit"));
  assert.deepEqual(result.providers.map((p) => p.status), ["ok", "ok", "unavailable", "unavailable"]);
  assert.equal(result.providers[1]?.windows[0]?.percentUsed, 25);
  assert.match(result.providers[2]!.message!, /No public balance API/);
  assert.doesNotMatch(JSON.stringify(result), /test-(access|refresh|go|zen|cn|account)/);
});

test("cache survives credential clones, expires, refreshes, and isolates account switches", async () => {
  let now = Date.parse("2026-09-27T12:00:00Z");
  let calls = 0;
  const values: Record<string, Credential> = { "opencode-go": { type: "key", key: "first-account" } };
  const collect = createCollector(accounts(values), {
    now: () => now,
    fetch: async () => { calls++; return Response.json(go); },
  });
  await collect();
  await collect();
  assert.equal(calls, 1);
  await collect(true);
  assert.equal(calls, 2);
  now += 60_001;
  await collect();
  assert.equal(calls, 3);
  values["opencode-go"] = { type: "key", key: "second-account" };
  await collect();
  assert.equal(calls, 4);
  delete values["opencode-go"];
  const disconnected = await collect();
  assert.equal(calls, 4);
  assert.equal(disconnected.providers[1]?.status, "unavailable");
});

test("ChatGPT caches anchored reset times and redacts echoed secrets", async () => {
  const now = Date.parse("2026-09-27T12:00:00Z");
  const collect = createCollector(accounts({ openai: oauth() }), {
    now: () => now,
    fetch: async () => Response.json({ ...wham, credits: { has_credits: true, balance: "test-access-token test-refresh-token test-account\u001b" } }),
  });
  const result = await collect();
  assert.equal(result.providers[0]?.windows[0]?.resetsAt, now + 120_000);
  assert.equal(result.providers[0]?.windows[0]?.resetsInSeconds, undefined);
  assert.doesNotMatch(JSON.stringify(result), /test-access-token|test-refresh-token|test-account|\\u001b/);
});

test("API keys never go to ChatGPT and absent credentials make no requests", async () => {
  const collect = createCollector(accounts({ openai: { type: "key", key: "api-key" } }), {
    fetch: async () => { throw new Error("must not fetch"); },
  });
  const result = await collect();
  assert.match(result.providers[0]!.message!, /OAuth/);
  assert.ok(result.providers.every((p) => p.status === "unavailable"));
});

test("401 responses do not expose bodies or perform independent OAuth refresh", async () => {
  let calls = 0;
  const collect = createCollector(accounts({ openai: oauth() }), {
    fetch: async () => { calls++; return new Response("test-access-token", { status: 401 }); },
  });
  const result = await collect();
  assert.equal(calls, 1);
  assert.match(result.providers[0]!.message!, /Reconnect openai/);
  assert.doesNotMatch(JSON.stringify(result), /test-access-token/);
});

test("z.ai global accounts use the global monitor, not the China endpoint", async () => {
  const collect = createCollector(accounts({ "zai-coding-plan": { type: "key", key: "global-key" } }), {
    fetch: async (url) => {
      assert.equal(url, "https://api.z.ai/api/monitor/usage/quota/limit");
      return Response.json({ data: { limits: [{ unit: 3, percentage: 10, nextResetTime: 1_900_000_000_000 }] } });
    },
  });
  assert.equal((await collect()).providers[3]?.windows[0]?.percentUsed, 10);
});

test("cancelling a caller aborts in-flight network work", async () => {
  const controller = new AbortController();
  const collect = createCollector(accounts({ openai: oauth() }), {
    fetch: async (_url, init) => new Promise((_resolve, reject) => {
      init!.signal!.addEventListener("abort", () => reject(init!.signal!.reason), { once: true });
      controller.abort();
    }),
  });
  await assert.rejects(collect(false, controller.signal), { name: "AbortError" });
});

test("malformed successful responses do not show a healthy quota", async () => {
  const collect = createCollector(accounts({ openai: oauth(), "opencode-go": { type: "key", key: "test-key" } }), {
    fetch: async () => Response.json({ unexpected: true }),
  });
  assert.ok((await collect()).providers.every((p) => p.status === "unavailable"));
});

test("account ID falls back to OpenAI JWT claims", () => {
  const credential = oauth({});
  assert.equal(credential.type, "oauth");
  const token = Buffer.from(JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: "jwt-account" } })).toString("base64url");
  assert.equal(chatgptAccountID({ ...credential, access: `header.${token}.signature` } as Credential), "jwt-account");
  assert.equal(chatgptAccountID(credential), undefined);
});

test("shared Go/Zen parser supports reset epochs and excludes failed windows", () => {
  const result = parseOpencodeUsage({ usage: {
    rolling: { status: "ok", percent: "20", resetsAt: 1_900_000_000_000 },
    weekly: { status: "error", percent: 50 },
    monthly: { used_percent: 90, reset_at: "2026-10-01T00:00:00Z" },
  } }, "opencode-go");
  assert.equal(result.windows.length, 2);
  assert.equal(result.windows[0]?.resetsAt, 1_900_000_000_000);
  assert.equal(result.extra[0], "weekly: status error");
  assert.equal(parseOpencodeUsage({}, "opencode-zen").status, "unavailable");
});

test("Go follows Console provider mapping instead of an unrelated dedicated Go key", async () => {
  const seen: string[] = [];
  const collect = createCollector(accounts({
    opencode: oauth({ server: "https://opencode.ai/console/", orgID: "test-org" }),
    "opencode-go": { type: "key", key: "unrelated-go-key" },
  }), {
    integrationID: async () => "opencode",
    fetch: async (input, init) => {
      const url = String(input);
      seen.push(url);
      const headers = new Headers(init?.headers);
      assert.equal(headers.get("authorization"), "Bearer test-access-token");
      assert.equal(headers.get("x-org-id"), "test-org");
      assert.ok(!init?.method || init.method === "GET");
      if (url.endsWith("/api/go/status")) return Response.json({ product: "go", access: {
        endsAt: "2026-10-01T00:00:00Z",
        meters: { month: { usedMicroCents: "3000000000", limitMicroCents: "6000000000" } },
      } });
      if (url.endsWith("/api/billing/status")) return Response.json({ balanceMicroCents: "100000000", availableMicroCents: "100000000" });
      throw new Error("Unexpected endpoint");
    },
  });
  const result = await collect();
  assert.deepEqual(seen.sort(), ["https://opencode.ai/console/api/billing/status", "https://opencode.ai/console/api/go/status"]);
  assert.equal(result.providers[1]?.windows[0]?.percentUsed, 50);
  assert.equal(result.providers[2]?.status, "ok");
  assert.doesNotMatch(JSON.stringify(result), /test-org|test-access-token|unrelated-go-key/);
});

test("Console cache is scoped to workspace even when access token is unchanged", async () => {
  let calls = 0;
  const values: Record<string, Credential> = { opencode: oauth({ orgID: "first-org" }) };
  const collect = createCollector(accounts(values), {
    integrationID: async () => "opencode",
    fetch: async (input) => {
      calls++;
      return String(input).endsWith("/api/go/status")
        ? Response.json(null)
        : Response.json({ balanceMicroCents: "0", availableMicroCents: "0" });
    },
  });
  await collect();
  await collect();
  assert.equal(calls, 2);
  values.opencode = oauth({ orgID: "second-org" });
  await collect();
  assert.equal(calls, 4);
});

test("Console role errors explain permissions without misreporting missing credentials", async () => {
  const collect = createCollector(accounts({ opencode: oauth({ orgID: "test-org" }) }), {
    integrationID: async () => "opencode",
    fetch: async () => new Response("forbidden", { status: 403 }),
  });
  const result = await collect();
  assert.match(result.providers[1]!.message!, /workspace role/);
  assert.match(result.providers[2]!.message!, /workspace role/);
});

test("an older request cannot overwrite a refreshed cache entry", async () => {
  const { promise: started, resolve: start } = Promise.withResolvers<void>();
  const { promise: pending, resolve: finish } = Promise.withResolvers<Response>();
  let calls = 0;
  const collect = createCollector(accounts({ "opencode-go": { type: "key", key: "test-key" } }), {
    fetch: async () => {
      if (++calls === 1) {
        start();
        return pending;
      }
      return Response.json({ usage: { rolling: { percent: 70 } } });
    },
  });
  const older = collect();
  await started;
  assert.equal((await collect(true)).providers[1]?.windows[0]?.percentUsed, 70);
  finish(Response.json({ usage: { rolling: { percent: 10 } } }));
  assert.equal((await older).providers[1]?.windows[0]?.percentUsed, 10);
  assert.equal((await collect()).providers[1]?.windows[0]?.percentUsed, 70);
  assert.equal(calls, 2);
});

test("invalid reset timestamps do not break the tool summary or other providers", async () => {
  const collect = createCollector(accounts({
    openai: oauth(),
    "opencode-go": { type: "key", key: "test-key" },
  }), {
    fetch: async (url) => Response.json(String(url).includes("chatgpt.com")
      ? { rate_limit: { primary_window: { used_percent: 12, reset_at: 1e300 } } }
      : go),
  });
  const result = await collect();
  assert.equal(result.providers[0]?.windows[0]?.resetsAt, undefined);
  assert.equal(result.providers[1]?.status, "ok");
  assert.match(formatSummaryText(result), /reset time unknown/);
});

test("slow credential resolution cannot make an older refresh replace a newer one", async () => {
  const { promise: started, resolve: start } = Promise.withResolvers<void>();
  const { promise: pending, resolve: finish } = Promise.withResolvers<void>();
  const connections = accounts({ "opencode-go": { type: "key", key: "test-key" } });
  const resolve = connections.resolve;
  let resolutions = 0;
  let calls = 0;
  const collect = createCollector({
    ...connections,
    async resolve(connection) {
      if (++resolutions === 1) {
        start();
        await pending;
      }
      return resolve(connection);
    },
  }, {
    fetch: async () => Response.json({ usage: { rolling: { percent: ++calls === 1 ? 70 : 10 } } }),
  });
  const older = collect(true);
  await started;
  await collect(true);
  finish();
  await older;
  assert.equal((await collect()).providers[1]?.windows[0]?.percentUsed, 70);
  assert.equal(calls, 2);
});

test("reset timestamps are normalized to milliseconds and invalid relative resets are omitted", async () => {
  const now = Date.parse("2026-10-01T12:00:00Z");
  const collect = createCollector(accounts({ openai: oauth() }), {
    now: () => now,
    fetch: async () => Response.json({ rate_limit: {
      primary_window: { used_percent: 12, reset_at: now / 1000 },
      secondary_window: { used_percent: 20, reset_after_seconds: 1e300 },
    } }),
  });
  const windows = (await collect()).providers[0]!.windows;
  assert.equal(windows[0]?.resetsAt, now);
  assert.equal(windows[1]?.resetsAt, undefined);
  assert.equal(windows[1]?.resetsInSeconds, undefined);
});
