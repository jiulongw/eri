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

There is no test target.

## Runtime model

Eri is a one-shot agent app — every invocation terminates itself. There are two launch paths, distinguished by whether the GetURL Apple Event fires:

1. **macOS-dispatched URL** (the hot path): `applicationWillFinishLaunching` registers the GetURL handler *before* `applicationDidFinishLaunching` runs, so by the time `didFinishLaunching` fires, `handleGetURL` has already set `didReceiveURL = true`. The handler routes the URL and calls `scheduleQuit()` (0.4 s grace for any pending `UNNotificationRequest` to flush, then `NSApp.terminate`).
2. **Manual launch** (Finder, `open -a Eri`): no URL arrives, the 0.2 s timer in `applicationDidFinishLaunching` fires, `DefaultBrowserPrompt.runIfNeeded()` shows the NSAlert, and the app quits.

Consequences worth remembering when editing:
- Do not add long-lived state or background work — the process is gone within ~½ second.
- Anything that needs to outlive the process (notifications, log lines) must be dispatched before `scheduleQuit()`; the 0.4 s delay exists specifically because `UNUserNotificationCenter.add` is async and would otherwise be cancelled on terminate.
- `Info.plist` sets `LSUIElement=true` (no Dock icon, no menu bar). If you ever need a window, that flag has to come off.

## Routing pipeline

`AppDelegate.handleGetURL` → `Router.open(url:config:)` → `Config.match(url:)` → `/usr/bin/open`.

- `Config.load()` searches `~/.config/eri/config.toml` then `~/Library/Application Support/Eri/config.toml`. First hit wins. Missing config → user-visible notification, but the app still terminates cleanly.
- `Config.match` walks `[[rule]]` entries top-to-bottom; first match wins. A rule matches by **exactly one** of `host` (glob with `*`), `host_regex`, or `url_regex` — `Rule.matches` checks them in url_regex → host_regex → host order. Glob is implemented by escaping the pattern then turning literal `\*` into `.*` and anchoring with `^…$` (see `Config.swift:78`).
- `Router.launch` has two non-obvious workarounds:
  - **Safari profile is silently dropped** (`Router.swift:13`). Safari has no CLI/URL-scheme way to pick a profile, and if we let `--profile-directory=…` reach the `--args` branch, `open` swallows the URL too.
  - **`-n` is required whenever extra args are passed** (`Router.swift:24`). Without it, `open` skips `--args` entirely when the target is already running, dropping both the profile flag and the URL. `-n` forces a fresh launch; Chromium's single-instance handler IPCs the args to the existing process so no duplicate window stays open.

## Default-browser prompt

`DefaultBrowserPrompt` probes `NSWorkspace.urlForApplication(toOpen: https://example.com)` and compares the returned bundle id to `Bundle.main.bundleIdentifier` (`cc.novacore.eri`). If they don't match and the user hasn't ticked "Don't Ask Again" (stored in `UserDefaults` as `EriSkipDefaultBrowserPrompt`), it offers to call `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)` for both `http` and `https`. macOS still shows its own confirmation sheet on top of that.

## Dependencies

Single SwiftPM dependency: [TOMLKit](https://github.com/LebJe/TOMLKit) for config parsing. macOS 12+ deployment target.
