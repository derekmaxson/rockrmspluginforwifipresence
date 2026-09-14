-- Read-only validation; execute against the Rock test database after installation.
DECLARE @PageGuid UNIQUEIDENTIFIER = 'D41AE879-39AE-4230-A894-0F561F7F7BA7';
DECLARE @BlockGuid UNIQUEIDENTIFIER = '3FDF5FCB-1F2E-4799-902A-A0CE2F33953F';
DECLARE @BlockTypeGuid UNIQUEIDENTIFIER = 'B31D5874-C9CE-48AB-B3B7-0B94C352A495';
DECLARE @RouteGuid UNIQUEIDENTIFIER = '5AA58179-6279-4976-BF48-6C2BA2EC54AB';

SELECT p.[Id], p.[InternalName], s.[Name] AS [Site], l.[Name] AS [Layout],
       p.[DisplayInNavWhen], p.[OutputCacheDuration], r.[Route],
       b.[Name] AS [Block], b.[Zone], bt.[Path] AS [BlockPath]
FROM [Page] p
JOIN [Layout] l ON l.[Id] = p.[LayoutId]
JOIN [Site] s ON s.[Id] = l.[SiteId]
LEFT JOIN [PageRoute] r ON r.[PageId] = p.[Id]
LEFT JOIN [Block] b ON b.[PageId] = p.[Id]
LEFT JOIN [BlockType] bt ON bt.[Id] = b.[BlockTypeId]
WHERE p.[Guid] = @PageGuid;

SELECT
    (SELECT COUNT(*) FROM [Page] WHERE [Guid] = @PageGuid) AS [ExpectedOnePage],
    (SELECT COUNT(*) FROM [Block] b JOIN [Page] p ON p.[Id] = b.[PageId]
     JOIN [BlockType] bt ON bt.[Id] = b.[BlockTypeId]
     WHERE b.[Guid] = @BlockGuid AND p.[Guid] = @PageGuid
       AND bt.[Guid] = @BlockTypeGuid AND b.[Zone] = 'Main') AS [ExpectedOnePlacedBlock],
    (SELECT COUNT(*) FROM [PageRoute] r JOIN [Page] p ON p.[Id] = r.[PageId]
     WHERE r.[Guid] = @RouteGuid AND p.[Guid] = @PageGuid) AS [ExpectedOnePageRoute];

SELECT et.[Name] AS [EntityType], a.[EntityId], a.[Action], a.[AllowOrDeny], a.[SpecialRole]
FROM [Auth] a JOIN [EntityType] et ON et.[Id] = a.[EntityTypeId]
WHERE a.[Guid] IN ('46B8F14F-C23D-4CA9-835D-AEAB9A25588D', '623A5702-63FD-4964-AD77-1F6976A5B5CF');
