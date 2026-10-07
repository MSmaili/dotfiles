import { Plugin, usePlugin } from "@opencode/plugin/tui";
import { For, Show, createSignal, onCleanup, onMount } from "solid-js";
import { Usage } from "./rpc.ts";
import {
  formatClock,
  formatResetsIn,
  formatWindowLabel,
  remainingPercent,
  type ProviderSnapshot,
  type UsageSnapshot,
} from "./shared.ts";

export default Plugin.define({
  id: "dotfiles.usage.tui",
  setup(ctx) {
    // Keymap registration needs the mounted host's Keymap.Provider.
    return ctx.ui.slot({ append: "app", render: () => <UsageCommands /> });
  },
});

function UsageCommands() {
  const ctx = usePlugin();
  ctx.keymap.layer(() => ({
    mode: "global",
    commands: [
      {
        id: "dotfiles.usage.show",
        title: "Show provider usage & credits",
        group: "Usage",
        palette: true,
        slash: { name: "usage", arguments: true },
        run(input) {
          const args = (input ?? "")
            .trim()
            .toLowerCase()
            .split(/\s+/)
            .filter(Boolean);
          if (args.some((arg) => !["refresh", "json"].includes(arg))) {
            ctx.ui.toast.show({
              message: "Usage: /usage [refresh] [json]",
              variant: "info",
            });
            return;
          }
          ctx.ui.dialog.show(() => (
            <Dashboard
              refresh={args.includes("refresh")}
              json={args.includes("json")}
            />
          ));
          ctx.ui.dialog.set({ size: "large", centered: true });
        },
      },
    ],
  }));
  return null;
}

function Dashboard(props: { refresh: boolean; json: boolean }) {
  const ctx = usePlugin();
  const rpc = ctx.client.rpc(Usage);
  const [snapshot, setSnapshot] = createSignal<UsageSnapshot>();
  const [loading, setLoading] = createSignal(false);
  const [error, setError] = createSignal("");
  const controller = new AbortController();
  const location = ctx.location ?? ctx.data.location.default();
  onCleanup(() => controller.abort());

  async function load(refresh: boolean) {
    if (loading()) return;
    setLoading(true);
    setError("");
    try {
      const result = await rpc.check(
        { refresh },
        { location, signal: controller.signal },
      );
      if (!controller.signal.aborted) setSnapshot(result as UsageSnapshot);
    } catch {
      if (!controller.signal.aborted)
        setError(
          "Cannot reach the usage plugin. Check that it is enabled on the connected server, then press r.",
        );
    } finally {
      if (!controller.signal.aborted) setLoading(false);
    }
  }
  onMount(() => void load(props.refresh));
  ctx.keymap.layer(() => ({
    mode: "global",
    priority: 100,
    commands: [
      { bind: "r", run: () => load(true) },
      { bind: "q", run: () => ctx.ui.dialog.clear() },
      { bind: "escape", run: () => ctx.ui.dialog.clear() },
      { bind: "return", run: () => ctx.ui.dialog.clear() },
    ],
  }));

  return (
    <box flexDirection="column" paddingX={2} paddingY={1} gap={1}>
      <text fg={ctx.theme.text.base}>
        <b>usage · provider usage &amp; credits</b>
      </text>
      <Show when={loading()}>
        <text fg={ctx.theme.text.muted}>Checking accounts…</text>
      </Show>
      <Show when={error()}>
        <text fg={ctx.theme.text.feedback.error.base}>{error()}</text>
      </Show>
      <Show when={snapshot()}>
        {(value) => <SnapshotView snapshot={value()} json={props.json} />}
      </Show>
      <text fg={ctx.theme.text.muted}>
        r refresh · esc / enter / q close · 60s cache
      </text>
    </box>
  );
}

function SnapshotView(props: { snapshot: UsageSnapshot; json: boolean }) {
  const ctx = usePlugin();
  return (
    <scrollbox maxHeight={Math.max(5, ctx.renderer.height - 12)} focused>
      <Show
        when={!props.json}
        fallback={<text fg={ctx.theme.text.base}>{JSON.stringify(props.snapshot, null, 2)}</text>}
      >
        <For each={props.snapshot.providers}>
          {(provider) => <ProviderUsage provider={provider} />}
        </For>
      </Show>
    </scrollbox>
  );
}

function ProviderUsage(props: { provider: ProviderSnapshot }) {
  const ctx = usePlugin();
  const color = (remaining: number) => ctx.theme.text.feedback[
    remaining >= 40 ? "success" : remaining >= 20 ? "warning" : "error"
  ].base;
  return (
    <box flexDirection="column" marginBottom={1} gap={0}>
      <text fg={ctx.theme.text.base}>
        <b>{props.provider.displayName}{props.provider.plan ? ` · ${props.provider.plan}` : ""}</b>
        {`  · ${props.provider.status} · ${formatClock(props.provider.fetchedAt)}`}
      </text>
      <Show when={props.provider.message}>
        <text fg={ctx.theme.text.muted}>{props.provider.message}</text>
      </Show>
      <For each={props.provider.windows}>
        {(window) => {
          const left = remainingPercent(window);
          const filled = Math.round((left / 100) * 12);
          return (
            <text fg={color(left)}>
              {`${formatWindowLabel(window).padEnd(14)} ${"█".repeat(filled)}${"░".repeat(12 - filled)} ${left}% left · ${formatResetsIn(window)}`}
            </text>
          );
        }}
      </For>
      <For each={props.provider.extra}>
        {(line) => <text fg={ctx.theme.text.muted}>{line}</text>}
      </For>
    </box>
  );
}
