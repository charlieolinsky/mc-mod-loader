# Install the pinned Aether pack into a dedicated official-launcher profile on Windows.
# Like the macOS script, this keeps the setup isolated and safe to re-run.
param(
    [string]$ManifestPath,
    [string]$ManifestUrl,
    [string]$MinecraftDir = "$env:APPDATA\.minecraft",
    [string]$ProfileName,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Info($Message) {
    Write-Host "[aether-installer] $Message"
}

function Fail($Message) {
    throw "[aether-installer] $Message"
}

# Allow the installer to work from either a local repo checkout or a hosted raw URL.
function Resolve-ManifestFile {
    param(
        [string]$ManifestPath,
        [string]$ManifestUrl,
        [string]$DefaultManifest
    )

    if ($ManifestUrl) {
        $tempManifest = Join-Path ([System.IO.Path]::GetTempPath()) 'aether-manifest.json'
        Invoke-WebRequest -Uri $ManifestUrl -OutFile $tempManifest
        return $tempManifest
    }

    if ($ManifestPath) {
        return $ManifestPath
    }

    return $DefaultManifest
}

# Prefer the Java runtime bundled by the official launcher before falling back
# to a system-wide Java install.
function Get-JavaPath {
    param([string]$MinecraftDir)

    $bundled = Get-ChildItem -Path (Join-Path $MinecraftDir 'runtime') -Filter javaw.exe -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($bundled) {
        return $bundled
    }

    $cmd = Get-Command javaw.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $cmd = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    Fail 'Could not find Java. Open the official Minecraft Launcher once first, or install Java.'
}

function Verify-Sha1 {
    param(
        [string]$Path,
        [string]$Expected
    )

    $actual = (Get-FileHash -Path $Path -Algorithm SHA1).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        Fail "Checksum mismatch for $(Split-Path $Path -Leaf): expected $Expected, got $actual"
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$defaultManifest = Join-Path $scriptDir '..\manifests\aether-fabric-1.21.1.json'
$manifestFile = Resolve-ManifestFile -ManifestPath $ManifestPath -ManifestUrl $ManifestUrl -DefaultManifest $defaultManifest

if (-not (Test-Path $manifestFile)) {
    Fail "Manifest not found: $manifestFile"
}

if (-not (Test-Path $MinecraftDir)) {
    Fail "Minecraft directory not found: $MinecraftDir"
}

$launcherProfiles = Join-Path $MinecraftDir 'launcher_profiles.json'
if (-not (Test-Path $launcherProfiles)) {
    Fail 'launcher_profiles.json not found. Open the official Minecraft Launcher once before running this.'
}

$manifest = Get-Content -Path $manifestFile -Raw | ConvertFrom-Json
if (-not $ProfileName) {
    $ProfileName = $manifest.profileName
}

$instanceDir = Join-Path $MinecraftDir $manifest.instanceDirName
$modsDir = Join-Path $instanceDir 'mods'
$shaderpacksDir = Join-Path $instanceDir 'shaderpacks'
$fabricVersionId = "fabric-loader-$($manifest.loader.version)-$($manifest.minecraftVersion)"
$javaPath = Get-JavaPath -MinecraftDir $MinecraftDir

Write-Info "Pack: $($manifest.name)"
Write-Info "Minecraft dir: $MinecraftDir"
Write-Info "Instance dir: $instanceDir"
Write-Info "Java: $javaPath"

# In dry-run mode we stop after validating the environment and manifest contents.
if ($DryRun) {
    Write-Info 'Dry run complete. No files were changed.'
    exit 0
}

# Create the isolated instance directory and back up launcher configuration first.
New-Item -ItemType Directory -Force -Path $modsDir, $shaderpacksDir | Out-Null
$backupDir = Join-Path $MinecraftDir 'copilot-backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -Path $launcherProfiles -Destination (Join-Path $backupDir "launcher_profiles.$timestamp.json")

$installerVersion = ((Invoke-RestMethod -Uri 'https://meta.fabricmc.net/v2/versions/installer')[0]).version
$installerJar = Join-Path ([System.IO.Path]::GetTempPath()) "fabric-installer-$installerVersion.jar"
Invoke-WebRequest -Uri "https://maven.fabricmc.net/net/fabricmc/fabric-installer/$installerVersion/fabric-installer-$installerVersion.jar" -OutFile $installerJar

# Install the pinned Fabric loader into the user's normal official-launcher directory.
Write-Info "Installing Fabric loader $($manifest.loader.version) for Minecraft $($manifest.minecraftVersion)"
& $javaPath -jar $installerJar client -dir $MinecraftDir -mcversion $manifest.minecraftVersion -loader $manifest.loader.version -noprofile | Out-Null

# Download or refresh each mod defined in the manifest, removing stale versions by slug.
foreach ($mod in $manifest.mods) {
    Get-ChildItem -Path $modsDir -Filter "$($mod.slug)*.jar" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $mod.filename } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $destination = Join-Path $modsDir $mod.filename
    $needsDownload = $true
    if (Test-Path $destination) {
        $currentSha = (Get-FileHash -Path $destination -Algorithm SHA1).Hash.ToLowerInvariant()
        if ($currentSha -eq $mod.sha1.ToLowerInvariant()) {
            Write-Info "Already up to date: $($mod.name)"
            $needsDownload = $false
        }
    }

    if ($needsDownload) {
        Write-Info "Downloading $($mod.name)"
        Invoke-WebRequest -Uri $mod.url -OutFile $destination
        Verify-Sha1 -Path $destination -Expected $mod.sha1
    }
}

# Also install a few pinned shader packs so friends can enable one immediately in-game.
foreach ($shaderpack in @($manifest.shaderpacks)) {
    if (-not $shaderpack) {
        continue
    }

    Get-ChildItem -Path $shaderpacksDir -Filter "$($shaderpack.slug)*.zip" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $shaderpack.filename } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $destination = Join-Path $shaderpacksDir $shaderpack.filename
    $needsDownload = $true
    if (Test-Path $destination) {
        $currentSha = (Get-FileHash -Path $destination -Algorithm SHA1).Hash.ToLowerInvariant()
        if ($currentSha -eq $shaderpack.sha1.ToLowerInvariant()) {
            Write-Info "Already up to date: $($shaderpack.name)"
            $needsDownload = $false
        }
    }

    if ($needsDownload) {
        Write-Info "Downloading $($shaderpack.name)"
        Invoke-WebRequest -Uri $shaderpack.url -OutFile $destination
        Verify-Sha1 -Path $destination -Expected $shaderpack.sha1
    }
}

# Update the launcher profile so the user can select the prepared instance immediately.
$profilesJson = Get-Content -Path $launcherProfiles -Raw | ConvertFrom-Json
$profileObject = [pscustomobject]@{
    created       = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    gameDir       = $instanceDir
    icon          = 'Grass'
    lastUsed      = '1970-01-01T00:00:00.000Z'
    lastVersionId = $fabricVersionId
    name          = $ProfileName
    type          = 'custom'
}

$profilesJson.profiles | Add-Member -NotePropertyName $ProfileName -NotePropertyValue $profileObject -Force
$profilesJson | ConvertTo-Json -Depth 10 | Set-Content -Path $launcherProfiles -Encoding UTF8

Write-Info "Done. Open the Minecraft Launcher and select the '$ProfileName' profile."
Write-Info "Your Aether mods live in: $modsDir"
Write-Info "Default shader packs live in: $shaderpacksDir"
Write-Info 'In-game: Options -> Video Settings -> Shaders, then choose one of the installed packs.'
