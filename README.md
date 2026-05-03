# Eri

A tiny macOS link router. Set Eri as your default web browser and it forwards every `http`/`https` link to the real browser you actually want — picked per-URL from a TOML config (host glob, host regex, full-URL regex, or `domain` match).

Eri does not render web pages itself. It is a one-shot agent app (no Dock icon, no menu bar, no preferences window) that wakes up, picks a browser, calls `open(1)`, and exits in well under a second. Launching Eri manually (with no URL) forwards to the configured default browser, so it behaves like a normal browser shortcut once it's set as the system default.

> **About the name.** *Eri* (えり / 選) is a Japanese given name that also carries the meaning *to select, to pick* — which is, more or less, the entire job description.

## Why Eri

If you keep your dotfiles in a git repo and rsync/`stow`/`chezmoi` them across machines, the existing macOS link routers tend to get in the way:

- **No UI, no preferences pane.** Every behavior change is an edit to one TOML file. There is no settings window with state hidden in `~/Library/Preferences/<bundle id>.plist` that has to be re-clicked on every fresh machine.
- **Fully config driven.** A single `~/.config/eri/config.toml` is the entire surface area — browser map, default, rules. Diffable, reviewable, greppable.
- **Trivially version-controlled.** The config lives at `~/.config/eri/config.toml` (XDG-style) by default, so it drops straight into the same dotfiles repo you already manage. Commit it, sync it, and a new Mac is one `make install` + `stow` away from your full routing setup.
- **No analytics, no auto-update, no account.** Eri is ~600 lines of Swift around `/usr/bin/open`. The whole process exits in ~½ second per click — there is nothing resident to phone home.

Compared to the alternatives:

| | Eri | Velja / Choosy / Browserosaurus | Finicky |
| --- | --- | --- | --- |
| UI surface | none | menu-bar app + prefs window | menu-bar icon (hideable) + config/diagnostics window |
| Config format | TOML file | GUI (plist-backed) | JavaScript file |
| Git-syncable across machines | yes, single text file | partial — GUI state | yes |
| Runtime model | one-shot, exits per click | resident agent | resident agent |
| External dependencies | none (vendored toml++) | — | embedded JS engine |
| Bundle size | ~2 MB | ~10–110 MB (Browserosaurus is Electron) | ~30 MB |

If you want a popup picker every time you click a link, Eri is the wrong tool — use Velja or Choosy. If you want declarative, file-based routing that survives a clean macOS install by `git pull`-ing your dotfiles, that's the niche Eri is built for.

## Requirements

