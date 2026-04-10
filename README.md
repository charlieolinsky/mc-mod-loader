# `mc-mod-loader`

A lightweight, shareable installer for getting **`The Aether`** running on the **official Minecraft Launcher** with as little setup as possible.

> **Current pinned pack:** `Minecraft 1.21.1` + `Fabric 0.19.1` + `The Aether 1.5.11` + `Iris 1.8.8` + `Sodium 0.6.13`

This project is built for the simple use case: send a friend **one command**, have them run it, and get everyone onto the same tested mod setup.

> **Disclaimer:** This repository and installer were AI-assisted/generated and should be reviewed and used at your own discretion.

## Features

- ✅ One-command install flow for the **official launcher**
- ✅ Creates a separate launcher profile: `Aether Friends`
- ✅ Keeps mod files isolated in their own game directory
- ✅ Backs up `launcher_profiles.json` before changing anything
- ✅ Downloads mods and shader packs from official **Modrinth** sources at install time
- ✅ Includes `Iris Shaders`, `Sodium`, and 3 optional shader packs by default
- ✅ **macOS verified** on a real machine
- ⚠️ **Windows script included**, but not yet end-to-end verified on a Windows machine

---

## Quick start

### macOS one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/charlieolinsky/mc-mod-loader/main/install/install-aether.sh | bash -s -- --manifest https://raw.githubusercontent.com/charlieolinsky/mc-mod-loader/main/manifests/aether-fabric-1.21.1.json
```

### Windows PowerShell one-liner

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/charlieolinsky/mc-mod-loader/main/install/install-aether.ps1 -UseBasicParsing -OutFile $env:TEMP\install-aether.ps1; & $env:TEMP\install-aether.ps1 -ManifestUrl https://raw.githubusercontent.com/charlieolinsky/mc-mod-loader/main/manifests/aether-fabric-1.21.1.json"
```

### Run from a local clone

```bash
bash ./install/install-aether.sh
```

Dry-run:

```bash
bash ./install/install-aether.sh --dry-run
```

---

## What gets installed

### Mods

- `The Aether 1.21.1-1.5.11-fabric`
- `Fabric API 0.116.10+1.21.1`
- `oωo-lib 0.12.15.4+1.21`
- `Sodium 0.6.13+mc1.21.1`
- `Iris Shaders 1.8.8+mc1.21.1`

`Accessories` and `Cumulus` are embedded by the current `Aether` release.

### Default shader packs

- `Complementary Shaders - Unbound`
- `BSL Shaders`
- `MakeUp - Ultra Fast`

---

## Requirements

- The **official Minecraft Launcher** must already be installed
- The launcher should be opened **at least once** before running the installer
- This project currently targets the **Java Edition official launcher flow**

On macOS, the installer can usually use the launcher’s bundled Java runtime, so a separate Java install is often **not required**.

---

## What the installer changes

1. Detects the official `.minecraft` folder
2. Backs up `launcher_profiles.json`
3. Installs the pinned `Fabric` loader for `1.21.1`
4. Downloads the pinned mod jars and shader pack zips from official Modrinth CDNs
5. Creates or updates a dedicated launcher profile named `Aether Friends`

The profile uses a separate game directory, so it does **not** overwrite a normal vanilla setup.

## Using the included shaders

1. Run the installer as usual and launch the `Aether Friends` profile
2. Open `Options` → `Video Settings` → `Shaders`
3. Pick one of the included packs:
   - `Complementary Shaders - Unbound` for a high-end look
   - `BSL Shaders` for a classic popular style
   - `MakeUp - Ultra Fast` for better performance on weaker machines

> If a shader runs poorly on a friend's computer, switch to `MakeUp - Ultra Fast` or disable shaders without affecting the Aether mod setup.

---

## Public repo notes

- This project is **not affiliated with Mojang, Microsoft, Fabric, or The Aether Team**.
- The repo does **not** bundle the mod jars directly; it downloads them from official public sources during install.
- Version pinning is intentional so everyone in a group ends up on the **same tested pack**.

---

## Files

- `install/install-aether.sh` — macOS installer
- `install/install-aether.ps1` — Windows installer
- `manifests/aether-fabric-1.21.1.json` — pinned pack definition

---

## Troubleshooting

If the launcher reports missing or incompatible mods:

1. Fully close Minecraft and the launcher
2. Run the installer again
3. Make sure you launch the `Aether Friends` profile
4. If it still fails, open an issue and paste the full error output
