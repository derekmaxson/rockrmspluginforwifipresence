using System;
using Rock.Plugin;

namespace rocks.derekmaxson.WifiPresence.Migrations
{
    /// <summary>
    /// Installs a separate public portal page. Existing core pages and routes are untouched.
    /// Uses Rock's migration transaction, not a separate RockContext.
    /// </summary>
    [MigrationNumber( 1, "1.19.0" )]
    public class CreateCaptivePortalPage : Migration
    {
        private const string PageGuid = "D41AE879-39AE-4230-A894-0F561F7F7BA7";
        private const string BlockGuid = "3FDF5FCB-1F2E-4799-902A-A0CE2F33953F";
        private const string BlockTypeGuid = "B31D5874-C9CE-48AB-B3B7-0B94C352A495";
        private const string RouteGuid = "5AA58179-6279-4976-BF48-6C2BA2EC54AB";
        private const string PageViewAuthGuid = "46B8F14F-C23D-4CA9-835D-AEAB9A25588D";
        private const string BlockViewAuthGuid = "623A5702-63FD-4964-AD77-1F6976A5B5CF";
        private const string LayoutGuid = "5FEAF34C-7FB6-4A11-8A1E-C452EC7849BD";
        private const string SiteGuid = "F3F82256-2D66-432B-9D67-3552CD2F4C2B";
        private const string Owner = "rocks.derekmaxson.WifiPresence";
        private const string BlockPath = "~/Plugins/WifiPresence/CaptivePortal.ascx";

