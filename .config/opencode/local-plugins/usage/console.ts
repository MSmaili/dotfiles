import type { Credential } from "@opencode/plugin";
import type { ProviderSnapshot } from "./shared.ts";

/** Console's own read-only dashboard endpoints (verified against its web client).
 * They are internal APIs, so keep their contract separate from legacy Go/Zen.
 */
export function consoleRequest(
  credential: Credential.OAuth,
  provider: "opencode-go" | "opencode-zen",
) {
  const server = new URL(
    typeof credential.metadata?.server === "string"
      ? credential.metadata.server
      : "https://opencode.ai/console",
  );
  if (
    !["https:", "http:"].includes(server.protocol) ||
    server.username ||
    server.password ||
    server.search ||
    server.hash
  ) {
    throw new Error("Invalid Console server");
  }
  const path =
    provider === "opencode-go" ? "/api/go/status" : "/api/billing/status";
  const headers: Record<string, string> = {
    Accept: "application/json",
    Authorization: `Bearer ${credential.access}`,
  };
  if (typeof credential.metadata?.orgID === "string")
    headers["x-org-id"] = credential.metadata.orgID;
  return {
    url: `${server.origin}${server.pathname.replace(/\/+$/, "")}${path}`,
    headers,
  };
}

export function parseConsoleGo(raw: unknown): ProviderSnapshot {
  const snapshot = base("opencode-go", "go");
  const data = record(raw);
  if (raw === null)
    return {
      ...snapshot,
      message: "No Go subscription in the selected Console workspace.",
    };
  const access = record(data?.access);
  if (!access)
    return {
      ...snapshot,
      message:
        data?.renewalPending === true
          ? "Go renewal is pending; no active paid access yet."
          : "No active Go access in the selected Console workspace.",
    };

  Object.assign(snapshot, parseGoMeters(access));
  if (snapshot.windows.length === 0)
    return {
      ...snapshot,
      message: "Console response contained no Go usage meters.",
    };
  snapshot.status = "ok";
  snapshot.plan = data?.product === "go-plus" ? "GO PLUS" : "GO";
  if (typeof data?.useBalance === "boolean")
    snapshot.extra.push(
      `use balance beyond limits: ${data.useBalance ? "on" : "off"}`,
    );
  if (data?.cancelAtPeriodEnd === true)
    snapshot.extra.push("cancels at the end of the paid period");
  if (data?.renewalPending === true) snapshot.extra.push("renewal pending");
  return snapshot;
}

function parseGoMeters(
  access: Record<string, unknown>,
): Pick<ProviderSnapshot, "windows" | "extra"> {
  const windows: ProviderSnapshot["windows"] = [];
  const extra: string[] = [];
  const meters = record(access.meters);
  for (const [key, id, label] of [
    ["fiveHour", "rolling", "5-hour rolling"],
    ["week", "weekly", "weekly"],
    ["month", "monthly", "monthly"],
  ] as const) {
    const meter = record(meters?.[key]);
    const limit = microcents(meter?.limitMicroCents);
    const used = microcents(meter?.usedMicroCents);
    if (limit === undefined || used === undefined || limit <= 0n || used < 0n)
      continue;
    const percentUsed = Number((used * 10_000n) / limit) / 100;
    if (!Number.isFinite(percentUsed)) continue;
    const reset = key === "month" ? access.endsAt : meter?.resetsAt;
    windows.push({
      id,
      label,
      percentUsed,
      ...(validDate(reset) ? { resetsAt: reset } : {}),
    });
    if (key === "fiveHour" && reset === null && used === 0n) {
      extra.push("5-hour window starts on first use");
    }
  }
  return { windows, extra };
}

export function parseConsoleBilling(raw: unknown): ProviderSnapshot {
  const snapshot = base("opencode-zen", "opencode");
  const data = record(raw);
  const balance = microcents(data?.balanceMicroCents);
  const available = microcents(data?.availableMicroCents);
  const creditLimit = microcents(data?.creditLimitMicroCents);
  if (balance === undefined || available === undefined) {
    return {
      ...snapshot,
      message: "Console response contained no billing balance.",
    };
  }
  snapshot.status = "ok";
  snapshot.plan = "CONSOLE";
  snapshot.extra.push(`credits balance: ${dollars(balance)}`);
  if (available !== balance)
    snapshot.extra.push(`available balance: ${dollars(available)}`);
  if (creditLimit !== undefined)
    snapshot.extra.push(`credit limit: ${dollars(creditLimit)}`);
  return snapshot;
}

function base(
  provider: "opencode-go" | "opencode-zen",
  displayName: string,
): ProviderSnapshot {
  return {
    provider,
    displayName,
    status: "unavailable",
    windows: [],
    extra: [],
    fetchedAt: new Date().toISOString(),
  };
}

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function microcents(value: unknown): bigint | undefined {
  if (typeof value === "string" && /^-?\d+$/.test(value)) return BigInt(value);
  if (typeof value === "number" && Number.isSafeInteger(value))
    return BigInt(value);
  return undefined;
}

function dollars(value: bigint): string {
  const abs = value < 0n ? -value : value;
  const cents = (abs + 500_000n) / 1_000_000n;
  return `${value < 0n ? "-" : ""}$${cents / 100n}.${String(cents % 100n).padStart(2, "0")}`;
}

function validDate(value: unknown): value is string {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}
