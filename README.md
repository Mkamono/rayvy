# Rayvy

Lightweight macOS launcher. `⌥Space` → Command Palette → apps, clipboard history, system actions.

See [`SPEC.md`](SPEC.md) for the full design and config format.

## Install

Via [mise](https://mise.jdx.dev):

```bash
cp mise.example.toml mise.toml   # or merge the [bootstrap.packages] entry into your own
mise bootstrap
```

Or download `Rayvy-<version>-arm64.zip` from [Releases](https://github.com/Mkamono/rayvy/releases).

## Config

`~/.config/rayvy/config.toml`, created with defaults on first run. Hot-reloaded on save — see `SPEC.md` for the format.
