# Shenghai Apple App Workspace

This folder holds the Xcode-first implementation for Shenghai.

## Current Module

`ShenghaiCore` is a Swift package that can be opened directly in Xcode:

```bash
open ios-app/ShenghaiCore/Package.swift
```

It targets:

- iOS 17+ for iPhone and iPad
- macOS 14+

## Why Package First

The first risky part of Shenghai is not the UI. It is whether sheet data can become a reliable playback timeline. Keeping that logic in a package lets iPhone, iPad, and macOS apps share the same parser, data model, and playback preparation code.

## Next App Targets

After the core package stabilizes, create app targets in Xcode:

- `Shenghai`: iOS/iPadOS SwiftUI app
- `ShenghaiMac`: macOS SwiftUI app

Both should depend on `ShenghaiCore`.