        public override void Up()
        {
            // Stop before any writes if this site's assumptions are not satisfied.
            Sql( $@"
IF NOT EXISTS (
    SELECT 1 FROM [Layout] l JOIN [Site] s ON s.[Id] = l.[SiteId]
    WHERE l.[Guid] = '{LayoutGuid}' AND s.[Guid] = '{SiteGuid}'
)
    THROW 51000, 'Wi-Fi Presence requires the standard external site Full Width layout. Restore it or adapt the installer to your test site before retrying.', 1;

IF EXISTS (SELECT 1 FROM [Page] WHERE [Guid] = '{PageGuid}' AND ISNULL([ForeignKey], '') <> '{Owner}')
    THROW 51000, 'Wi-Fi Presence page GUID is already owned by another page.', 1;

IF EXISTS (SELECT 1 FROM [Block] WHERE [Guid] = '{BlockGuid}' AND ISNULL([ForeignKey], '') <> '{Owner}')
    THROW 51000, 'Wi-Fi Presence block GUID is already owned by another block.', 1;

IF EXISTS (SELECT 1 FROM [PageRoute] WHERE [Guid] = '{RouteGuid}' AND ISNULL([ForeignKey], '') <> '{Owner}')
    THROW 51000, 'Wi-Fi Presence route GUID is already owned by another route.', 1;

IF EXISTS (
    SELECT 1 FROM [PageRoute] r JOIN [Page] p ON p.[Id] = r.[PageId]
    WHERE LOWER(LTRIM(RTRIM(r.[Route]))) IN ('wificonnect-plugin', '/wificonnect-plugin', 'wificonnect-plugin/', '/wificonnect-plugin/')
      AND r.[Guid] <> '{RouteGuid}'
)
    THROW 51000, 'The wificonnect-plugin route is already in use. Choose a different installer route before retrying.', 1;

IF EXISTS (SELECT 1 FROM [BlockType] WHERE [Guid] = '{BlockTypeGuid}' AND ISNULL([Path], '') <> '{BlockPath}')
    OR EXISTS (SELECT 1 FROM [BlockType] WHERE [Path] = '{BlockPath}' AND [Guid] <> '{BlockTypeGuid}')
    THROW 51000, 'Wi-Fi Presence block type GUID and path do not match. Resolve the registration conflict before retrying.', 1;
" );

            // Rock may have already registered the source block during manual testing.
            RockMigrationHelper.UpdateBlockType( "Wi-Fi Presence Captive Portal",
                "Controls access to Wi-Fi.", BlockPath, "Plugins > Wi-Fi Presence", BlockTypeGuid );

            var pageExists = Convert.ToInt32( SqlScalar(
                $"SELECT COUNT(*) FROM [Page] WHERE [Guid] = '{PageGuid}'" ) ) != 0;

            RockMigrationHelper.AddPage( true, "", LayoutGuid, "Wi-Fi Connect (Plugin)",
                "Wi-Fi guest registration. Supply client_mac and fppostback in the incoming URL.",
                PageGuid, "ti ti-wifi" );

            if ( !pageExists )
            {
                Sql( $@"UPDATE [Page] SET [ForeignKey] = '{Owner}', [IsSystem] = 0,
                    [DisplayInNavWhen] = 2, [PageDisplayTitle] = 0, [PageDisplayBreadCrumb] = 0,
                    [OutputCacheDuration] = 0 WHERE [Guid] = '{PageGuid}';" );
                // Public VIEW only. Administrative rights continue to use Rock's existing rules.
                RockMigrationHelper.AddSecurityAuthForPage( PageGuid, 0, "View", true, null,
                    1, PageViewAuthGuid ); // SpecialRole.AllUsers = 1 in Rock v19.
            }

            var blockExists = Convert.ToInt32( SqlScalar(
                $"SELECT COUNT(*) FROM [Block] WHERE [Guid] = '{BlockGuid}'" ) ) != 0;

            RockMigrationHelper.AddBlock( true, PageGuid, "", BlockTypeGuid,
                "Wi-Fi Presence Captive Portal", "Main", "", "", 0, BlockGuid );

            if ( !blockExists )
            {
                Sql( $@"UPDATE [Block] SET [ForeignKey] = '{Owner}', [IsSystem] = 0,
                    [OutputCacheDuration] = 0 WHERE [Guid] = '{BlockGuid}';" );
                RockMigrationHelper.AddSecurityAuthForBlock( BlockGuid, 0, "View", true, null,
                    Rock.Model.SpecialRole.AllUsers, BlockViewAuthGuid );
            }

            var routeExists = Convert.ToInt32( SqlScalar(
                $"SELECT COUNT(*) FROM [PageRoute] WHERE [Guid] = '{RouteGuid}'" ) ) != 0;
            if ( !routeExists )
            {
                RockMigrationHelper.AddOrUpdatePageRoute( PageGuid, "wificonnect-plugin", RouteGuid );
                Sql( $"UPDATE [PageRoute] SET [ForeignKey] = '{Owner}', [IsSystem] = 0 WHERE [Guid] = '{RouteGuid}';" );
            }
            // Existing block settings and edited page/route/security properties survive a rerun.
            // The release URL is supplied by each inbound fppostback query parameter, not a block setting.
        }

        public override void Down()
        {
            // Rollback must not cascade into pages or blocks that administrators added later.
            Sql( $@"
IF EXISTS (SELECT 1 FROM [Page] WHERE [Guid] = '{PageGuid}' AND ISNULL([ForeignKey], '') <> '{Owner}')
    OR EXISTS (SELECT 1 FROM [Block] WHERE [Guid] = '{BlockGuid}' AND ISNULL([ForeignKey], '') <> '{Owner}')
    OR EXISTS (SELECT 1 FROM [PageRoute] WHERE [Guid] = '{RouteGuid}' AND ISNULL([ForeignKey], '') <> '{Owner}')
    THROW 51000, 'Wi-Fi Presence ownership changed; remove the installation manually.', 1;

DECLARE @PageId INT = (SELECT [Id] FROM [Page] WHERE [Guid] = '{PageGuid}');
IF EXISTS (SELECT 1 FROM [Page] WHERE [ParentPageId] = @PageId)
    OR EXISTS (SELECT 1 FROM [Block] WHERE [PageId] = @PageId AND [Guid] <> '{BlockGuid}')
    OR EXISTS (SELECT 1 FROM [PageRoute] WHERE [PageId] = @PageId AND [Guid] <> '{RouteGuid}')
    THROW 51000, 'Wi-Fi Presence page has additional content. Move that content before rollback.', 1;
" );
            RockMigrationHelper.DeleteSecurityAuth( BlockViewAuthGuid );
            RockMigrationHelper.DeleteSecurityAuth( PageViewAuthGuid );
            RockMigrationHelper.DeleteBlock( BlockGuid );
            Sql( $"DELETE FROM [PageRoute] WHERE [Guid] = '{RouteGuid}' AND [ForeignKey] = '{Owner}';" );
            RockMigrationHelper.DeletePage( PageGuid );
            // Keep block-type registration: other pages may use it, or it may predate this installer.
            // PersonalDevice, Person and Interaction records are never removed by this migration.
        }
    }
}
