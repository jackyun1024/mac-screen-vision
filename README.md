# screen-vision

macOS screen OCR & click automation CLI powered by Apple Vision framework.

Capture any window or screen region, extract text with coordinates, and optionally click on recognized text — all from the terminal.

## Features

- **OCR** — Extract all text from screen as structured JSON with coordinates
- **Find** — Locate specific text and get its screen coordinates
- **Tap** — Find text and click on it automatically
- **List** — Human-readable OCR output sorted by position

## Requirements

- macOS 14.0+ (Sonoma)
- Screen Recording permission (System Settings > Privacy > Screen Recording)
- [cliclick](https://github.com/BlueM/cliclick) for `tap` command: `brew install cliclick`

## Install

```bash
git clone https://github.com/jackyun1024/mac-screen-vision.git
cd mac-screen-vision
swift build -c release
cp .build/release/screen-vision /usr/local/bin/
```

## Usage

```
screen-vision <command> [options]
```

### Commands

| Command | Description | Output |
|---------|-------------|--------|
| `ocr`   | Full OCR    | JSON array of `{text, x, y, w, h, confidence}` |
| `list`  | OCR list    | Human-readable text with coordinates |
| `find "text"` | Find text | JSON `{text, x, y, found}` |
| `tap "text"`  | Find + click | JSON `{text, x, y, tapped}` |

### Options

| Option | Description |
|--------|-------------|
| `--app NAME` | Target a specific app window by name |
| `--region x,y,w,h` | Capture a specific screen region |

### Capture Priority

```
--region  >  --app window  >  full screen (default)
```

If no options are given, captures the entire main screen.

## Examples

```bash
# OCR the full screen
screen-vision list

# OCR a specific app window
screen-vision list --app "Safari"

# Find text in an app
screen-vision find "Submit" --app "Chrome"

# Click on text anywhere on screen
screen-vision tap "OK"

# OCR a specific screen region (x, y, width, height)
screen-vision ocr --region 100,200,800,600

# Pipe JSON output to jq
screen-vision ocr --app "Finder" | jq '.[].text'
```

## Output Format

### `ocr` — JSON array

```json
[
  {
    "text": "Hello World",
    "x": 540,
    "y": 320,
    "w": 120,
    "h": 18,
    "confidence": 1.0
  }
]
```

### `find` / `tap` — JSON object

```json
{
  "text": "Submit",
  "x": 640,
  "y": 480,
  "found": true
}
```

## How It Works

1. Captures the target (screen region / app window / full screen) via `CGWindowListCreateImage`
2. Runs Apple Vision `VNRecognizeTextRequest` with accurate recognition (Korean + English)
3. Converts Vision normalized coordinates to screen coordinates
4. For `tap`: uses [cliclick](https://github.com/BlueM/cliclick) to perform the click

## License

MIT
