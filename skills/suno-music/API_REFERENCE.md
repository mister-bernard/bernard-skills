# Suno API Reference

Technical documentation for the Suno API integration.

## Endpoints

### Generate Music

**POST** `https://api.sunoapi.org/api/v1/generate`

Submit a music generation request.

**Headers:**
```
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

**Request Body (Simple Mode):**
```json
{
  "customMode": false,
  "prompt": "upbeat electronic dance music",
  "instrumental": false,
  "model": "V4_5ALL",
  "callBackUrl": "https://<YOUR_DOMAIN>/api/webhook"
}
```

**Request Body (Custom Mode):**
```json
{
  "customMode": true,
  "prompt": "Verse 1: Your lyrics here...",
  "style": "rock, energetic, 90s",
  "title": "Song Title",
  "instrumental": false,
  "model": "V4_5ALL",
  "callBackUrl": "https://<YOUR_DOMAIN>/api/webhook"
}
```

**Response:**
```json
{
  "taskId": "12345-67890-abcde",
  "status": "pending"
}
```

### Poll Status

**GET** `https://api.sunoapi.org/api/v1/generate/record-info?taskId=<taskId>`

Check generation status and retrieve results.

**Headers:**
```
Authorization: Bearer YOUR_API_KEY
```

**Response (Pending):**
```json
{
  "taskId": "12345-67890-abcde",
  "status": "pending"
}
```

**Response (Processing):**
```json
{
  "taskId": "12345-67890-abcde",
  "status": "processing"
}
```

**Response (Completed):**
```json
{
  "taskId": "12345-67890-abcde",
  "status": "completed",
  "data": [
    {
      "id": "song-1-id",
      "title": "Generated Song Title 1",
      "audioUrl": "https://cdn.sunoapi.org/audio/song1.mp3",
      "imageUrl": "https://cdn.sunoapi.org/covers/song1.jpg",
      "lyrics": "Full lyrics here...",
      "style": "rock, energetic",
      "duration": 180
    },
    {
      "id": "song-2-id",
      "title": "Generated Song Title 2",
      "audioUrl": "https://cdn.sunoapi.org/audio/song2.mp3",
      "imageUrl": "https://cdn.sunoapi.org/covers/song2.jpg",
      "lyrics": "Full lyrics here...",
      "style": "rock, energetic",
      "duration": 185
    }
  ]
}
```

**Response (Failed):**
```json
{
  "taskId": "12345-67890-abcde",
  "status": "failed",
  "error": "Error message describing what went wrong"
}
```

## Parameters

### Generate Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `customMode` | boolean | Yes | `false` for simple mode, `true` for custom mode |
| `prompt` | string | Yes | Text description (simple) or lyrics (custom) |
| `style` | string | Custom only | Genre and style tags (comma-separated) |
| `title` | string | Custom only | Song title |
| `instrumental` | boolean | No | Generate instrumental (no vocals). Default: `false` |
| `model` | string | No | Model version: `V4`, `V4_5`, `V4_5ALL`, `V5`. Default: `V4_5ALL` |
| `callBackUrl` | string | Yes | Webhook URL for completion notification (required by API) |

### Models

- **V4**: Original Suno v4 model
- **V4_5**: Enhanced v4.5 model
- **V4_5ALL**: v4.5 all-genre model (most versatile, default)
- **V5**: Latest Suno v5 model (experimental)

### Status Values

- `pending` - Request received, queued for processing
- `queued` - Same as pending
- `processing` - Generation in progress
- `completed` - Generation complete, songs available
- `failed` - Generation failed, see `error` field

## Implementation Details

### Polling Strategy

Our implementation polls every **5 seconds** with a **5-minute timeout**:

```python
POLL_INTERVAL = 5  # seconds
MAX_TIMEOUT = 300  # 5 minutes

while elapsed < MAX_TIMEOUT:
    response = check_status(task_id)
    if response.status == "completed":
        return response
    time.sleep(POLL_INTERVAL)
```

### Error Handling

1. **Network errors**: Retry with same poll interval
2. **Timeout**: Exit after 5 minutes with clear error
3. **API errors**: Parse `error` field from response
4. **Download failures**: Warn but continue with other songs

### File Naming

Generated MP3 files are named after the song titles returned by the API:

1. Extract `title` from response
2. Sanitize: keep only alphanumeric, spaces, hyphens, underscores
3. Replace spaces with underscores
4. Append `.mp3` extension

Example: `"My Song Title!"` → `My_Song_Title.mp3`

### Output Format

**stderr**: Progress updates, status messages, warnings
```
Submitting generation request...
Task ID: 12345-67890-abcde
Waiting for generation to complete...
Generation complete!
Downloading MP3 files...
Generated songs saved:
  /path/to/output/Song_Title_1.mp3
  /path/to/output/Song_Title_2.mp3
```

**stdout**: File paths only (for scripting)
```
/path/to/output/Song_Title_1.mp3
/path/to/output/Song_Title_2.mp3
```

## Rate Limiting

The API may have rate limits. Recommended:

- Wait **10-30 seconds** between generation requests
- Don't submit more than **6 requests per minute**
- Monitor your API quota usage

## Webhook (callBackUrl)

The API requires a `callBackUrl` parameter. We use `https://<YOUR_DOMAIN>/api/webhook` as a placeholder since our implementation uses polling instead of webhooks.

If you want to implement webhook-based notifications:

1. Set up an HTTPS endpoint
2. Accept POST requests with the task status
3. Parse the JSON body (same format as poll response)
4. Process completed generations

## API Key

Obtain from: https://sunoapi.org

Set as environment variable:
```bash
export SUNO_API_KEY="your_api_key_here"
```

The key is sent in the `Authorization` header:
```
Authorization: Bearer your_api_key_here
```

## Cost

Each generation request uses API credits. Check sunoapi.org for current pricing.

Typical: ~1-5 credits per generation (2 songs).

## Examples

See `USAGE_EXAMPLES.md` for complete CLI examples.

## Troubleshooting

**"Invalid API key"**
→ Check `SUNO_API_KEY` environment variable

**"Timeout after 5 minutes"**
→ API overloaded or generation failed, try again later

**"customMode validation error"**
→ Ensure you provide either `prompt` OR `lyrics+style+title`

**Missing audioUrl in response**
→ Generation may have partially failed, check API status

**Download fails**
→ Check internet connection and output directory permissions
