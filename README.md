# DeskFree

**A free, open-source "desktop in your pocket" for iPhone.**
Floating, resizable windows, a Dock, desktop search, a browser, a file manager, a PDF annotator and a video editor — and when you plug in a bigger screen, your phone turns into a trackpad and keyboard.

> 🇮🇹 **In breve:** un'app iPhone gratuita e open source che porta un vero desktop a finestre sull'iPhone (menu bar, Dock, finestre mobili e ridimensionabili, ricerca, browser, file, PDF, editor video) e, collegando uno schermo esterno, trasforma l'iPhone in trackpad + tastiera. Istruzioni per compilarla e installarla sono qui sotto.

DeskFree is an **independent project**. It is inspired by the idea behind "iPhone desktop" apps, but it is written from scratch: no code, artwork, icons or text from any commercial app are used, and it is not affiliated with or endorsed by any of them.

---

## Features

| | |
|---|---|
| **Desktop shell** | Menu bar with clock/battery, frosted Dock with running indicators, wallpapers (6 built-in + your own photo) |
| **Windows** | Drag by the title bar, resize from any edge or corner, minimise to the Dock, maximise (button or double-tap the title bar), click-to-focus stacking |
| **Search** | Spotlight-style search for apps, open windows, files in *Documents*, quick maths (`12*(3+4)`), web search or a URL |
| **Browser** | WebKit, desktop-class sites, tabs, address bar with search, progress bar, favourites page |
| **Files** | Browse the app's *Documents* (also visible in the iOS Files app), grid/list, thumbnails, import, new folder, rename, duplicate, share, delete |
| **PDF Studio** | PDFKit viewer with page thumbnails; highlight, underline, strikethrough, freehand pen, text, eraser, undo; save / save a copy / share |
| **Video Editor** | Import from Files or Photos, timeline with thumbnails, trim handles, speed (0.5–2×), filters, mute, 720p/1080p/best export to *Documents/Exports* |
| **Notes** | Multiple notes, search, autosave |
| **Calculator** | Expressions with parentheses, powers, percent, √ and π |
| **Big screen mode** | Plug in a display over USB-C / HDMI / AirPlay: the desktop appears on it at up to 2560 × 1440 and the iPhone becomes a trackpad (move, tap-to-click, hold-and-move to drag, two-finger scroll) with a keyboard and quick actions |
| **Portrait trackpad layout** | In portrait the phone shows a live preview of the desktop above a trackpad, so you can explore the workspace without any display |

Landscape without a display gives you the same desktop directly under your fingers.

## Build it

You need a Mac with **Xcode 16 or later** (iOS 17+ deployment target).

```bash
brew install xcodegen
git clone https://github.com/simocc99/DeskOs-free.git
cd DeskOs-free
xcodegen generate        # creates DeskFree.xcodeproj from project.yml
open DeskFree.xcodeproj
```

Select your iPhone, choose your (free) Apple ID team under *Signing & Capabilities* and press **Run**. With a free Apple ID the app expires after 7 days and must be re-installed.

Run the unit tests with `⌘U`, or from the command line:

```bash
xcodebuild test -project DeskFree.xcodeproj -scheme DeskFree \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### No Mac? Use the CI build

Every push to `main` is built by GitHub Actions. The workflow uploads **`DeskFree-unsigned.ipa`** as a build artifact (Actions → latest run → *Artifacts*). Unsigned IPAs can be installed with sideloading tools such as AltStore or Sideloadly, which sign the app with your own Apple ID.

## Using it

- **Open an app:** tap its Dock icon. Tap the icon of the front app again to minimise it; minimised windows live at the right of the Dock.
- **Move / resize:** drag the title bar; drag any edge or corner.
- **Maximise:** green button, or double-tap the title bar.
- **Search:** magnifier in the menu bar.
- **Files:** put files in *DeskFree* via the iOS Files app, or use *Import Files…*. Double-tap a PDF or video to open it in the right tool.
- **Big screen:** connect a display. The desktop moves to it and the phone shows the trackpad. **Touch** switches back to driving the desktop with your fingers; **Keyboard** opens the iOS keyboard and sends your typing to the search box, the browser address bar, Notes or the Calculator; **Desktop** minimises/restores every window.

## Project layout

```
project.yml                 XcodeGen spec (the .xcodeproj is generated, not committed)
Sources/DeskFree/
  Core/    window manager, Dock geometry, pointer hit-testing, search, settings, session
  Shell/   menu bar, Dock, window chrome, Spotlight, trackpad, root views
  Apps/    Browser, Files, PDF, Video, Notes, Calculator, Settings
  App/     entry point and the external-display scene
Tests/DeskFreeTests/        unit tests for the logic above
.github/workflows/ios.yml   build + test on a macOS runner, unsigned IPA artifact
```

The window manager, Dock layout and pointer hit-testing are plain value-based Swift with no UIKit dependency, so the trackpad pointer and the touch UI always agree on what is clickable.

## Known limitations (v0.1)

- **Not yet tested on a physical external display.** The external-display scene follows Apple's documented API, but it has only been built and unit-tested in CI. Please open an issue with your findings.
- With the desktop on a big screen, the **pointer can move/resize/close windows, use the Dock and search, and click and scroll inside the Browser**, and scroll PDFs. Clicking inside other apps' content (Files, Video timeline, …) needs the **Touch** button for now.
- System pickers (file importer, Photos, share sheet) are always shown on the phone.
- iPhone only; no iPad layout yet.

## Roadmap

- Pointer clicks everywhere (accessibility-based activation) and right-click
- Keyboard shortcuts for hardware keyboards
- Window snapping by dragging to screen edges, multiple desktops
- Drag and drop between windows, more apps (Terminal, Image viewer, Clipboard history)

## Contributing

Issues and pull requests are welcome. Please keep new logic testable (see `Tests/`) and make sure `xcodebuild test` passes.

## License

[MIT](LICENSE)
