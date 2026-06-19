# iGentic Diagnostics App Wrapper

This directory contains the smallest installable iOS application wrapper for the existing `iGenticApp` Swift package product.

## What it does

- Defines the `iGenticDiagnostics` iOS application target.
- Imports the local package product from `../../ios`.
- Presents `DiagnosticView` as the root SwiftUI view.
- Builds for the iOS Simulator without code signing in GitHub Actions.

## What it does not do

- No networking or external providers.
- No persistence or private user data.
- No App Intents or real tool execution.
- No model calls or model weights.
- No Apple account, team identifier, certificate, provisioning profile or device identifier is stored in the repository.
- No physical-device validation is claimed.

## Local owner steps

The committed bundle identifier `org.example.iGenticDiagnostics` is a non-production placeholder. Before a physical-device run, replace it locally with an identifier controlled by the owner and select the Apple Developer Team under Signing & Capabilities.

Do not commit account identifiers, signing certificates or provisioning-profile contents.

## Repository validation

Package validation remains:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

The wrapper has an additional unsigned simulator build:

```bash
xcodebuild \
  -project app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj \
  -scheme iGenticDiagnostics \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

A successful simulator build does not prove physical-device installation, launch behavior or performance.

## Follow-up

After repository validation succeeds, the remaining steps are local owner actions: choose the production bundle identifier, select the Apple Developer Team, configure signing and execute the committed physical-device checklist.
