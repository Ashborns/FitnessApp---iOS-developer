#!/usr/bin/env python3
"""
PULSE Fitness App — Dataset Preparation Script
================================================
Downloads exercise videos from YouTube and organizes them for Create ML training.

REQUIREMENTS:
    pip install yt-dlp

USAGE:
    python prepare_dataset.py

OUTPUT:
    dataset/
        jumping_jack/   (videos)
        squat/
        push_up/
        high_knees/
        lunge/
        rest/
"""

import os
import subprocess
import sys

# ─── Exercise classes + YouTube search queries ───────────────────────────────
# Each entry: (folder_name, [list of YouTube URLs or search queries])
# We use yt-dlp's search feature: "ytsearch10:query" = top 10 results

EXERCISES = {
    "jumping_jack": [
        "ytsearch15:jumping jacks exercise tutorial full body",
        "ytsearch10:how to do jumping jacks fitness",
    ],
    "squat": [
        "ytsearch15:squat exercise tutorial bodyweight",
        "ytsearch10:how to do squats properly",
    ],
    "push_up": [
        "ytsearch15:push up exercise tutorial beginner",
        "ytsearch10:how to do push ups properly",
    ],
    "high_knees": [
        "ytsearch15:high knees exercise cardio tutorial",
        "ytsearch10:high knees running in place workout",
    ],
    "lunge": [
        "ytsearch15:lunge exercise tutorial legs",
        "ytsearch10:how to do lunges properly",
    ],
    "rest": [
        "ytsearch10:person standing still neutral pose",
        "ytsearch10:person walking slowly casual",
    ],
}

# ─── Config ──────────────────────────────────────────────────────────────────
OUTPUT_DIR = "dataset"
MAX_DURATION = 30       # seconds — skip videos longer than this
MAX_PER_CLASS = 20      # max videos per class
VIDEO_FORMAT = "mp4"    # Create ML accepts mp4 and mov


def check_yt_dlp():
    """Check if yt-dlp is installed."""
    try:
        subprocess.run(["yt-dlp", "--version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ yt-dlp not found. Install with: pip install yt-dlp")
        sys.exit(1)


def download_videos(class_name: str, queries: list[str]):
    """Download videos for a given exercise class."""
    class_dir = os.path.join(OUTPUT_DIR, class_name)
    os.makedirs(class_dir, exist_ok=True)

    existing = len([f for f in os.listdir(class_dir) if f.endswith(f".{VIDEO_FORMAT}")])
    if existing >= MAX_PER_CLASS:
        print(f"  ✅ {class_name}: already has {existing} videos, skipping")
        return

    needed = MAX_PER_CLASS - existing
    print(f"  📥 {class_name}: downloading up to {needed} videos...")

    for query in queries:
        if needed <= 0:
            break

        cmd = [
            "yt-dlp",
            query,
            "--output", os.path.join(class_dir, "%(title)s.%(ext)s"),
            "--format", f"bestvideo[ext={VIDEO_FORMAT}][height<=480]+bestaudio/best[height<=480]",
            "--merge-output-format", VIDEO_FORMAT,
            "--max-downloads", str(needed),
            "--match-filter", f"duration < {MAX_DURATION}",
            "--no-playlist",
            "--quiet",
            "--no-warnings",
            "--ignore-errors",
        ]

        try:
            subprocess.run(cmd, check=False, timeout=300)
        except subprocess.TimeoutExpired:
            print(f"    ⚠️  Timeout on query: {query}")
        except Exception as e:
            print(f"    ⚠️  Error: {e}")

        # Recount
        existing = len([f for f in os.listdir(class_dir) if f.endswith(f".{VIDEO_FORMAT}")])
        needed = MAX_PER_CLASS - existing

    final_count = len([f for f in os.listdir(class_dir) if f.endswith(f".{VIDEO_FORMAT}")])
    print(f"  ✅ {class_name}: {final_count} videos ready")


def print_summary():
    """Print dataset summary."""
    print("\n📊 Dataset Summary:")
    print("─" * 40)
    total = 0
    for class_name in EXERCISES:
        class_dir = os.path.join(OUTPUT_DIR, class_name)
        if os.path.exists(class_dir):
            count = len([f for f in os.listdir(class_dir) if f.endswith(f".{VIDEO_FORMAT}")])
            total += count
            status = "✅" if count >= 10 else "⚠️ " if count > 0 else "❌"
            print(f"  {status} {class_name:<20} {count:>3} videos")
        else:
            print(f"  ❌ {class_name:<20}   0 videos")
    print("─" * 40)
    print(f"  Total: {total} videos across {len(EXERCISES)} classes")
    print()
    if total >= len(EXERCISES) * 10:
        print("✅ Dataset ready for Create ML training!")
        print_create_ml_instructions()
    else:
        print("⚠️  Some classes have fewer than 10 videos.")
        print("   Consider recording additional videos manually.")


def print_create_ml_instructions():
    print("""
╔══════════════════════════════════════════════════════════════╗
║           NEXT STEP: Train in Create ML                      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  1. Open Xcode → Xcode menu → Open Developer Tool           ║
║     → Create ML                                             ║
║                                                              ║
║  2. File → New Document → Action Classification             ║
║                                                              ║
║  3. Training Data: drag the 'dataset/' folder here          ║
║                                                              ║
║  4. Settings:                                                ║
║     • Prediction Window: 60                                  ║
║     • Iterations: 20 (fast) or 50 (more accurate)           ║
║                                                              ║
║  5. Click Train (takes 5-30 minutes)                         ║
║                                                              ║
║  6. Output tab → Get → save as ExerciseClassifier.mlmodel   ║
║                                                              ║
║  7. Drag ExerciseClassifier.mlmodel into Xcode project      ║
║     (FitnessApp folder, check "Add to target: FitnessApp")  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
""")


if __name__ == "__main__":
    print("🏋️  PULSE — Dataset Preparation")
    print("=" * 40)

    check_yt_dlp()
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for class_name, queries in EXERCISES.items():
        download_videos(class_name, queries)

    print_summary()
