# Poke Desktop

Native macOS menu bar app for [Poke](https://poke.com), an AI assistant accessible via iMessage. Talk to Poke from anywhere on your Mac through a compact popover or a full slide-out panel -- no need to switch to Messages.app.

Poke Desktop reads your iMessage conversation directly from `chat.db` and sends messages through AppleScript, so it works with your existing Poke account with zero server-side setup.

## Features

- **Menu bar popover** -- click the icon for a compact voice-first interface showing the last Poke reply and a hold-to-talk button
- **Slide-out panel** -- press Cmd+Shift+P to open a full conversation view from the right edge of the screen
- **Push-to-talk** -- hold-to-talk in the popover with on-device speech recognition (Apple Speech framework)
- **Text-to-speech** -- replies are read aloud using your system Siri voice
- **Screenshot capture** -- capture a screen region and send it to Poke as an attachment
- **File attachments** -- drag-and-drop files onto the panel or use the file picker; multiple files can be staged before sending
- **Conversation history** -- scrollable message history with pagination, loaded directly from `chat.db`
- **Unread badge** -- red dot on the menu bar icon when new replies arrive while the UI is closed
- **Auto-updates** -- Sparkle framework checks for new releases on GitHub
- **Auto-launch** -- optionally starts at login via `SMAppService`

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (building from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (building from source)
- An active Poke account reachable via iMessage

## Installation

### From source

```bash
git clone https://github.com/hummusonrails/poke-desktop.git
cd poke-desktop
xcodegen generate
xcodebuild -scheme PokeDesktop -configuration Release -derivedDataPath build
```

The built app will be at `build/Build/Products/Release/PokeDesktop.app`.

### From a release

Download the latest tarball from [GitHub Releases](https://github.com/hummusonrails/poke-desktop/releases), then:

```bash
tar xzf PokeDesktop-*.tar.gz
./install.sh
```

The install script copies the app to `/Applications`, strips the quarantine attribute (prevents the "app is damaged" error for unsigned apps), and launches it.

## Permissions

Poke Desktop needs several macOS permissions to function. The app walks you through these during onboarding.

| Permission | Why | When prompted |
|---|---|---|
| **Full Disk Access** | Read `~/Library/Messages/chat.db` to load conversation history | First launch (manual grant in System Settings) |
| **Microphone** | Record audio for push-to-talk | First push-to-talk use |
| **Speech Recognition** | On-device transcription of recorded audio | First push-to-talk use |
| **Automation (Messages.app)** | Send messages and attachments via AppleScript | First message send |
| **Screen Recording** | Capture screenshots to attach | First screenshot capture |

Full Disk Access must be granted manually: System Settings > Privacy & Security > Full Disk Access, then add Poke Desktop.

## Architecture

Poke Desktop is a pure Swift/SwiftUI app that lives entirely in the menu bar (`LSUIElement = true`).

```
AppDelegate          -- NSStatusItem, global hotkey (HotKey lib), lifecycle
PopoverView          -- compact voice-first UI shown on menu bar click
PanelController      -- NSPanel slide-in/out from right edge, non-activating
PanelView            -- conversation history, composer bar, drag-and-drop
MessageStore         -- polls chat.db (SQLite, read-only) on a background queue
MessageSender        -- sends text and files via AppleScript / osascript
VoiceEngine          -- SFSpeechRecognizer (STT) + say command (TTS)
ScreenshotCapture    -- ScreenCaptureKit interactive capture
```

**Sending:** User types or speaks a message. `MessageSender` executes an AppleScript that tells Messages.app to send to the configured Poke handle.

**Receiving:** `MessageStore` polls `chat.db` every 1.5-3 seconds (adaptive -- faster right after sending), tracks a ROWID cursor, and publishes new messages to the UI.

**Poke handle selection:** During onboarding, the app scans recent iMessage conversations and asks the user to pick their Poke chat. The selected handle is stored in UserDefaults.

## Configuration

Right-click the menu bar icon for preferences:

- **Read aloud** -- toggle TTS for incoming replies
- **Launch at login** -- toggle auto-start
- **Global hotkey** -- default Cmd+Shift+P

## License

MIT
