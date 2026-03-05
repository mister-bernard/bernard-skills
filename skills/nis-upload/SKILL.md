# NIS Upload Skill — North Idaho Sunsets Photo Pipeline

## When to Use
When a photo (HEIC, JPEG, PNG) is uploaded to the "North Idaho Sunsetss" Telegram group (`<TELEGRAM_GROUP_ID>`) by DeeDee (sender ID: `<UPLOADER_TELEGRAM_ID>`).

## What to Do

### Single Photo Upload
When Dee sends ONE photo (with or without a caption):

1. Find the file in `~/.openclaw/media/inbound/` (most recent file matching the upload)
2. Run the pipeline:
```bash
cd /home/openclaw/north-idaho-sunsets
GEMINI_API_KEY="$GEMINI_API_KEY" python3 scripts/process-upload.py \
  <file_path> \
  --auto-approve \
  --location "Hayden Lake" \
  2>&1
```
3. If Dee provided a caption, add `--title "Caption Text"` to the command
4. If no caption, the AI will generate a name automatically
5. Reply to Dee with the result: title, URL (`https://northidahosunsets.com/sunset/<slug>`), and a brief comment about the photo

### Bulk Upload (Multiple Photos)
When Dee sends MULTIPLE photos without naming them:

1. Collect all file paths from `~/.openclaw/media/inbound/`
2. Run them all at once:
```bash
cd /home/openclaw/north-idaho-sunsets
GEMINI_API_KEY="$GEMINI_API_KEY" python3 scripts/process-upload.py \
  <file1> <file2> <file3> ... \
  --auto-approve \
  --location "Hayden Lake" \
  2>&1
```
3. The pipeline will:
   - Auto-classify each photo (sunset detection)
   - Generate unique, evocative titles for each
   - Create smart crops for all 3 print ratios (4:5, 11:14, 2:3)
   - Upload and auto-approve each one
4. Reply to Dee with a summary of all uploaded photos and their URLs

### If Location is Specified
If Dee says "this one is from Sandpoint" or mentions a specific location, pass `--location "Sandpoint"` instead. Default is always Hayden Lake.

### If Classification Fails
If a photo has low sunset confidence (<40%), the pipeline will NOT auto-approve it. Tell Dee and ask if she wants it uploaded anyway.

## File Paths
- Media lands in: `~/.openclaw/media/inbound/`
- Files are named: `file_NN---<uuid>.<ext>` (e.g., `file_95---41495fae-dbbf-4344-ba88-b0274fb0b3d9.heic`)
- Match by recency — the most recent files matching the upload count

## Key Details
- **NIS API**: runs on port 3001 (localhost)
- **Photo routes**: `/sunset/<slug>` (NOT `/p/`)
- **Print sizes**: 8×10 (4:5), 11×14 (11:14), 16×20 (4:5), 24×36 (2:3)
- **GEMINI_API_KEY** must be in environment for classification/naming
- **NIS_API_KEY** in `/home/openclaw/north-idaho-sunsets/.env` for upload API

## After Renaming or Slug Changes
**Always restart `nis-web` after any DB changes to slugs/titles:**
```bash
systemctl --user restart nis-web
```
The server caches photo data — without a restart, old slugs may 404 and new ones won't resolve.

## Pinning a Photo to Top
The site orders by `published_at DESC`. To pin a photo:
```sql
UPDATE photos SET published_at='2099-01-01 00:00:00' WHERE slug='<slug>';
```
Then restart nis-web.

## Title Uniqueness (Critical)
- **Every photo MUST have a unique title** — duplicate names confuse customers and the site
- The pipeline has 3 layers of dedup: better Gemini prompts, title collision check + retry, perceptual hash
- If Gemini generates a duplicate title, it retries once, then falls back to Roman numeral suffixes
- After any bulk upload, verify: `sqlite3 data/photos.db "SELECT title, COUNT(*) FROM photos WHERE status='approved' GROUP BY title HAVING COUNT(*) > 1;"`

## Bulk Processing Tips
- **Always use `PYTHONUNBUFFERED=1` and `python3 -u`** — without it, output buffers and you can't monitor progress
- **Pipe through `tee /tmp/nis-batchN.log`** — so output survives if the session disconnects
- **Batch size: max 10 photos per run** — larger batches risk OOM/timeout kills (HEIC conversion is ~500MB+ RAM for 32 photos)
- **If a batch dies mid-run**, check the log file to see which completed, then continue from where it left off
- **Gemini classification can return `None` for focal_x/focal_y/horizon_y** — the pipeline now defaults to center (0.5, 0.4, 0.5)
- **Don't send progress updates to the group** — only send the final summary with all links when everything is done

## Do NOT
- Don't ask Dee to name photos — generate names automatically
- Don't upload non-sunset photos without confirming with Dee
- Don't expose internal pipeline details to Dee — just show results
- Don't run HEIC crop generation synchronously (it's 60s per crop) — web JPEGs are generated immediately
- Don't send "processing..." messages for each batch — one final summary only
