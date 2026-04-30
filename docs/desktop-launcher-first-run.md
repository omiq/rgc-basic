# Desktop launcher — first-run instructions

**Audience:** End users who downloaded the RGC-BASIC desktop launcher
(`.app`, `.exe`, `.AppImage`, or `.deb`) from the online IDE.

The launcher is **unsigned** to keep it free. Each OS shows a one-time
warning on first launch. After the first bypass it runs normally.

---

## macOS

Launcher files: `RGC-BASIC.dmg` (contains `RGC-BASIC.app`).

**First launch:**

1. Open the `.dmg`. Drag `RGC-BASIC.app` to `Applications` (or anywhere).
2. **Right-click** (or Control-click) the app → **Open**.
3. Dialog says "macOS cannot verify the developer." Click **Open**.
4. App launches. Future double-clicks work normally.

**If the right-click → Open trick is blocked (macOS Sequoia 15+):**

Open Terminal and run:

```bash
xattr -dr com.apple.quarantine /Applications/RGC-BASIC.app
```

Replace path if you put the app elsewhere. Then double-click as normal.

**Alternative path via System Settings:**

1. Double-click the app — it gets blocked.
2. Open **System Settings → Privacy & Security**.
3. Scroll to "RGC-BASIC was blocked…" → click **Open Anyway**.
4. Confirm.

---

## Windows

Launcher files: `RGC-BASIC-setup.exe` (NSIS installer) or `RGC-BASIC.msi`.

**First launch:**

1. Double-click the installer. SmartScreen shows
   "Windows protected your PC."
2. Click **More info**.
3. Click **Run anyway**.
4. Installer proceeds. Launches RGC-BASIC from Start Menu after install.

**WebView2 runtime:**

Windows 10 21H2+ and all Windows 11 ship WebView2. Older Windows 10 prompts
to install the WebView2 bootstrapper on first launch — accept the prompt.

**Antivirus false positives:**

Rare on unsigned binaries. If your AV blocks the installer, whitelist the
file or download fresh from the IDE. The installer only writes to its own
install dir; it does not modify system files outside that.

---

## Linux

### AppImage (recommended — portable, no install)

1. Download `RGC-BASIC.AppImage`.
2. Make executable:
   ```bash
   chmod +x RGC-BASIC.AppImage
   ```
3. Run:
   ```bash
   ./RGC-BASIC.AppImage
   ```

WebKitGTK is bundled — no system dependency required.

### `.deb` (Debian / Ubuntu)

1. Download `rgc-basic_0.1.0_amd64.deb`.
2. Install:
   ```bash
   sudo dpkg -i rgc-basic_0.1.0_amd64.deb
   sudo apt install -f      # if missing-dep errors appear
   ```
3. Launch from your application menu, or run `rgc-basic` in a terminal.

`.deb` requires `libwebkit2gtk-4.1-0` on the system. Most modern Ubuntu /
Debian have it; `apt install -f` pulls it in if not.

### Other distros

Use the AppImage. Works on any glibc-based x86_64 distro (Fedora, Arch,
openSUSE, etc.).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Black window on launch | WebGL2 not available in system webview | Update OS / WebView2 (Windows) / WebKitGTK (Linux ≥ 2.36) |
| "App is damaged" on macOS | Sequoia quarantine | `xattr -dr com.apple.quarantine /path/to/RGC-BASIC.app` |
| No sound | WebAudio blocked or muted | Click inside the window once to give it audio focus |
| `HTTPFETCH` fails on remote URL | Remote site missing CORS headers | Same constraint as the browser web export — server must send `Access-Control-Allow-Origin` |
| Window too small / large | Default 800×600 | Resize manually; saved-state-on-quit not implemented in v1 |

If the program runs in the IDE preview but not in the desktop launcher,
report the issue with the BASIC source and OS/version — likely a
webview-specific WebGL or audio quirk.

---

## Why unsigned?

Code-signing certs cost ~$99/yr (macOS) and $200–500/yr (Windows EV). For a
free hobbyist tool, that overhead is hard to justify until usage justifies
it. The bypass is one click per OS per binary — annoying once, fine forever
after. If this becomes a problem in practice, signing will be added; track
progress in [`docs/tauri-desktop-launcher-spec.md`](tauri-desktop-launcher-spec.md)
M4.
