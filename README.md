# Eri

A tiny macOS link router. Set Eri as your default web browser and it forwards every `http`/`https` link to the real browser you actually want — picked per-URL from a TOML config (host glob, host regex, or full-URL regex). Useful for sending work links to a Chrome work profile, GitHub to a Personal profile, localhost to Firefox, and everything else to Safari.

Eri does not render web pages itself. It is a one-shot agent app (no Dock icon, no window) that wakes up, picks a browser, calls `open(1)`, and exits.

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

Drop a config at one of:

- `~/.config/eri/config.toml` (preferred)
- `~/Library/Application Support/Eri/config.toml`

A starter config lives at [`config.example.toml`](./config.example.toml):

```toml
default = { browser = "com.apple.Safari" }

[[rule]]
host = "github.com"
browser = "com.google.Chrome"
profile = "Default"

[[rule]]
host = "*.work.example.com"
browser = "com.google.Chrome"
profile = "Work"

[[rule]]
host_regex = "^(.+\\.)?notion\\.so$"
browser = "com.google.Chrome"
profile = "Personal"

[[rule]]
url_regex = "^https?://localhost(:\\d+)?(/.*)?$"
browser = "org.mozilla.firefox"
```

Rules are evaluated top-to-bottom; first match wins. Each rule must match by exactly one of `host` (glob with `*`), `host_regex`, or `url_regex`. If nothing matches, `default` is used; if `default` is omitted, Safari is used.

### Fields

- `browser` — bundle id of the target app, e.g. `com.apple.Safari`, `com.google.Chrome`, `org.mozilla.firefox`, `com.microsoft.edgemac`, `com.brave.Browser`.
- `profile` — passed as `--profile-directory=<value>`. Chromium-family browsers only; silently ignored for Safari (Safari has no CLI profile flag).
- `args` — extra command-line arguments appended to the target browser.

## How it works

1. macOS sends Eri a `GetURL` Apple Event for every clicked `http`/`https` link.
2. Eri loads the TOML config, walks the rules, and resolves a `(browser, profile, args)` target.
3. Eri shells out to `/usr/bin/open -b <bundleId> [--args …] <url>` and exits.

Errors (missing config, parse failure, `open` non-zero exit) are surfaced as macOS user notifications and logged via `os.log` under subsystem `cc.novacore.eri`.

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

