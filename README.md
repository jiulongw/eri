# Eri

A tiny macOS link router. Set Eri as your default web browser and it forwards every `http`/`https` link to the real browser you actually want — picked per-URL from a TOML config (host glob, host regex, or full-URL regex). Useful for sending work links to a Chrome work profile, GitHub to a Personal profile, localhost to Firefox, and everything else to Safari.

Eri does not render web pages itself. It is a one-shot agent app (no Dock icon, no window) that wakes up, picks a browser, calls `open(1)`, and exits. Launching Eri manually (with no URL) forwards to the configured default browser, so it behaves like a normal browser shortcut once it's set as the system default.

## Requirements

- macOS 12 or newer
- Swift 5.9+ toolchain (Xcode command line tools)
- [`pngquant`](https://pngquant.org/) on `PATH` for the icon build step (`brew install pngquant`)

## Build & install

```sh
make install   # builds build/Eri.app, copies to /Applications, registers with LaunchServices
```

Then open **System Settings → Desktop & Dock → Default web browser** and pick **Eri**.

Other useful targets:

```sh
make           # build build/Eri.app without installing
make register  # register the local build/Eri.app with LaunchServices (so it shows up in the picker)
make uninstall # remove /Applications/Eri.app
make clean     # wipe .build/ and build/
```

## Configure

Eri reads its config from one of:

- `~/.config/eri/config.toml` (preferred)
- `~/Library/Application Support/Eri/config.toml`

If neither exists on first launch, Eri scaffolds the preferred path with a minimal `[default] / browser = "com.apple.Safari"` so every link routes to Safari until you customize it.

A starter config lives at [`config.example.toml`](./config.example.toml):

```toml
[browsers.safari]
browser = "com.apple.Safari"

[browsers.chrome-personal]
browser = "com.google.Chrome"
profile = "Personal"

[browsers.chrome-work]
browser = "com.google.Chrome"
profile = "Work"

default = { browser = "safari" }

[[rule]]
host = "github.com"
browser = "chrome-personal"

[[rule]]
domain = "work.example.com"
browser = "chrome-work"

[[rule]]
domain = "notion.so"
browser = "chrome-personal"

# Inline form: `browser` is a bundle id, no [browsers] entry needed.
[[rule]]
url_regex = "^https?://localhost(:\\d+)?(/.*)?$"
browser = "org.mozilla.firefox"
```

Rules are evaluated top-to-bottom; first match wins. Each rule must match by exactly one of `host` (glob with `*`), `domain` (the value itself plus any subdomain of it), `host_regex`, or `url_regex`. If nothing matches, `default` is used; if `default` is omitted, Safari is used.

### Browsers

Define `(browser, profile, args)` triples once under `[browsers.<id>]` and reference them from rules:

```toml
[browsers.chrome-work]
browser = "com.google.Chrome"
profile = "Work"
args = ["--enable-features=Foo"]   # optional, applied wherever this id is used
```

A rule's `browser` field is looked up in `[browsers]` first. On a miss, it's treated as a bundle id (the inline form), and the rule's own `profile` / `args` apply. When using an id reference, rule-level `args` are appended after browser-level `args`; rule-level `profile` is ignored (the id already pins it).

### Fields

- `browser` — either an id from `[browsers]`, or a bundle id directly (`com.apple.Safari`, `com.google.Chrome`, `org.mozilla.firefox`, `com.microsoft.edgemac`, `com.brave.Browser`, ...).
- `profile` — passed as `--profile-directory=<value>`. Chromium-family browsers only; silently ignored for Safari (Safari has no CLI profile flag).
- `args` — extra command-line arguments appended to the target browser.

## How it works

1. macOS sends Eri a `GetURL` Apple Event for every clicked `http`/`https` link.
2. Eri loads the TOML config (auto-scaffolding a Safari default on first run), walks the rules, and resolves a `(browser, profile, args)` target.
3. Eri shells out to `/usr/bin/open -b <bundleId> [--args …] <url>` and exits.

When Eri is launched without a URL (e.g. clicking its Dock/Finder icon), it offers to set itself as the default browser, then launches the configured default browser with no URL.

Errors (config parse failure, scaffold write failure, `open` non-zero exit) are surfaced as macOS user notifications and logged via `os.log` under subsystem `cc.novacore.eri`.

## Project layout

```
Sources/Eri/
  main.swift                  NSApplication boot
  AppDelegate.swift           GetURL handler + lifecycle
  Config.swift                TOML schema, rule matching
  Router.swift                open(1) invocation
  DefaultBrowserPrompt.swift  manual-launch onboarding alert
  Notifier.swift              os.log + UNUserNotificationCenter wrapper
Resources/
  Info.plist                  declares http/https URL schemes, LSUIElement
  AppIcon.png
Makefile                      .app bundling, codesign, lsregister
Package.swift                 SwiftPM (depends on TOMLKit)
config.example.toml           starter config
```

## License

[MIT](./LICENSE) © Jiulong Wang

