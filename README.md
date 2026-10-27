<div align="center">

# CliProxy Quota

**Your remaining AI usage. One glance at the menu bar.**

A small, native macOS app for [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI). See remaining subscription quotas, account-level limits, and reset countdowns without opening a browser.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-333333?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-397468)

<img src="docs/screenshots/overview.png" width="390" alt="Native macOS popover showing remaining quota by provider and reset countdowns" />

</div>

## About this fork

This fork of [aduggleby/CliProxyQuota](https://github.com/aduggleby/CliProxyQuota) displays the actual 5-hour and weekly remaining percentages independently in the menu bar. For example, a full 5-hour window and 59% remaining weekly quota display as `⁵ʰ 100% · ʷ 59%`. The countdown shows whichever 5-hour or weekly reset comes first. Regression tests cover individual accounts, provider averages, used-percentage mode, and reset selection.

## A quieter way to watch your limits

- **Remaining usage**, with progress bars and reset countdowns for every reported limit. Hover over a countdown to see its full reset date and time in your local timezone.
- **All accounts** groups matching provider quotas and shows their average in the selected percentage mode.
- **Per account** shows individual windows, including weekly and model-specific limits. Click a Claude account’s email to open Claude billing in your browser. The link uses the account already signed in to your browser; check that it matches the email shown.
- **Fits your screen**: both views grow to show all content, scrolling only when the popover would exceed the available display height.
- **Remaining or Used**: one preference updates percentages and bars in both quota views and the menu bar.
- **5-hour, Weekly, or Both** in the menu bar. Single limits show `72%`; Both shows `⁵ʰ 72% · ʷ 84%`.
- **Independent tray quotas**: the 5-hour and weekly percentages show their own API-reported remaining values, averaged separately across accounts reporting each window.
- **Tray warning badges**: each percentage and its window label use white text on a rounded dark yellow/gold background above 10% through 25% remaining and a red background at or below 10%. Colors always reflect remaining capacity, including in Used mode. **Color warnings** in Tray Display is on by default; switch it off for plain tray text. Colored mode separates segments with compact badge padding; plain mode uses dots. The separate **Reset countdown** switch is also on by default and works independently of colors and warning thresholds.
- **Checkbox source menu**: select provider averages or individual accounts. Each selected source gets its own menu bar item; clear all selections for icon-only mode.
- **Provider-wide usage forecast**: one sentence in All accounts estimates whether the combined allowance lasts until reset. Enable or disable it under General and choose a 30-, 60-, or 120-minute averaging period.
- **Automatic refresh** every 1, 2, 5, or 10 minutes, plus manual refresh.
- **Configurable connection** with the management password stored in macOS Keychain, scoped to the instance URL.
- **Light and dark mode**, optional launch at login, and no Dock icon.
- **No third-party dependencies**, analytics, or account-token storage.
- **Provider icons**: artwork for 17 provider identities in both quota views and the source menu, including light/dark variants where supplied. Unknown custom providers retain a letter fallback. Bundled locally for offline use.
- **Three-dot menu**: Refresh, Open management UI, API version, and Quit are grouped in the bottom-right menu.

## Screenshots

<img src="docs/screenshots/tray-badges.png" width="420" alt="Rounded red and yellow tray badges in Remaining and Used modes, with a third segment showing the next reset in 2h 14m" />

The `↻ 2h 14m` segment shows the earlier of the reported 5-hour and weekly resets across the selected accounts.

<table>
<tr>
<td align="center"><strong>Account detail</strong></td>
<td align="center"><strong>Dark mode</strong></td>
</tr>
<tr>
<td><img src="docs/screenshots/accounts.png" width="360" alt="Per-account remaining quota view" /></td>
<td><img src="docs/screenshots/overview-dark.png" width="360" alt="Quota overview in dark mode" /></td>
</tr>
</table>

Screenshots are rendered from the app's actual SwiftUI views in **Demo** mode. Account addresses and percentages are synthetic.

## Install

Requires **macOS 14 Sonoma or later**. Supports Apple Silicon and Intel.

**[Download the latest app](https://github.com/aduggleby/CliProxyQuota/releases/latest)**, unzip it, and move **CliProxy Quota.app** into Applications. No Xcode is needed for the prebuilt app.

To build from source, install Xcode 16 or newer (Swift 6), then:

```sh
git clone https://github.com/aduggleby/CliProxyQuota.git
cd CliProxyQuota
./scripts/build-app.sh
./scripts/install.sh
```

The installer copies the app to `~/Applications` and opens it. You can also copy `build/CliProxy Quota.app` into `/Applications`. Quit the running app before installing an update.

Build for both Apple Silicon and Intel with:

```sh
./scripts/build-app.sh --universal
```

Local builds are **ad-hoc signed**, not Developer ID signed or notarized. Downloaded builds may require **right-click → Open** or approval in **System Settings → Privacy & Security**. Building locally avoids downloading an unsigned executable. Ad-hoc signing can cause Keychain access prompts after rebuilding the app.

## Connect your instance

1. Click the Quota Bot icon in the menu bar, then the settings icon.
2. Enter your CLIProxyAPI instance's base URL, such as `http://localhost:8317` or `https://proxy.example.com`.
3. Enter the **management password/key**, not a proxy inference API key or a provider OAuth token.
4. Click **Save & connect** in **Connection**. Choose a refresh interval under **General**.
5. Under **Tray Display**, choose **Remaining / Used**, **5-hour / Weekly / Both**, and one or more **Source** checkboxes. Changes apply immediately.
6. Use the back arrow to return to **All accounts** or **Per account**. Both use the selected percentage mode.

Settings has three tabs: **General**, **Connection**, and **Tray Display**. Connection changes use **Save & connect**; a blank management-password field keeps the saved Keychain password for that same instance. Refresh interval, launch-at-login, and **Light / Dark / System (Default)** appearance are under General. Appearance changes apply immediately and are remembered. **Usage forecast** and its **Average over** control also live in General; disabling it clears forecast history and stops collecting samples.

The management API must be enabled. Connections from another machine require remote management to be allowed on the server. Your Mac must be able to resolve and reach the URL, including any required VPN.

HTTPS is the default for remote instances. To use a trusted HTTP instance, explicitly enable **Allow HTTP for this instance**. HTTP carries the management password without encryption; the opt-in applies only to that saved URL. Redirects are refused so credentials cannot silently move to another endpoint.

### Settings screenshots

<table>
<tr><td align="center"><strong>General</strong></td><td align="center"><strong>Connection</strong></td></tr>
<tr>
<td><img src="docs/screenshots/settings-general.png" width="360" alt="General settings with appearance, refresh interval, launch at login, and configurable usage forecasts" /></td>
<td><img src="docs/screenshots/settings-connection.png" width="360" alt="Connection settings with instance URL, management password, and Save and connect" /></td>
</tr>
<tr><td align="center"><strong>Tray Display</strong></td><td align="center"><strong>General in dark mode</strong></td></tr>
<tr>
<td><img src="docs/screenshots/settings.png" width="360" alt="Tray Display settings with the default-on Color warnings and Reset countdown switches, remaining or used percentages, quota windows, and source selection" /></td>
<td><img src="docs/screenshots/settings-general-dark.png" width="360" alt="General settings using dark appearance" /></td>
</tr>
</table>

### Used mode

<img src="docs/screenshots/overview-used.png" width="420" alt="Used percentages and matching bars across provider quotas" />

### Independent menu bar percentages

Each tray percentage uses that window's API-reported remaining value. Provider sources average 5-hour and weekly readings independently across accounts reporting each window. Missing and stale windows show a dash. Review-specific limits are excluded.

With **Reset countdown** enabled in Tray Display (the default), an extra `↻` segment shows the earliest reported reset among the main 5-hour and weekly windows of the selected accounts. Remaining percentages do not affect the choice: a 5-hour reset in 2 hours takes precedence over a weekly reset in 6 days, even when the weekly percentage is lower. If only one reset date is available, that date is used; if neither is known, the countdown shows a dash. Disabled or failed accounts and review/monthly windows are excluded. A past-due reset shows `due` until a quota refresh confirms it. Hover the tray item for the absolute reset time. This setting applies immediately and is independent of Color warnings.

For example, accounts reporting `100% / 0%` and `80% / 60%` produce a tray 5-hour average of **90%** and a weekly average of **30%**. An individual account reporting `100% / 59%` displays **5-hour 100% · Weekly 59%**. Used mode shows each window's complement. Quota views and usage forecasts continue to use the observed API values.

## Usage forecast

Forecasts appear only in **All accounts**, beneath each provider. They combine matching quota windows across all enabled, reporting accounts of that provider. Each account’s percentage allowance counts equally, consistent with the overview; plan capacities and routing weights are not available, so this is an estimate rather than a guarantee of transferable capacity.

For each window, the app divides the sum of remaining percentage points by the observed drop per second, including idle intervals, and compares the result with the **next reported reset among its accounts**. The window projected to run out first supplies the warning: “At current pace you will run out Xm before reset.” If every window has sufficient data and none is projected to run out before its next reset: “At current pace your limits will reset in time.” Remaining/Used display preferences do not change this calculation.

The default averaging period is **60 minutes**, configurable to **30 / 60 / 120** under General. Estimates require at least four samples spanning half the selected period: 15, 30, or 60 minutes respectively. Until then the app shows “Learning your usage pace…”. Failed account checks, missing/past reset dates, or stale data suppress the verdict. Changes to account membership, allowance increases, reset dates, or long gaps restart learning. Usage outside the app’s observation period cannot be reconstructed.

History is kept locally and pruned to the last 24 hours whenever samples are recorded, with opaque hashes for instance/provider/window and account membership, summed percentages, timestamps, and reset dates. It contains no account emails, credentials, or tokens. Switching instances clears it. Disabling the feature hides forecasts, stops collection, and deletes the local history file. No additional network requests are made.

<img src="docs/screenshots/overview-forecast-off.png" width="390" alt="All accounts with usage forecasts disabled" />

## Provider support

| OAuth account | Reported limits |
| --- | --- |
| Codex | 5-hour, weekly/monthly, code review, and additional windows returned by the usage endpoint |
| Claude | 5-hour, weekly, and supported model-specific weekly windows |
| Gemini CLI | Per-model quota buckets returned by Google Code Assist |
| Antigravity | Quota summary groups and their reset windows |
| Other providers | Listed with an explicit unsupported status |

Provider artwork follows the [upstream provider list](https://github.com/router-for-me/CLIProxyAPI#readme) and [management UI assets](https://github.com/router-for-me/Cli-Proxy-API-Management-Center/tree/714de0760a3ce86094b178fb46f834d34bc4a2a5/src/assets/icons): OpenAI, Codex, Claude, Gemini, AI Studio, Vertex AI, Antigravity, Kimi, xAI/Grok, Meta/Muse, and Devin. Icons are also bundled for Qwen and iFlow setups, and compatible DeepSeek, GLM, MiniMax, and OpenRouter providers. Aliases such as `grok`, `muse`, and `moonshot` resolve to the corresponding artwork.

Icon coverage does not add quota readers: the quota support table above still applies. Custom OpenAI-compatible services are open-ended. See [artwork attribution](THIRD_PARTY_NOTICES.md) for sources and licensing.

Google accounts need a `project_id` exposed in their CliProxy credential metadata. An account without one is listed with an explanatory message. API-key accounts without a subscription quota endpoint do not get an invented remaining balance. Provider endpoints are unofficial implementation details and can change.

### What the percentages mean

Provider responses are the source of truth: used percentages are converted to **100 − used**, and remaining fractions are multiplied by 100. Missing or failed data is **unavailable**, never assumed to be 100%.

The overview is an **unweighted average across reporting accounts for the same provider and quota window**. It is not a combined transferable allowance: accounts may have different plans, capacities, and reset times. Each pool shows the reporting-account count and the earliest reported reset. Disabled accounts are excluded. A provider-level failure stays visible in the account list, and the overview calls out partial coverage.

Old data is marked after a connection failure or when it becomes stale; the menu bar shows a dash instead of a stale percentage. A reset countdown reaching zero does not automatically grant fresh quota—the next successful API refresh confirms it. On first launch, the menu bar defaults to the Codex provider average when available, otherwise the first provider. Existing pinned selections are migrated. Sources without the selected 5-hour or weekly window show a dash; tooltips retain the window name when a single percentage is shown. Low-quota warning colors always reflect remaining capacity, including in Used mode.

## How it works

The app first requests `GET /v8/management/credentials`. If the server returns 404, it falls back to `GET /v0/management/auth-files`. Quotas are fetched through the corresponding `POST /requests/api-call` (v8) or `POST /api-call` (legacy), using the account's `auth_index` and the server-side `$TOKEN$` placeholder.

Your Mac communicates with **your CliProxy instance**. CliProxy makes the provider quota requests using the credentials it already holds. The app does not download provider credential files, change routing, enable/disable accounts, or redeem/reset quotas. At most four account quota checks run concurrently. Polling uses an ephemeral URL session with no response cache; raw API error bodies are never shown or logged.

The management key is stored in macOS Keychain, associated with the normalized instance URL. The URL, refresh interval, selected source identifiers, percentage mode, and menu bar window are stored locally in UserDefaults. Quota results and account details remain in memory. No configuration or credentials belong in this repository.

API references: [current Management API](https://github.com/router-for-me/CLIProxyAPIDocs/blob/main/docs/en/management/apiv8.md), [legacy API](https://github.com/router-for-me/CLIProxyAPIDocs/blob/main/docs/en/management/api.md), and [official management UI quota readers](https://github.com/router-for-me/Cli-Proxy-API-Management-Center/tree/main/src/features/quota/providers).

## Development

```sh
swift test                      # quota math, parsing, aggregation, and mocked HTTP requests
swift build                     # debug build
.build/debug/CliProxyQuota --verify-layout # native checks for natural height, overflow, and tab changes
./scripts/build-app.sh           # release app bundle + icon + local signature
./scripts/screenshots.sh         # render native views using synthetic data
open "build/CliProxy Quota.app" --args --demo --show
```

`--demo` never connects to an instance and does not write connection preferences. Screenshots use native view rendering; they do not capture your desktop or live account data. Launch-at-login is available after installation through macOS ServiceManagement.

```text
Sources/QuotaCore/      Models, quota parsers, aggregation, HTTP client
Sources/CliProxyQuota/  SwiftUI popover, menu bar lifecycle, settings, Keychain
Tests/QuotaCoreTests/   Parser and mocked network tests
scripts/               Build, install, icon, and screenshot tooling
```

## License

[MIT](LICENSE). Provider artwork is excluded; see [third-party notices](THIRD_PARTY_NOTICES.md).
