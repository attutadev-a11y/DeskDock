# DeskDock 🖥

**Samsung DeX-style desktop for iPhone.** Plug your iPhone 17 Pro into an external monitor and, instead of mirroring, DeskDock takes over the display and turns it into a desktop: draggable/resizable windows, a taskbar, a mouse cursor — with your phone screen acting as the trackpad and keyboard.

Built-in desktop apps:

| App | What it does |
|---|---|
| **Code** | Monospaced code editor + built-in JavaScript engine (JavaScriptCore). Press **▶ Run** and `console.log` output appears in the console pane. Your code auto-saves to `main.js`. |
| **Browser** | Full web browser (WKWebView) with URL/search bar, back/forward/reload. |
| **Notes** | Simple auto-saving notepad. |

## What it is (and isn't)

iOS sandboxing means **no third-party app can put *other* iOS apps into windows** — only Apple can ship a true system-wide DeX. What apps *can* do (and DeskDock does) is claim the external display as a separate, non-mirrored screen and render their own desktop environment on it. So everything on the monitor lives inside DeskDock.

## Requirements

- iPhone with USB-C (15 Pro or later for DisplayPort out — your 17 Pro is perfect) + a USB-C→HDMI/DisplayPort cable or adapter
- iOS 17+ (works on the iOS 27 beta)
- **Developer Mode** enabled on the phone: Settings → Privacy & Security → Developer Mode

## Installing without the App Store

### Option A — you can borrow any Mac
1. Install Xcode, then `brew install xcodegen`.
2. In this folder: `xcodegen generate`, open `DeskDock.xcodeproj`.
3. Signing & Capabilities → Team → add your (free) Apple ID → pick the auto-created Personal Team.
4. Plug in the iPhone, press Run.

Free-account apps expire after **7 days** — re-run from Xcode to refresh. A paid ($99/yr) developer account signs for 1 year.

### Option B — no Mac at all (Windows + GitHub + AltStore)
1. Push this folder to a GitHub repo. The included workflow (`.github/workflows/build-ipa.yml`) builds an **unsigned `DeskDock.ipa`** on GitHub's Mac runners — download it from the repo's **Actions** tab → latest run → Artifacts (unzip the artifact to get the .ipa).
2. On your PC, install **AltServer** (altstore.io) — it needs iTunes + iCloud installed from Apple's website (not the Microsoft Store versions). [SideStore](https://sidestore.io) is an alternative that doesn't need the PC after setup.
3. Install AltStore to your iPhone via AltServer, then open the `.ipa` with AltStore → it re-signs it with your free Apple ID and installs it.
4. Trust the app: Settings → General → VPN & Device Management.

Free Apple ID limits: max **3 sideloaded apps**, **7-day** signing (AltStore auto-refreshes over Wi-Fi when AltServer is running).

> ⚠️ **iOS beta caveat:** AltServer/SideStore pairing sometimes lags behind new iOS betas. If installation fails on the iOS 27 beta, check their Discord/releases for a beta-compatible build.

## Using it

1. Open DeskDock on the phone, then plug the monitor in. The monitor switches from mirroring to the DeskDock desktop.
2. The phone becomes the trackpad:

| Gesture (on phone) | Action (on monitor) |
|---|---|
| 1-finger drag | Move cursor |
| Tap | Click |
| Long-press, then drag | Move a window (grab anywhere) / resize (grab the ◢ corner) |
| 2-finger drag | Scroll |
| Tap the ⌨️ bar | Toggles the keyboard on/off — everything you type goes to whatever you last clicked on the monitor |

A Bluetooth keyboard paired to the iPhone also works — tap the ⌨️ bar once and type away.

**Keep DeskDock in the foreground and the phone unlocked** — if the app backgrounds or the phone locks, iOS tears down the external display scene and the monitor goes back to mirroring. DeskDock disables auto-lock while it's open.

## Known limitations

- Typing into web pages is basic (works for simple inputs; complex web editors won't). The URL bar always works.
- No text selection/copy-paste on the desktop yet.
- JavaScript only in the Code app for now (Python would require embedding CPython — doable later). Scripts are killed after 5 seconds so an infinite loop can't hang the app.

## Project layout

```
project.yml                  XcodeGen spec (generates DeskDock.xcodeproj)
DeskDock/
  AppDelegate.swift          Routes scenes: phone → trackpad, monitor → desktop
  Desk.swift                 Shared hub linking the two scenes
  PhoneScene.swift           Trackpad + keyboard-capture UI on the phone
  DesktopScene.swift         External display scene delegate
  DesktopViewController.swift  Desktop: wallpaper, taskbar, cursor, window manager
  DeskWindow.swift           Window chrome (title bar, close, resize grip)
  Apps.swift                 Code editor + JS runner, Browser, Notes
.github/workflows/build-ipa.yml  Cloud build → unsigned IPA artifact
```
