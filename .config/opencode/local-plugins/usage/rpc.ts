import { Rpc } from "@opencode/plugin/rpc";

export type UsageInput = { refresh?: boolean };
export const usageInputSchema = {
  type: "object",
  properties: { refresh: { type: "boolean" } },
  additionalProperties: false,
} as const;

export const Usage = Rpc.define({
  id: "dotfiles.usage",
  events: {},
  methods: {
    check: {
      input: usageInputSchema,
      output: {
        type: "object",
        required: ["generatedAt", "providers"],
        properties: {
          generatedAt: { type: "string" },
          providers: {
            type: "array",
            items: {
              type: "object",
              required: ["provider", "displayName", "status", "windows", "extra", "fetchedAt"],
              properties: {
                provider: { enum: ["chatgpt", "opencode-go", "opencode-zen", "zai"] },
                displayName: { type: "string" },
                status: { enum: ["ok", "error", "unavailable"] },
                plan: { type: "string" },
                message: { type: "string" },
                fetchedAt: { type: "string" },
                extra: { type: "array", items: { type: "string" } },
                windows: {
                  type: "array",
                  items: {
                    type: "object",
                    required: ["id", "label", "percentUsed"],
                    properties: {
                      id: { type: "string" },
                      label: { type: "string" },
                      percentUsed: { type: "number" },
                      resetsAt: { type: ["number", "string"] },
                      windowSeconds: { type: "number" },
                      resetsInSeconds: { type: "number" },
                    },
                    additionalProperties: false,
                  },
                },
              },
              additionalProperties: false,
            },
          },
        },
        additionalProperties: false,
      },
    },
  },
});
