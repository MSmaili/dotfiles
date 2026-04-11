package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

func main() {
	if len(os.Args) < 2 {
		fail("usage: fzp-yaml-parser <catalog|load> ...")
	}

	switch os.Args[1] {
	case "catalog":
		if len(os.Args) != 3 {
			fail("usage: fzp-yaml-parser catalog <channels_dir>")
		}
		out, err := buildCatalog(os.Args[2])
		if err != nil {
			fail(err.Error())
		}
		emitJSON(out)
	case "load":
		if len(os.Args) != 5 {
			fail("usage: fzp-yaml-parser load <channel> <channels_dir> <default_height>")
		}
		out, err := loadChannel(os.Args[2], os.Args[3], os.Args[4])
		if err != nil {
			fail(err.Error())
		}
		emitJSON(out)
	default:
		fail("unknown command: " + os.Args[1])
	}
}

func fail(msg string) {
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
}

func emitJSON(v any) {
	enc := json.NewEncoder(os.Stdout)
	if err := enc.Encode(v); err != nil {
		fail(err.Error())
	}
}

func buildCatalog(dir string) ([]map[string]string, error) {
	if stat, err := os.Stat(dir); err != nil || !stat.IsDir() {
		return nil, errors.New("missing channels dir")
	}

	entries := map[string]string{}

	fileMatches, _ := filepath.Glob(filepath.Join(dir, "*.yaml"))
	sort.Strings(fileMatches)
	for _, path := range fileMatches {
		name := strings.TrimSuffix(filepath.Base(path), ".yaml")
		if _, ok := entries[name]; !ok {
			entries[name] = path
		}
	}

	bundleMatches, _ := filepath.Glob(filepath.Join(dir, "*", "main.yaml"))
	sort.Strings(bundleMatches)
	for _, path := range bundleMatches {
		name := filepath.Base(filepath.Dir(path))
		entries[name] = path
	}

	names := make([]string, 0, len(entries))
	for name := range entries {
		names = append(names, name)
	}
	sort.Strings(names)

	out := make([]map[string]string, 0, len(names))
	for _, name := range names {
		path := entries[name]
		raw, err := parseYAML(path)
		if err != nil {
			return nil, err
		}
		meta := toMap(raw["metadata"])
		out = append(out, map[string]string{
			"name":        name,
			"description": toString(meta["description"]),
			"path":        path,
		})
	}

	return out, nil
}

func loadChannel(channel, dir, defaultHeight string) (map[string]any, error) {
	fileCandidate := filepath.Join(dir, channel+".yaml")
	bundleCandidate := filepath.Join(dir, channel, "main.yaml")

	path := ""
	if fileExists(bundleCandidate) {
		path = bundleCandidate
	} else if fileExists(fileCandidate) {
		path = fileCandidate
	}

	if path == "" {
		return nil, fmt.Errorf("channel not found: %s", channel)
	}

	raw, err := parseYAML(path)
	if err != nil {
		return nil, err
	}

	channelDir := filepath.Dir(path)
	meta := toMap(raw["metadata"])
	source := toMap(raw["source"])
	preview := toMap(raw["preview"])
	ui := toMap(raw["ui"])
	navigation := toMap(raw["navigation"])
	actions := toMap(raw["actions"])

	requires := toStringSlice(meta["requires"])

	sourceType := toStringDefault(source["type"], "command")
	sourceCommand := toString(source["command"])
	if sourceType == "script" || hasKey(source, "script") {
		scriptRef := firstNonEmpty(toString(source["script"]), sourceCommand)
		scriptPath := absPath(scriptRef, channelDir)
		scriptArgs := toString(source["args"])
		sourceCommand = shellEscape(scriptPath)
		if scriptArgs != "" {
			sourceCommand += " " + scriptArgs
		}
		sourceType = "script"
	}

	previewCommand := toString(preview["command"])
	if toString(preview["type"]) == "script" || hasKey(preview, "script") {
		scriptPath := absPath(toString(preview["script"]), channelDir)
		scriptArgs := toStringDefault(preview["args"], "{}")
		previewCommand = shellEscape(scriptPath) + " " + scriptArgs
	}
	if previewCommand == "" {
		previewCommand = "echo {}"
	}

	navItems := []map[string]string{}
	navKeys := sortedKeys(navigation)
	for _, key := range navKeys {
		value := navigation[key]
		target := ""
		label := ""

		if vm := toMap(value); len(vm) > 0 {
			target = firstNonEmpty(toString(vm["channel"]), toString(vm["target"]))
			label = firstNonEmpty(toString(vm["label"]), target)
		} else {
			target = toString(value)
			label = target
		}

		if key == "" || target == "" {
			continue
		}

		navItems = append(navItems, map[string]string{
			"key":    key,
			"target": target,
			"label":  label,
		})
	}

	actionItems := []map[string]any{}
	actionKeys := sortedKeys(actions)
	for _, key := range actionKeys {
		value := actions[key]
		cfg := toMap(value)
		if len(cfg) == 0 {
			cfg = map[string]any{"command": toString(value)}
		}

		mode := toStringDefault(cfg["mode"], "execute")
		label := firstNonEmpty(toString(cfg["label"]), toString(cfg["description"]), key)
		command := toString(cfg["command"])

		if hasKey(cfg, "script") {
			scriptPath := absPath(toString(cfg["script"]), channelDir)
			scriptArgs := toStringDefault(cfg["args"], "{}")
			command = shellEscape(scriptPath) + " " + scriptArgs
		}

		actionItems = append(actionItems, map[string]any{
			"key":             key,
			"mode":            mode,
			"label":           label,
			"command":         command,
			"target":          toString(cfg["target"]),
			"field":           toString(cfg["field"]),
			"confirm":         toBool(cfg["confirm"]),
			"confirm_message": toStringDefault(cfg["confirm_message"], "Run "+label+"?"),
		})
	}

	out := map[string]any{
		"name":        channel,
		"path":        path,
		"dir":         channelDir,
		"description": toString(meta["description"]),
		"requires":    requires,
		"prompt":      toStringDefault(ui["prompt"], "["+channel+"]> "),
		"header":      toString(ui["header"]),
		"height":      toStringDefault(ui["height"], defaultHeight),
		"multi":       toBoolDefault(ui["multi"], true),
		"source": map[string]any{
			"type":      sourceType,
			"command":   sourceCommand,
			"delimiter": toString(source["delimiter"]),
			"ansi":      toBool(source["ansi"]),
			"no_sort":   toBool(source["no_sort"]),
			"cwd":       absPathMaybe(toString(source["cwd"]), channelDir),
			"env":       toMap(source["env"]),
		},
		"preview": map[string]any{
			"command": previewCommand,
			"window":  toStringDefault(preview["window"], "right:50%"),
		},
		"navigation":  navItems,
		"actions":     actionItems,
		"fzf_options": toStringSlice(raw["fzf_options"]),
	}

	return out, nil
}

