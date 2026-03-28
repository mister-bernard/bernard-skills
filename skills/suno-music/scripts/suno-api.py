#!/usr/bin/env python3
"""
Suno Music Generation API Client
Generates music via sunoapi.org with automatic polling and download.
"""

import argparse
import json
import os
import sys
import time
import requests
from pathlib import Path
from typing import Optional, Dict, List


class SunoAPIClient:
    """Client for Suno music generation API"""
    
    BASE_URL = "https://api.sunoapi.org/api/v1"
    CALLBACK_URL = "https://YOUR_DOMAIN.com/api/webhook"
    POLL_INTERVAL = 5  # seconds
    MAX_TIMEOUT = 300  # 5 minutes
    
    def __init__(self, api_key: str):
        if not api_key:
            raise ValueError("SUNO_API_KEY environment variable not set")
        self.api_key = api_key
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
    
    def generate(
        self,
        prompt: Optional[str] = None,
        lyrics: Optional[str] = None,
        style: Optional[str] = None,
        title: Optional[str] = None,
        instrumental: bool = False,
        model: str = "V4_5ALL"
    ) -> str:
        """
        Submit a music generation request.
        
        Returns:
            Task ID for polling
        """
        # Validate parameters
        custom_mode = bool(lyrics and style and title)
        simple_mode = bool(prompt and not any([lyrics, style, title]))
        
        if not custom_mode and not simple_mode:
            raise ValueError(
                "Must provide either --prompt (simple) OR "
                "--lyrics + --style + --title (custom)"
            )
        
        # Build request payload
        payload = {
            "customMode": custom_mode,
            "instrumental": instrumental,
            "callBackUrl": self.CALLBACK_URL,
            "model": model
        }
        
        if custom_mode:
            payload["prompt"] = lyrics  # In custom mode, prompt = lyrics
            payload["style"] = style
            payload["title"] = title
        else:
            payload["prompt"] = prompt
        
        # Submit request
        try:
            response = requests.post(
                f"{self.BASE_URL}/generate",
                headers=self.headers,
                json=payload,
                timeout=30
            )
            response.raise_for_status()
            data = response.json()
            
            if "taskId" not in data:
                raise ValueError(f"Unexpected API response: {data}")
            
            return data["taskId"]
            
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"API request failed: {e}")
    
    def poll_status(self, task_id: str) -> Dict:
        """
        Poll for generation status.
        
        Returns:
            Status data with song information when complete
        """
        start_time = time.time()
        
        while True:
            elapsed = time.time() - start_time
            if elapsed > self.MAX_TIMEOUT:
                raise TimeoutError(
                    f"Generation timeout after {self.MAX_TIMEOUT}s"
                )
            
            try:
                response = requests.get(
                    f"{self.BASE_URL}/generate/record-info",
                    headers=self.headers,
                    params={"taskId": task_id},
                    timeout=30
                )
                response.raise_for_status()
                data = response.json()
                
                # Check status
                status = data.get("status")
                
                if status == "completed":
                    return data
                elif status == "failed":
                    error_msg = data.get("error", "Unknown error")
                    raise RuntimeError(f"Generation failed: {error_msg}")
                elif status in ["pending", "processing", "queued"]:
                    # Still processing, wait and retry
                    time.sleep(self.POLL_INTERVAL)
                    continue
                else:
                    # Unknown status, keep polling
                    time.sleep(self.POLL_INTERVAL)
                    continue
                    
            except requests.exceptions.RequestException as e:
                # Network error, retry
                time.sleep(self.POLL_INTERVAL)
                continue
    
    def download_songs(
        self,
        status_data: Dict,
        output_dir: Path
    ) -> List[Path]:
        """
        Download generated MP3 files.
        
        Returns:
            List of downloaded file paths
        """
        songs = status_data.get("data", [])
        if not songs:
            raise ValueError("No songs found in response")
        
        output_dir.mkdir(parents=True, exist_ok=True)
        downloaded_files = []
        
        for i, song in enumerate(songs, 1):
            # Get song metadata
            song_url = song.get("audioUrl") or song.get("audio_url")
            song_title = song.get("title", f"untitled_{i}")
            
            if not song_url:
                print(
                    f"Warning: No audio URL for song {i}, skipping",
                    file=sys.stderr
                )
                continue
            
            # Clean filename
            safe_title = "".join(
                c for c in song_title
                if c.isalnum() or c in (' ', '-', '_')
            ).strip()
            safe_title = safe_title.replace(' ', '_')
            filename = f"{safe_title}.mp3"
            filepath = output_dir / filename
            
            # Download MP3
            try:
                response = requests.get(song_url, timeout=60)
                response.raise_for_status()
                
                filepath.write_bytes(response.content)
                downloaded_files.append(filepath)
                
            except requests.exceptions.RequestException as e:
                print(
                    f"Warning: Failed to download {filename}: {e}",
                    file=sys.stderr
                )
                continue
        
        return downloaded_files


def main():
    parser = argparse.ArgumentParser(
        description="Generate music using Suno API"
    )
    
    # Mode arguments
    parser.add_argument(
        "--prompt",
        help="Text description for simple mode"
    )
    parser.add_argument(
        "--lyrics",
        help="Custom lyrics (requires --style and --title)"
    )
    parser.add_argument(
        "--style",
        help="Genre/style tags (requires --lyrics and --title)"
    )
    parser.add_argument(
        "--title",
        help="Song title (requires --lyrics and --style)"
    )
    
    # Options
    parser.add_argument(
        "--instrumental",
        action="store_true",
        help="Generate instrumental (no vocals)"
    )
    parser.add_argument(
        "--model",
        default="V4_5ALL",
        choices=["V4", "V4_5", "V4_5ALL", "V5"],
        help="Model version (default: V4_5ALL)"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path.cwd(),
        help="Output directory for MP3 files (default: current dir)"
    )
    
    args = parser.parse_args()
    
    # Get API key
    api_key = os.getenv("SUNO_API_KEY")
    if not api_key:
        print("Error: SUNO_API_KEY environment variable not set", file=sys.stderr)
        print("Set it with: export SUNO_API_KEY='your_key'", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Initialize client
        client = SunoAPIClient(api_key)
        
        # Submit generation request
        print("Submitting generation request...", file=sys.stderr)
        task_id = client.generate(
            prompt=args.prompt,
            lyrics=args.lyrics,
            style=args.style,
            title=args.title,
            instrumental=args.instrumental,
            model=args.model
        )
        print(f"Task ID: {task_id}", file=sys.stderr)
        
        # Poll for completion
        print("Waiting for generation to complete...", file=sys.stderr)
        status_data = client.poll_status(task_id)
        print("Generation complete!", file=sys.stderr)
        
        # Download songs
        print("Downloading MP3 files...", file=sys.stderr)
        files = client.download_songs(status_data, args.output_dir)
        
        if not files:
            print("Error: No files were downloaded", file=sys.stderr)
            sys.exit(1)
        
        # Output file paths (stdout for script integration)
        print("\nGenerated songs saved:", file=sys.stderr)
        for filepath in files:
            print(f"  {filepath}", file=sys.stderr)
            print(filepath)  # stdout for parsing
        
        sys.exit(0)
        
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
