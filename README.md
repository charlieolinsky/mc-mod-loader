# `mc_mod_loader`

A tiny, portable installer for a **one-command Aether setup** using the **official Minecraft Launcher**.

## Current target

- **Minecraft:** `1.21.1`
- **Loader:** `Fabric 0.19.1`
- **Main mod:** `The Aether 1.21.1-1.5.11-fabric`
- **Required deps:** `Fabric API`, `oωo-lib` (`Accessories` and `Cumulus` are embedded by `Aether`)

The installer creates a separate launcher profile named **`Aether Friends`** and keeps the mod files isolated in their own game directory.

---

## macOS: install on this machine

Run from this repo:

```bash
bash ./install/install-aether.sh
```

Dry-run first if you want to inspect what it will use:

```bash
bash ./install/install-aether.sh --dry-run
```

---

## Windows: install on a friend’s machine

From PowerShell inside the repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\install\install-aether.ps1
```

---

## What the installer does

1. Detects the official `.minecraft` folder
2. Backs up `launcher_profiles.json`
3. Installs the pinned `Fabric` loader for `1.21.1`
4. Downloads the pinned mod jars from official Modrinth CDNs
5. Creates/updates a dedicated launcher profile: `Aether Friends`

---

## Notes

- The **official Minecraft Launcher must already be installed and opened once**.
- On macOS, the script can use the launcher’s **bundled Java runtime**, so your friends should not need to install Java separately in the common case.
- For later sharing as a true one-liner, push this repo to GitHub and use a raw-file install URL.

Example shape after you publish it:

```bash
curl -fsSL <raw-install-script-url> | bash -s -- --manifest <raw-manifest-url>
```

---

## Files

- `install/install-aether.sh` — macOS installer
- `install/install-aether.ps1` — Windows installer
- `manifests/aether-fabric-1.21.1.json` — pinned pack definition
