# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & install

`swift build` alone is not enough — Eri must be a proper `.app` bundle (with `Info.plist` declaring `CFBundleURLTypes` for http/https) and registered with LaunchServices before macOS will offer it as a default browser. The `Makefile` is the source of truth:

- `make` / `make app` — build release binary, generate `AppIcon.icns`, assemble `build/Eri.app`, ad-hoc codesign.
- `make register` — `lsregister -f build/Eri.app` so LaunchServices picks up the local build (needed for "Default Web Browser" to list it).
- `make install` — copy to `/Applications/Eri.app` and register it there.
- `make uninstall` — remove from `/Applications`.
- `make clean` — wipe `.build/` and `build/`.
- `swift build -c release` — binary only; useful for quick syntax/type checks but produces nothing macOS can route URLs to.

The icon pipeline shells out to `sips`, `pngquant`, and `iconutil` — `pngquant` must be on `PATH` (e.g. `brew install pngquant`).

`swift test` runs the `EriTests` target (Swift Testing, `@Test`/`#expect` style). Tests live in `Tests/EriTests/`.

## Runtime model

Eri is a one-shot agent app — every invocation terminates itself. There are two launch paths, distinguished by whether the GetURL Apple Event fires:

1. **macOS-dispatched URL** (the hot path): `applicationWillFinishLaunching` registers the GetURL handler *before* `applicationDidFinishLaunching` runs, so by the time `didFinishLaunching` fires, `handleGetURL` has already set `didReceiveURL = true`. The handler routes the URL and calls `scheduleQuit()` (0.4 s grace for any pending `UNNotificationRequest` to flush, then `NSApp.terminate`).
2. **Manual launch** (Finder, `open -a Eri`): no URL arrives, the 0.2 s timer in `applicationDidFinishLaunching` fires, `DefaultBrowserPrompt.runIfNeeded()` shows the NSAlert, then `Router.openDefault(config:)` launches the configured default browser with no URL (Eri itself has no UI). Quit goes through `scheduleQuit()` so any error notification from the default-browser launch survives termination.

Consequences worth remembering when editing:
- Do not add long-lived state or background work — the process is gone within ~½ second.
- Anything that needs to outlive the process (notifications, log lines) must be dispatched before `scheduleQuit()`; the 0.4 s delay exists specifically because `UNUserNotificationCenter.add` is async and would otherwise be cancelled on terminate.
- `Info.plist` sets `LSUIElement=true` (no Dock icon, no menu bar). If you ever need a window, that flag has to come off.

## Routing pipeline

URL flow: `AppDelegate.handleGetURL` → `Router.open(url:config:)` → `Config.match(url:)` → `/usr/bin/open`.
Manual flow: `AppDelegate.launchDefaultBrowser` → `Router.openDefault(config:)` → `Config.defaultTarget()` → `/usr/bin/open` (no URL appended).

- `Config.load()` searches `~/.config/eri/config.toml` then `~/Library/Application Support/Eri/config.toml`. First hit wins. If neither exists, `resolveConfigPath` scaffolds a minimal `[default] / browser = "com.apple.Safari"` at the primary path (creating `~/.config/eri/` as needed) and proceeds — so `Config.load` only fails on parse errors or write failures (`ConfigError.parseFailed` / `ConfigError.scaffoldFailed`, both surfaced as user-visible notifications).
- `Config.match` walks `[[rule]]` entries top-to-bottom; first match wins, otherwise it falls through to `defaultTarget()`. `defaultTarget()` returns the resolved `default` entry, or a hard-coded Safari `BrowserRef` if `default` is omitted. A rule matches by **exactly one** of `host` (glob with `*`), `domain` (value itself + any subdomain via `host == d || host.hasSuffix("." + d)`), `host_regex`, or `url_regex` — `Rule.matches` checks them in url_regex → host_regex → domain → host order. Glob is implemented by escaping the pattern then turning literal `\*` into `.*` and anchoring with `^…$` (see `Config.swift`).
- `Config` also holds a `[String: BrowserRef]` `browsers` map (decoded from `[browsers.<id>]`). `Config.resolve` looks up a rule's or default's `browser` string in that map first; on hit, the entry's bundle id/profile/args replace the rule's, with rule-level `args` appended after browser-level `args` (rule-level `profile` is ignored). On miss, the string is treated as a bundle id (the inline form, current behavior).
- `Router.launch` takes `URL?` — the manual-launch path passes `nil` and the URL is simply omitted from the `open` argv. Two non-obvious workarounds:
  - **Safari profile is silently dropped**. Safari has no CLI/URL-scheme way to pick a profile, and if we let `--profile-directory=…` reach the `--args` branch, `open` swallows the URL too.
  - **`-n` is required whenever extra args are passed**. Without it, `open` skips `--args` entirely when the target is already running, dropping both the profile flag and the URL. `-n` forces a fresh launch; Chromium's single-instance handler IPCs the args to the existing process so no duplicate window stays open.

## Default-browser prompt

`DefaultBrowserPrompt` probes `NSWorkspace.urlForApplication(toOpen: https://example.com)` and compares the returned bundle id to `Bundle.main.bundleIdentifier` (`cc.novacore.eri`). If they don't match and the user hasn't ticked "Don't Ask Again" (stored in `UserDefaults` as `EriSkipDefaultBrowserPrompt`), it offers to call `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)` for both `http` and `https`. macOS still shows its own confirmation sheet on top of that.

## Dependencies

Single SwiftPM dependency: [TOMLKit](https://github.com/LebJe/TOMLKit) for config parsing. macOS 12+ deployment target.
