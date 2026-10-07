import { createHash } from "node:crypto";
import type { Credential } from "@opencode/plugin";
import {
  PROVIDERS,
  createUsageRequest,
  resolveSource,
  httpError,
  type Connections,
  type Provider,
  type Source,
} from "./providers.ts";
import {
  resolveResetDate,
  type ProviderId,
  type ProviderSnapshot,
  type UsageSnapshot,
  type UsageWindow,
} from "./shared.ts";

const CACHE_TTL_MS = 60_000;
type CacheEntry = {
  identity: string;
  order: number;
  at: number;
  value?: ProviderSnapshot;
};

/** Only the host's resolved credential is used. OpenCode owns OAuth refresh. */
export function createCollector(
  connections: Connections,
  dependencies: {
    fetch?: typeof fetch;
    now?: () => number;
    integrationID?: (providerID: string) => Promise<string | undefined>;
  } = {},
) {
  const request = dependencies.fetch ?? fetch;
  const now = dependencies.now ?? Date.now;
  // Fingerprints handle hosts that clone resolved credentials. Keep only one
  // entry per provider; switching accounts cannot return the previous quota.
  const cache = new Map<ProviderId, CacheEntry>();
  let order = 0;

  function unavailable(provider: Provider, message: string): ProviderSnapshot {
    return {
      provider: provider.id,
      displayName: provider.name,
      status: "unavailable",
      message,
      windows: [],
      extra: [],
      fetchedAt: new Date(now()).toISOString(),
    };
  }

  async function fetchSnapshot(
    provider: Provider,
    source: Source,
    signal?: AbortSignal,
  ): Promise<ProviderSnapshot> {
    const usage = createUsageRequest(provider, source);
    if ("message" in usage) return unavailable(provider, usage.message);
    const timeout = AbortSignal.timeout(15_000);
    const response = await request(usage.url, {
      headers: usage.headers,
      redirect: "error",
      signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
    });
    if (!response.ok) {
      await response.body?.cancel();
      return unavailable(provider, httpError(provider, source, usage, response.status));
    }
    const parsed = usage.parse(await response.json());
    if (!parsed || (parsed.status === "ok" && !parsed.windows.length && !parsed.extra.length)) {
      return unavailable(provider, "Usage response contained no window data.");
    }
    const at = now();
    const value = {
      ...parsed,
      windows: parsed.windows.map((window) => normalizeReset(window, at)),
      fetchedAt: new Date(at).toISOString(),
    };
    return sanitize(value, source.credential, usage.headers["ChatGPT-Account-Id"]);
  }

  async function collect(
    provider: Provider,
    force: boolean,
    signal?: AbortSignal,
  ) {
    const requestOrder = ++order;
    try {
      signal?.throwIfAborted();
      const selected = await resolveSource(provider, connections, dependencies.integrationID);
      signal?.throwIfAborted();
      if (!selected)
        return unavailable(
          provider,
          `Connect ${provider.integrations.join(" or ")} in OpenCode to check usage.`,
        );
      const identity = createHash("sha256")
        .update(JSON.stringify(selected))
        .digest("hex");
      const cached = cache.get(provider.id);
      if (
        !force && cached?.identity === identity && cached.value &&
        now() - cached.at < CACHE_TTL_MS
      )
        return cached.value;

      // Request order is assigned before resolving credentials, since resolution
      // can finish out of order too. Only the newest request may publish a result.
      const entry: CacheEntry = { identity, order: requestOrder, at: now() };
      if (!cached || cached.order < requestOrder) cache.set(provider.id, entry);
      const value = await fetchSnapshot(provider, selected, signal);
      signal?.throwIfAborted();
      if (cache.get(provider.id) === entry) {
        entry.value = value;
        entry.at = now();
      }
      return value;
    } catch {
      signal?.throwIfAborted();
      // Exception messages can contain headers/bodies; expose only a fixed note.
      return unavailable(
        provider,
        "Unable to read usage (connection, timeout, or invalid response). Try /usage refresh.",
      );
    }
  }

  return async (
    force = false,
    signal?: AbortSignal,
  ): Promise<UsageSnapshot> => ({
    generatedAt: new Date(now()).toISOString(),
    providers: await Promise.all(
      PROVIDERS.map((provider) => collect(provider, force, signal)),
    ),
  });
}

function normalizeReset(window: UsageWindow, at: number): UsageWindow {
  const { resetsAt, resetsInSeconds, ...rest } = window;
  const reset = resolveResetDate(window, at);
  return reset ? { ...rest, resetsAt: reset.getTime() } : rest;
}

/** Do not reflect credentials or control sequences echoed by upstream APIs. */
function sanitize(
  value: ProviderSnapshot,
  credential: Credential.Value,
  accountID?: string,
): ProviderSnapshot {
  const secrets =
    credential.type === "key"
      ? [credential.key]
      : [credential.access, credential.refresh, accountID];
  return JSON.parse(
    JSON.stringify(value, (_key, item: unknown) => {
      if (typeof item !== "string") return item;
      for (const secret of secrets)
        if (secret) item = (item as string).replaceAll(secret, "[redacted]");
      return (item as string).replace(/[\x00-\x1f\x7f-\x9f]/g, "");
    }),
  );
}
