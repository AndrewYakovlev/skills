param(
    [ValidateSet("Codex", "Claude", "Both")]
    [string]$Target = "Both",

    [string]$Source = (Join-Path (Split-Path -Parent $PSScriptRoot) "skills"),

    [string]$DestinationRoot = [Environment]::GetFolderPath("UserProfile")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Source)) {
    throw "Skills source folder not found: $Source"
}

function Copy-Skills {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    Get-ChildItem -LiteralPath $Source -Directory | ForEach-Object {
        $targetPath = Join-Path $Destination $_.Name
        New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
        Copy-Item -Path (Join-Path $_.FullName "*") -Destination $targetPath -Recurse -Force
        Write-Host "Installed $($_.Name) -> $targetPath"
    }
}

if ($Target -eq "Codex" -or $Target -eq "Both") {
    Copy-Skills -Destination (Join-Path $DestinationRoot ".codex\skills")
}

if ($Target -eq "Claude" -or $Target -eq "Both") {
    Copy-Skills -Destination (Join-Path $DestinationRoot ".claude\skills")
}
