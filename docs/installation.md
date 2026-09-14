# Automatic test-page installation

The installer assembly contains a Rock plugin migration. On startup, Rock runs migration 1 once and creates:

- **Wi-Fi Connect (Plugin)** on the standard external site, using its Full Width layout and Main zone.
- The route **`/wificonnect-plugin`**, with the Wi-Fi Presence Captive Portal block already placed on the page.
- Public **View** permission on this page and block. Existing administrative permissions still govern editing.
- A page hidden from navigation, with output caching disabled.

The existing `/wificonnect` page and its settings are not changed. The installer creates no replacement cookie handler and changes no APIs.

## Build the package

On a Windows development machine, install a supported .NET SDK and the .NET Framework 4.7.2 developer/targeting pack. Make the `bin` directory from the Rock v19 test instance available locally. It supplies matching Rock and EntityFramework references; these dependencies are not bundled into the plugin ZIP.

From this repository, run PowerShell:

```powershell
.\build\Build-Package.ps1 -RockBinPath 'C:\RockTest\bin'
```

Replace that example path with your actual test site's `bin` directory. The result is `artifacts/WifiPresence-0.1.0.zip`:

```text
Plugins/WifiPresence/CaptivePortal.ascx
Plugins/WifiPresence/CaptivePortal.ascx.cs
bin/rocks.derekmaxson.WifiPresence.dll
```

This ZIP is a web-root deployment bundle, **not a Rock Shop import package**. The block itself remains an ASP.NET CodeFile compiled by the Rock host; the DLL contains the installation migration.

## Install into Rock v19

1. Use your test instance and its test database. Unzip the bundle outside the web root.
2. Copy the bundle's `Plugins/WifiPresence` folder into the test site's `Plugins` folder.
3. Copy `bin/rocks.derekmaxson.WifiPresence.dll` into the test site's `bin` folder **last**. Updating `bin` causes ASP.NET to restart the application. Load the site and let Rock finish startup migrations and block compilation.
4. Open **Admin Tools > CMS Configuration > Pages** and find the root page **Wi-Fi Connect (Plugin)**, or visit `/wificonnect-plugin` on that external site's hostname.
5. Configure your Wi-Fi system to include **`fppostback`** in the incoming query string. Its value must be the URL-encoded absolute HTTP or HTTPS release URL. There is no Release Link block setting or fallback. Set **MAC Address Parameter** and the form fields/person defaults to match your existing block; these settings are not automatically copied.
6. Test using a private browser window and a synthetic MAC address:

```text
https://YOUR-TEST-HOST/wificonnect-plugin?client_mac=02:11:22:33:44:55&fppostback=https%3A%2F%2Fwifi.example%2Frelease
```

Replace `https://wifi.example/release` with your actual release URL and URL-encode the entire value, especially if it contains `?`, `&`, `+`, or `#`. Keep the incoming query string on form postbacks. The plugin reads `fppostback` from the URL on every request and forwards the original inbound query string intact, appending `id=<person alias ID>` when a person is identified. Encoding, parameter order, repeated keys, empty values, and existing callback query text are preserved; existing parameters are not changed. Without an identified person, no `id` is appended. Have the Wi-Fi system omit `id` from incoming URLs: preserving an existing one would result in duplicate `id` values.

If updating an existing source-only installation, replace the code-behind file and reload block-type attributes in Rock. A previously stored Release Link value is ignored.

The installer assumes Rock's standard external site and Full Width layout still exist. If they were removed, it fails with an explicit prerequisite message before changing the database. Adapt `SiteGuid` and `LayoutGuid` in the migration for a custom installation, and verify the selected layout has a `Main` zone before building.

## Validation on the test instance

This code has not yet been compiled against Rock assemblies or executed on IIS/SQL Server. Perform these checks before considering it a release:

1. **Clean installation:** one plugin page, one route, one plugin block; existing core page and block remain intact.
2. **Configuration:** missing, empty, duplicate, relative, or non-HTTP(S) `fppostback` values display an error before processing. With a valid callback, registration creates/links the test device and redirects correctly. Test initial visits, form submissions, and automatic connection mode. Also remove `fppostback` from a submitted URL and verify that no person/device changes occur. Verify the administrator redirect preview displays encoded text safely.
3. **Permissions:** an anonymous visitor sees the form but cannot administer it. A Rock administrator can change settings.
4. **Restart:** change a form setting, restart the site, and confirm that setting and the single page/block/route remain intact. Submit requests with two different `fppostback` hosts and confirm each uses its own callback.
5. **Conflict:** on a separate disposable test database, create `/wificonnect-plugin` on another page before first installation. The migration must fail before creating its page. Resolve the conflict, then retry startup. Review Rock's Exception Log for the migration error.
6. **Presence compatibility:** if your external integration sends `/api/Presence` sessions, confirm sessions for a device linked by the plugin associate with the expected person.
7. **No cookie-reader replacement:** the plugin still writes the original cookie, but supplies no reader. Rock v19 may still process it; that is existing core behavior, not functionality installed by this package.

The read-only queries in `verify-installation.sql` display the created objects and any page/block duplication or placement errors. They do not test form compilation or Wi-Fi-controller behavior.

## Focused URL tests

From a fresh **Windows PowerShell 5.1** session, run:

```powershell
.\tests\Test-ReleaseUrl.ps1
```

These tests compile the actual URL helper methods from the block using .NET Framework `System.Web`. They cover invalid/missing/duplicate callbacks, HTTP and HTTPS, nested query encoding, existing query strings/fragments, literal query-string preservation, appended id, repeated parameters, anonymous redirects, and different callbacks on successive requests. They do not replace Rock/WebForms integration testing and have not been run in the current Mac environment.

## Removal and rollback

Removing the DLL does not automatically invoke a migration's `Down()` method or delete its page. On the test instance, remove the plugin page/block and route through Rock's administration UI before removing the files. Keep existing people, devices, and interactions.

The migration includes a guarded `Down()` implementation for controlled rollback tooling. It removes only its page, block, route and initial View rules, refuses to remove a page with added child pages/blocks/routes, and leaves the block-type registration for other instances. It does not promise rollback if administrators have created additional references to the page. Use a database restore for a complete return to the pre-install test state; do not reset migration-history rows on a populated instance just to force a reinstall.

## Implementation references

- [Rock plugin migration lifecycle](https://community.rockrms.com/developer/book/17/17/content)
- [v19 migration helpers](https://github.com/SparkDevNetwork/Rock/blob/release-19.0/Rock/Data/MigrationHelper.cs)
- [v19 external Full Width layout identifier](https://github.com/SparkDevNetwork/Rock/blob/release-19.0/Rock/SystemGuid/Layout.cs)
