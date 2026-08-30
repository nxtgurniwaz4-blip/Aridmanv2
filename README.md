# Aridman's Happy Place

SwiftUI iPhone + iPad app for browsing a toddler-friendly catalog of Pramod's Life videos.

## Repository layout

```text
AridmansHappyPlace/
├── codemagic.yaml
├── project.yml
├── README.md
└── AridmansHappyPlace/
    ├── AridmansHappyPlaceApp.swift
    ├── Models.swift
    ├── HomeView.swift
    ├── CategoryTile.swift
    ├── VideoListView.swift
    ├── CategoryClassifier.swift
    ├── AppCache.swift
    ├── VideoCatalog.swift
    └── Info.plist
```

## Build

The repository is intended for Codemagic. Codemagic installs/uses XcodeGen on its macOS build machine, generates `AridmansHappyPlace.xcodeproj`, archives the iOS app with signing disabled, and packages the built `.app` into:

`AridmansHappyPlace-unsigned.ipa`

The IPA is intentionally unsigned. It must be signed with a valid Apple provisioning/signing setup before installation on an iPhone or iPad.

No Apple signing credentials are stored in this repository.

## Video catalog

No invented YouTube video IDs are bundled.

`VideoCatalog` stores catalog JSON in the app's cache directory. The starter build therefore starts empty rather than pretending that the whole channel has already been imported.

The model and classifier are ready for a real catalog feed/import. Each real video record should contain its actual YouTube video ID, title, description, thumbnail URL, and optionally precomputed categories. `CategoryClassifier` can classify titles/descriptions into the nine app categories.

The intended source channel is Pramod's Life:

https://youtube.com/@pramodslife

## Cache

Catalog/cache files are kept under the app's `Caches` directory. The cache manager targets a maximum of approximately 2 GB and removes oldest cache entries when the target is exceeded. iOS may also clear cache data when storage pressure requires it.

## Important

An unsigned IPA is not directly installable on a normal iPhone/iPad. Signing is a separate deployment step and is intentionally outside this project.
