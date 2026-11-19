# Home & Land

An iPhone app for finding homes and land for sale in **Southern Ontario**, including power of sale, tax sale, receivership, estate and government surplus properties.

## What's in the app

| Tab | What it does |
| --- | --- |
| **Find** | A search builder: pick a region and keywords (“power of sale”, “estate sale”, “vacant land”…) and search Realtor.ca, Kijiji, Zolo or the whole web. Also has tax sale notice searches and about 50 sources: MLS sites, tax sales, receivers, government surplus, commercial brokerages, farm auctions, due-diligence tools and lenders. |
| **Watchlist** | Save properties you find. Track the asking price, your maximum, the offer or tender deadline and the status. Each property gets a due-diligence checklist that changes with the sale type (power of sale, tax sale, receivership…) and kind of property (house, condo, land…), plus a land transfer tax estimate. Paste a Realtor.ca link and the address fills in. You can export and import backups. |
| **Guide** | How power of sale, tax sales, receiverships, estate sales and government surplus work in Ontario, a comparison of sale types, a page for each Southern Ontario region, due-diligence tools, financing and costs, and scams to avoid. |
| **Tools** | Land transfer tax and cash-to-close calculator (Ontario + Toronto, first-time buyer refunds) and a tax sale tender calculator (20% deposit, balance, LTT, HST). |

Listing sites such as Realtor.ca don't offer a public data feed, so the app doesn't copy listings. It opens the sites in an in-app browser and runs searches for you.

## Get the app (.ipa)

Every push to `main` runs the **Build iOS app** workflow on a GitHub Mac runner. It runs the unit tests and builds an unsigned `HomeLand.ipa`.

- **Easiest:** open the repository's **Releases** page and download `HomeLand.ipa` from **Latest build**.
- Or open **Actions → Build iOS app**, pick a run and download the `HomeLand-ipa` artifact (it's a zip with the .ipa inside).
- To build again without changing code: **Actions → Build iOS app → Run workflow**.

## Install it on your iPhone

The .ipa is unsigned, so you sign it with your own Apple ID while installing. Both of these tools are free:

### Option A: Sideloadly (Windows or Mac)

1. Install [Sideloadly](https://sideloadly.io/) on your computer (plus iTunes and iCloud from Apple's website if you're on Windows).
2. Connect your iPhone with a cable and tap **Trust** on the phone if asked.
3. Drag `HomeLand.ipa` into Sideloadly, enter your Apple ID and click **Start**.
4. On the iPhone, go to **Settings → General → VPN & Device Management**, tap your Apple ID and tap **Trust**.
5. On iOS 16 or later, turn on **Settings → Privacy & Security → Developer Mode** and restart when asked.

### Option B: AltStore (Windows or Mac)

1. Install AltServer on your computer and AltStore on your iPhone by following the instructions at [altstore.io](https://altstore.io/).
2. Copy `HomeLand.ipa` to your iPhone (AirDrop, Files or iCloud Drive).
3. In AltStore, open **My Apps**, tap **+** and choose the .ipa.

### Good to know

- With a **free Apple ID** the app stops opening after **7 days**. Refresh it in AltStore, or install it again with Sideloadly. Installing over the top keeps your watchlist.
- Free Apple IDs can have 3 sideloaded apps at a time.
- **Back up your watchlist** now and then: Watchlist → ••• → Export backup. If you delete the app, its data goes with it.
- With a paid Apple Developer account ($99 USD a year) you can sign it for a full year or use TestFlight instead.

## Build it yourself (Mac)

You need Xcode 15 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
open HomeLand.xcodeproj
```

The Xcode project is generated from `project.yml` and isn't committed. Run tests with **⌘U** in Xcode.

## Project layout

```
project.yml                     XcodeGen project spec
.github/workflows/build-ipa.yml CI: tests, unsigned IPA, "latest" release
scripts/xcodebuild-ci.sh        Runs xcodebuild and annotates errors in CI
HomeLand/
  App/          App entry point and tab bar
  Models/       Property, sale types, regions, checklists
  Store/        Watchlist storage (JSON in Documents) and backups
  Content/      Sources, keywords and the Ontario guide text
  Logic/        Land transfer tax, search links, parsing and formatting
  Views/        Find, Watchlist, Guide and Tools screens
  Resources/    App icon and accent colour
HomeLandTests/  Unit tests
```

## Disclaimer

General information, not legal or financial advice. Tax rates, rules and websites change. Confirm details with an Ontario real estate lawyer before you offer or bid.