func parseYAML(path string) (map[string]any, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var raw any
	if err := yaml.Unmarshal(b, &raw); err != nil {
		return nil, err
	}

	norm := normalize(raw)
	m := toMap(norm)
	if m == nil {
		m = map[string]any{}
	}
	return m, nil
}

func normalize(v any) any {
	switch x := v.(type) {
	case map[string]any:
		out := make(map[string]any, len(x))
		for k, vv := range x {
			out[k] = normalize(vv)
		}
		return out
	case map[any]any:
		out := make(map[string]any, len(x))
		for k, vv := range x {
			out[fmt.Sprint(k)] = normalize(vv)
		}
		return out
	case []any:
		out := make([]any, 0, len(x))
		for _, item := range x {
			out = append(out, normalize(item))
		}
		return out
	default:
		return x
	}
}

func toMap(v any) map[string]any {
	if v == nil {
		return map[string]any{}
	}
	m, ok := v.(map[string]any)
	if !ok {
		return map[string]any{}
	}
	return m
}

func toString(v any) string {
	if v == nil {
		return ""
	}
	switch x := v.(type) {
	case string:
		return x
	case []byte:
		return string(x)
	default:
		return fmt.Sprint(x)
	}
}

func toStringDefault(v any, def string) string {
	s := toString(v)
	if s == "" {
		return def
	}
	return s
}

func toStringSlice(v any) []string {
	if v == nil {
		return []string{}
	}
	switch x := v.(type) {
	case []any:
		out := make([]string, 0, len(x))
		for _, item := range x {
			s := toString(item)
			if s != "" {
				out = append(out, s)
			}
		}
		return out
	case []string:
		out := make([]string, 0, len(x))
		for _, item := range x {
			if item != "" {
				out = append(out, item)
			}
		}
		return out
	default:
		s := toString(v)
		if s == "" {
			return []string{}
		}
		return []string{s}
	}
}

func toBool(v any) bool {
	switch x := v.(type) {
	case bool:
		return x
	case string:
		b, err := strconv.ParseBool(strings.TrimSpace(x))
		return err == nil && b
	default:
		return false
	}
}

func toBoolDefault(v any, def bool) bool {
	if v == nil {
		return def
	}
	switch x := v.(type) {
	case bool:
		return x
	case string:
		b, err := strconv.ParseBool(strings.TrimSpace(x))
		if err != nil {
			return def
		}
		return b
	default:
		return def
	}
}

func hasKey(m map[string]any, key string) bool {
	_, ok := m[key]
	return ok
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func sortedKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func absPath(value, base string) string {
	if value == "" {
		return ""
	}
	if filepath.IsAbs(value) {
		return value
	}
	return filepath.Clean(filepath.Join(base, value))
}

func absPathMaybe(value, base string) string {
	if value == "" {
		return ""
	}
	return absPath(value, base)
}

func shellEscape(s string) string {
	if s == "" {
		return "''"
	}
	return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'"
}

func fileExists(path string) bool {
	stat, err := os.Stat(path)
	if err != nil {
		return false
	}
	return !stat.IsDir()
}