- macOS 12 or newer
- Swift 5.9+ toolchain (Xcode command line tools)
- [`pngquant`](https://pngquant.org/) on `PATH` for the icon build step (`brew install pngquant`)

## Build & install

```sh
make install   # builds build/Eri.app, copies to /Applications, registers with LaunchServices
```

Then open **System Settings → Desktop & Dock → Default web browser** and pick **Eri**. (Eri will also offer to do this for you the first time you launch it manually.)

Other useful targets:

```sh
make           # build build/Eri.app without installing
make register  # register the local build/Eri.app with LaunchServices (so it shows up in the picker)
make uninstall # remove /Applications/Eri.app
make clean     # wipe .build/ and build/
```

`swift build` alone is not enough — Eri needs to be a proper `.app` bundle with `Info.plist` declaring `CFBundleURLTypes` for `http`/`https` and registered with LaunchServices before macOS will list it as a default-browser candidate. Use the Makefile.

## Configure

Eri reads its config from one of:

- `~/.config/eri/config.toml` (preferred)
- `~/Library/Application Support/Eri/config.toml`

First hit wins. If neither exists on first launch, Eri scaffolds the preferred path with a minimal `[default]` block routing everything to Safari, so things keep working until you customize them.

A starter config lives at [`config.example.toml`](./config.example.toml):

```toml
# Fallback when no rule matches.
[default]
browser = "safari"

[browsers.safari]
browser = "com.apple.Safari"

[browsers.chrome-personal]
browser = "com.google.Chrome"
profile = "Personal"

[browsers.chrome-work]
browser = "com.google.Chrome"
profile = "Work"

# Rules are evaluated top-to-bottom; first match wins.
[[rule]]
host = "github.com"
browser = "chrome-personal"

[[rule]]
domain = "work.example.com"
browser = "chrome-work"

[[rule]]
domain = "notion.so"
browser = "chrome-personal"

# Inline form: `browser` is a bundle id directly, no [browsers] entry needed.
[[rule]]
url_regex = "^https?://localhost(:\\d+)?(/.*)?$"
browser = "org.mozilla.firefox"
```

### Rule matching

Rules are evaluated top-to-bottom; first match wins. Each rule must match by **exactly one** of:

- `host` — glob with `*` (e.g. `*.github.io`), case-insensitive, anchored.
- `domain` — value itself plus any subdomain of it. `domain = "google.com"` matches `google.com` and `mail.google.com` but not `evilgoogle.com`.
- `host_regex` — `NSRegularExpression` against the URL host.
- `url_regex` — `NSRegularExpression` against the full URL string. Checked before host-based predicates, so it wins if both could match.

If no rule matches, `[default]` is used. If `[default]` is omitted, Eri falls back to Safari.

### Browsers

Define `(browser, profile, args)` triples once under `[browsers.<id>]` and reference them from rules:

```toml
[browsers.chrome-work]
browser = "com.google.Chrome"
profile = "Work"
args = ["--enable-features=Foo"]   # optional, applied wherever this id is used
```

A rule's `browser` field is looked up in `[browsers]` first. On a miss it is treated as a bundle id (the inline form), and the rule's own `profile` / `args` apply. When using an id reference, rule-level `args` are appended after browser-level `args`; rule-level `profile` is ignored (the id already pins it).

### Fields

- `browser` — either an id from `[browsers]`, or a bundle id directly (`com.apple.Safari`, `com.google.Chrome`, `org.mozilla.firefox`, `com.microsoft.edgemac`, `com.brave.Browser`, …).
- `profile` — passed as `--profile-directory=<value>`. Chromium-family browsers only; silently ignored for Safari (Safari has no CLI profile flag).
- `args` — extra command-line arguments appended to the target browser.

### Chrome profiles

Chrome's `--profile-directory=` flag expects an internal directory name (`Default`, `Profile 1`, `Profile 2`, …), which is awkward to write into a config you'll re-read months from now. Eri reads `~/Library/Application Support/Google/Chrome/Local State` and resolves the `profile` you supply against three keys, in order:

1. The directory name itself (`Profile 1`).
2. The signed-in account email (`user_name`, e.g. `you@example.com`).
3. The user-facing display name (`name`, e.g. `Personal`).

So `profile = "Personal"` or `profile = "you@gmail.com"` both work and survive Chrome shuffling its directory numbers around. If nothing matches, Eri omits the flag and lets Chrome fall back to its default profile.

## How it works

1. macOS sends Eri a `GetURL` Apple Event for every clicked `http`/`https` link.
2. Eri loads the TOML config (auto-scaffolding a Safari default on first run), walks the rules, and resolves a `(browser, profile, args)` target.
3. Eri shells out to `/usr/bin/open -b <bundleId> [-n --args …] <url>` and exits.

When Eri is launched without a URL (e.g. clicking its Finder icon or `open -a Eri`), it offers to set itself as the default browser, then forwards to the configured default browser with no URL — so the Finder icon behaves like a normal browser shortcut.

Errors (config parse failure, scaffold write failure, `open` non-zero exit) are surfaced as macOS user notifications and logged via `os.log` under subsystem `cc.novacore.eri`.

### Implementation notes

- **One-shot lifecycle.** `applicationWillFinishLaunching` registers the `GetURL` handler before `applicationDidFinishLaunching` fires. If a URL arrived, it has already been routed by then; otherwise a 0.2 s timer treats the launch as manual. Either path ends with a 0.4 s grace period (to let any pending `UNNotificationRequest` flush) before `NSApp.terminate`. Total wall time per click is well under a second.
- **`-n` is required when extra args are passed.** Without it, `open` silently drops `--args` if the target browser is already running, taking the URL with it. Chromium's single-instance handler IPCs the args to the existing process, so `-n` does not leave a duplicate window behind.
- **No long-lived state.** Don't add background work or caches — the process is gone within ~½ second.

## Project layout

```
Sources/Eri/
  main.swift                  NSApplication boot
  AppDelegate.swift           GetURL handler + lifecycle
  Config.swift                TOML schema, rule matching
  TomlDecoder.swift           Swift wrapper over the C ABI; manual Config decoder
  Router.swift                open(1) invocation
  ChromeProfileResolver.swift directory / user_name / display-name lookup
  DefaultBrowserPrompt.swift  manual-launch onboarding alert
  Notifier.swift              os.log + UNUserNotificationCenter wrapper
Sources/CTomlPlusPlus/
  include/toml.hpp            vendored toml++ single-header (MIT)
  include/eri_toml.h          C ABI exposed to Swift
  include/module.modulemap
  eri_toml.cpp                C++ shim implementing the C ABI on top of toml++
Resources/
  Info.plist                  declares http/https URL schemes, LSUIElement
  AppIcon.png
Tests/EriTests/               Swift Testing suite (rule matching + decoder)
Makefile                      .app bundling, codesign, lsregister
Package.swift                 SwiftPM (no third-party deps)
config.example.toml           starter config
```

## Dependencies

No SwiftPM dependencies. TOML parsing is provided by [toml++](https://github.com/marzer/tomlplusplus) v3.4.0, vendored as `Sources/CTomlPlusPlus/include/toml.hpp` (MIT). macOS 12+ deployment target.

## License

[MIT](./LICENSE) © Jiulong Wang
