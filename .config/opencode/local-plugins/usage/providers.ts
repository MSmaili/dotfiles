import type { Credential } from "@opencode/plugin";
import type { IntegrationDomain } from "@opencode/plugin/promise/integration";
import { consoleRequest, parseConsoleGo, parseConsoleBilling } from "./console.ts";
import {
  parseWham,
  parseOpencodeUsage,
  parseQuotaLimit,
  type ProviderId,
  type ProviderSnapshot,
} from "./shared.ts";

export type Connections = IntegrationDomain["connection"];
export type Source = { integrationID: string; credential: Credential.Value };
export type Provider = {
  id: ProviderId;
  name: string;
  integrations: string[];
};
export type UsageRequest = {
  url: string;
  headers: Record<string, string>;
  parse: (raw: unknown) => Omit<ProviderSnapshot, "fetchedAt"> | undefined;
  console?: boolean;
};

export const PROVIDERS: Provider[] = [
  { id: "chatgpt", name: "chatgpt", integrations: ["openai"] },
  { id: "opencode-go", name: "go", integrations: ["opencode-go"] },
  { id: "opencode-zen", name: "zen", integrations: ["opencode"] },
  { id: "zai", name: "z.ai", integrations: ["zhipuai-coding-plan", "zai-coding-plan"] },
];

export async function resolveSource(
  provider: Provider,
  connections: Connections,
  integrationID?: (providerID: string) => Promise<string | undefined>,
): Promise<Source | undefined> {
  // Console can remap Go to its shared connection. Do not use another saved account.
  const integrations =
    provider.id === "opencode-go" && integrationID
      ? [(await integrationID(provider.id)) ?? "opencode-go"]
      : provider.integrations;
  for (const integrationID of integrations) {
    const connection = await connections.active(integrationID);
    if (!connection) continue;
    const credential = await connections.resolve(connection);
    if (credential) return { integrationID, credential };
  }
}

export function createUsageRequest(
  provider: Provider,
  source: Source,
): UsageRequest | { message: string } {
  const { credential, integrationID } = source;
  if (
    integrationID === "opencode" &&
    credential.type === "oauth" &&
    (provider.id === "opencode-go" || provider.id === "opencode-zen")
  ) {
    return {
      ...consoleRequest(credential, provider.id),
      parse: provider.id === "opencode-go" ? parseConsoleGo : parseConsoleBilling,
      console: true,
    };
  }
  if (provider.id === "chatgpt") return chatgptRequest(credential);
  if (credential.type !== "key") {
    return { message: "Usage requires an API-key connection for this provider." };
  }
  return keyRequest(provider.id, integrationID, credential.key);
}

function chatgptRequest(credential: Credential.Value): UsageRequest | { message: string } {
  if (credential.type !== "oauth") {
    return { message: "Select a ChatGPT OAuth connection for OpenAI; API keys do not expose plan quotas." };
  }
  const accountID = chatgptAccountID(credential);
  if (!accountID) {
    return { message: "ChatGPT account ID missing. Reconnect OpenAI in OpenCode." };
  }
  return {
    url: "https://chatgpt.com/backend-api/wham/usage",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${credential.access}`,
      "ChatGPT-Account-Id": accountID,
    },
    parse: parseWham,
  };
}

function keyRequest(
  providerID: Exclude<ProviderId, "chatgpt">,
  integrationID: string,
  key: string,
): UsageRequest {
  const urls = {
    "opencode-go": "https://opencode.ai/zen/go/v1/usage",
    "opencode-zen": "https://opencode.ai/zen/v1/usage",
    zai: integrationID === "zhipuai-coding-plan"
      ? "https://open.bigmodel.cn/api/monitor/usage/quota/limit"
      : "https://api.z.ai/api/monitor/usage/quota/limit",
  };
  return {
    url: urls[providerID],
    headers: { Accept: "application/json", Authorization: `Bearer ${key}` },
    parse: providerID === "zai" ? parseQuotaLimit : (raw) => parseOpencodeUsage(raw, providerID),
  };
}

export function httpError(
  provider: Provider,
  source: Source,
  request: UsageRequest,
  status: number,
): string {
  if (request.console) {
    if (status === 403)
      return "Console denied usage access for this workspace. Check your workspace role in Console.";
    if (status === 404) return "Console usage endpoint is unavailable on this server.";
  }
  if (provider.id === "opencode-zen" && status === 404)
    return "No public balance API. Check the OpenCode Zen dashboard.";
  if (status === 401 || status === 403)
    return `Authorization rejected (HTTP ${status}). Reconnect ${source.integrationID} in OpenCode.`;
  return `Usage endpoint returned HTTP ${status}.`;
}

export function chatgptAccountID(credential: Credential.Value): string | undefined {
  if (credential.type !== "oauth") return;
  const metadata = credential.metadata?.accountId;
  if (typeof metadata === "string" && metadata) return metadata;
  try {
    const claims = JSON.parse(Buffer.from(credential.access.split(".")[1] ?? "", "base64url").toString());
    const id = claims["https://api.openai.com/auth"]?.chatgpt_account_id;
    return typeof id === "string" && id ? id : undefined;
  } catch {
    return undefined;
  }
}
