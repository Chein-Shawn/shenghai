# VocalDive Apple App Workspace

This folder holds the Xcode-first implementation for VocalDive.

## Current App

Open the app project:

```bash
open ios-app/VocalDive.xcodeproj
```

Use the `VocalDive` scheme. The project is configured as a SwiftUI multiplatform app target for:

- iPhone
- iPad
- macOS

The current Alpha UI supports:

- loading the built-in Twinkle MusicXML demo
- importing MusicXML files
- inspecting parts, measures, notes, and timeline ticks
- generating and playing MIDI
- sharing/exporting the generated MIDI file
- previewing pitch-feedback states for future singing analysis

Validated locally:

```bash
xcodebuild -project ios-app/VocalDive.xcodeproj -scheme VocalDive -destination generic/platform=macOS -derivedDataPath .build/XcodeDerivedData build CODE_SIGNING_ALLOWED=NO
```

If iPhone/iPad simulator destinations are unavailable, install the iOS platform component:

```bash
xcodebuild -downloadPlatform iOS
```

## Current Module

`VocalDiveCore` is a Swift package that can be opened directly in Xcode:

```bash
open ios-app/VocalDiveCore/Package.swift
```

It targets:

- iOS 17+ for iPhone and iPad
- macOS 14+

## Why Package First

The first risky part of VocalDive is not the UI. It is whether sheet data can become a reliable playback timeline. Keeping that logic in a package lets iPhone, iPad, and macOS apps share the same parser, data model, and playback preparation code.
