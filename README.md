# Wi-Fi Presence plugin conversion

Plugin source and automatic page installer targeting Rock RMS 19.0. **Not yet compiled/runtime-tested or certified for Rock 21.**

## What is included

`src/Plugins/WifiPresence/CaptivePortal.ascx` and its code-behind provide an independently identified WebForms block, **Wi-Fi Presence Captive Portal**, under **Plugins > Wi-Fi Presence**. ASP.NET compiles these two block files in the Rock host. The separate `src/rocks.derekmaxson.WifiPresence` project builds an installer DLL that creates a public **Wi-Fi Connect (Plugin)** page at `/wificonnect-plugin` with the block already attached. It uses the standard external site Full Width layout.

See [automatic installation and build instructions](docs/installation.md). The build script creates a web-root deployment ZIP; it is not a Rock Shop import package. Copying the two block files alone still requires manual page creation.

The source is derived from Rock's `release-19.0` branch. Exact upstream blob identifiers are in [the manifest](docs/upstream-manifest.json). Copyright and Rock Community License headers are retained in the C# file.

Changes from upstream:

- Separate plugin path, namespace, display name, category, and block-type GUID (`B31D5874-C9CE-48AB-B3B7-0B94C352A495`).
- Direct device/person linking is extracted from `RockPage` into the plugin, including backfilling interactions without a person alias.
- Existing form fields, matching behavior, device detection, and cookie writing are retained. The fixed Release Link setting is removed: every request supplies the release URL in `fppostback`.

The plugin keeps the configurable MAC query parameter (default `client_mac`). The release URL always comes from exactly one inbound `fppostback` query parameter containing a URL-encoded absolute HTTP or HTTPS URL. Missing/invalid values stop processing on both initial visits and form submissions; there is no fixed-setting fallback. The inbound query string is forwarded intact (including encoding, order, repeated keys, and `fppostback`), with `id=<person alias ID>` appended when a person is identified. Existing query text in the release URL is also retained. Existing parameters are not overwritten. If no person is identified, no `id` is added. An already-supplied `id` is preserved too, so the Wi-Fi system should omit it from incoming URLs to avoid duplicate values. Compatibility depends on the Wi-Fi system supplying that contract; this does not add vendor-specific controller integrations.

Project scope clarification: the APIs are not being deprecated. The conversion covers the Captive Portal block and any block-specific helpers it needs. Existing Rock APIs, including `POST /api/Presence`, remain core dependencies with their existing routes and contracts.

## Manual source-only staging (without the installer DLL)

Use the [automatic installer](docs/installation.md) to create the page during installation. The steps below apply only when copying the two block files by themselves.

1. Use an isolated copy of the current Rock v19 site and database. Capture existing `/wificonnect` page configuration, block settings, page/block security, and the incoming Wi-Fi URL including `fppostback`.
2. Copy `src/Plugins/WifiPresence` to `RockWeb/Plugins/WifiPresence` in that site. Register/reload block types using Rock's block registration tools. Confirm that the new block type is registered separately from the core Captive Portal (`CCFCD227-C8F9-4952-8AC5-E427D519EE47`).
3. Add the new block to a temporary test page. Copy the form settings, including custom legal-note Lava, visibility settings, person defaults, and MAC parameter. Configure your Wi-Fi system to supply `fppostback`; the old Release Link setting is no longer used. Reproduce page and block security. No automatic settings migration is included.
4. Test an incoming URL from each actual Wi-Fi integration. Verify missing/invalid MAC errors; first-time and returning devices; logged-in users; matching and new people; all enabled/disabled field combinations; required acceptance; automatic connection mode; the exact redirect URL; and behavior in iOS/Android captive browsers.
5. Confirm device/person links and historical interaction backfill in the database. If used, test the external presence sender against `/api/Presence`. Deferred cookie linking is excluded from the plugin: no replacement cookie reader will be added. Rock v19 may still process the cookie through its existing core handler.
6. After runtime validation, replace the block on the existing page while preserving the `/wificonnect` route. Transfer settings and security explicitly. Keep a record of the original block configuration for rollback. Rollback consists of restoring the original core block and its settings while still on v19; rollback after core removal requires a separate plan.

The production site has not been accessed or changed. The example demo URL could not be loaded by the research tool, so its exact route-to-block mapping has not been independently verified.

## Work required before v21

Rock's [March 2026 roadmap](https://community.rockrms.com/connect/product-grooming-roadmap) schedules Captive Portal removal in v21, expected in the first half of 2027. The project owner has clarified that APIs are not being deprecated; API replacement or migration is outside this conversion's scope. Block-specific helper and lifecycle compatibility still need verification.

| Dependency | Current state | Remaining conversion work |
| --- | --- | --- |
| Captive Portal form | Extracted into a separate v19 plugin block | Compile and exercise on the actual installed v19 patch; inspect v21 compatibility |
| Direct device/person linking | Extracted into the plugin | Verify interaction backfill helper remains available in v21 |
| Deferred `rock_wifi` cookie processing | Existing cookie writer retained; no plugin cookie reader | Explicitly excluded from conversion. Later identification through this mechanism ends when the core reader is removed |
| Authenticated `POST /api/Presence` | Retained core API; not deprecated | Use the existing endpoint; verify integration behavior where used |
| `PersonalDevice`, interactions, defined values | Existing Rock models and data remain in use | Audit removal migrations and preserve required data/configuration before upgrading |
| UAParser / `InteractionDeviceType.GetClientType` | v19 implementation retained | Adapt to the target Rock version; develop already uses different user-agent APIs |
| Installation/settings transfer | Versioned migration creates a separate public page, route and block | Build and validate on Rock v19; supply fppostback from the Wi-Fi system and copy desired form settings manually |

No claim is made that this extraction alone completes the v21 migration. There is no local .NET/MSBuild or Rock/IIS/SQL Server runtime available for end-to-end validation.

## Source references

- [Captive Portal code](https://github.com/SparkDevNetwork/Rock/blob/release-19.0/RockWeb/Blocks/Security/CaptivePortal.ascx.cs)
- [Captive Portal markup](https://github.com/SparkDevNetwork/Rock/blob/release-19.0/RockWeb/Blocks/Security/CaptivePortal.ascx)
- [RockPage cookie and linking logic](https://github.com/SparkDevNetwork/Rock/blob/release-19.0/Rock/Web/UI/RockPage.cs)
- [Presence API](https://github.com/SparkDevNetwork/Rock/blob/release-19.0/Rock.Rest/Controllers/PresenceController.cs)
- [Wi-Fi Presence documentation](https://community.rockrms.com/documentation/BookContent/36/)
