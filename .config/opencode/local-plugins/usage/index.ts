import { Plugin } from "@opencode/plugin";
import { createCollector } from "./collector.ts";
import { Usage, usageInputSchema, type UsageInput } from "./rpc.ts";
import { formatSummaryText } from "./shared.ts";

export default Plugin.define({
  id: "dotfiles.usage",
  async setup(ctx) {
    const collect = createCollector(ctx.integration.connection, {
      integrationID: async (providerID) =>
        (await ctx.provider.get({ providerID })).data.integrationID,
    });
    const check = (input: unknown, context: { signal: AbortSignal }) =>
      collect((input as UsageInput).refresh, context.signal);
    await ctx.rpc.register(Usage, { check });
    await ctx.tool.transform((editor) => {
      editor.add({
        name: "usage_check",
        description: "Check remaining provider quotas and credits for ChatGPT, OpenCode Go/Zen, and z.ai. Returns percentages and reset times; refresh bypasses the 60-second cache.",
        input: usageInputSchema,
        async execute(input, context) {
          return { content: formatSummaryText(await check(input, context)) };
        },
      });
    });
  },
});
