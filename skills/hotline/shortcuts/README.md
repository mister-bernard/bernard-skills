# iOS Shortcut Setup

## Manual Setup Steps

1. Open **Shortcuts** app on iPhone
2. Tap **+** to create new shortcut
3. Add these actions in order:

### Action 1: Record Audio
- **Search**: "Record Audio"
- **Add action**: Record Audio
- **Settings**: 
  - Start Recording: On Tap
  - Finish Recording: On Tap
  - Audio Quality: Normal (or High for better quality)

### Action 2: Get Current Location
- **Search**: "Get Current Location"
- **Add action**: Get Current Location

### Action 3: Get Contents of URL
- **Search**: "Get Contents of URL"
- **Add action**: Get Contents of URL
- **Settings**:
  - URL: `https://YOUR_DOMAIN.com/voice`
  - Method: `POST`
  - Headers:
    - `Authorization`: `Bearer YOUR_API_KEY`
    - `X-Location-Lat`: Tap "Select Variable" → **Current Location** → Latitude
    - `X-Location-Lon`: Tap "Select Variable" → **Current Location** → Longitude
  - Request Body: **File**
  - File: Tap "Select Variable" → **Recorded Audio**
  - **IMPORTANT**: Do NOT manually set Content-Type header (let iOS auto-set it)

### Action 4: Quick Look (optional, for debugging)
- **Search**: "Quick Look"
- **Add action**: Quick Look
- **Input**: Tap "Select Variable" → **Contents of URL**

### Action 5: Name the Shortcut
- Tap shortcut name at top
- Rename to "Hotline" or your preferred name

### Action 6: Add to Home Screen
- Tap the (i) info button
- Tap "Add to Home Screen"
- Choose icon (optional)
- Tap "Add"

## Configuration

Replace these values in the "Get Contents of URL" action:

- **YOUR_DOMAIN**: Your domain (e.g., `mrb.sh`)
- **YOUR_API_KEY**: Your hotline API key from `.env`

## Example Configuration

```
URL: https://YOUR_DOMAIN.com/voice
Method: POST
Headers:
  - Authorization: Bearer YOUR_HOTLINE_API_KEY
  - X-Location-Lat: <Current Location.Latitude>
  - X-Location-Lon: <Current Location.Longitude>
Request Body: File
  File: <Recorded Audio>
```

## Troubleshooting

### "Invalid form data" error
- Make sure Content-Type header is NOT manually set
- iOS should auto-detect audio format (audio/x-m4a)
- Backend accepts raw binary POST

### No GPS coordinates
- Check Location permission for Shortcuts app
- Settings → Privacy → Location Services → Shortcuts → While Using

### Quick Look shows error
- Check Authorization header matches your API key
- Verify URL is correct (https, not http)
- Check backend is running (`journalctl --user -u mrb-sh -f`)

## Testing

1. Open Shortcuts app
2. Tap your "Hotline" shortcut
3. Tap to start recording
4. Speak your message
5. Tap to stop recording
6. Wait for response in Telegram

## Permissions Required

- **Microphone**: Required for audio recording
- **Location**: Required for GPS coordinates
- **Network**: Required to send to server

Grant these when prompted on first run.
