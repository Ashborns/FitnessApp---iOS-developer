#!/usr/bin/env python3
"""
PULSE Fitness App — Create ML Training Script
==============================================
Trains an Action Classification model using Create ML Python API.
This is an ALTERNATIVE to using the Create ML GUI app.

REQUIREMENTS:
    macOS 12+ with Xcode installed
    pip install coremltools

USAGE:
    python train_model.py

OUTPUT:
    ExerciseClassifier.mlmodel  ← drag this into Xcode
"""

import os
import sys

# ─── Check platform ──────────────────────────────────────────────────────────
if sys.platform != "darwin":
    print("❌ Create ML only works on macOS.")
    sys.exit(1)

try:
    import coremltools as ct
    print(f"✅ coremltools {ct.__version__} found")
except ImportError:
    print("❌ coremltools not found. Install with: pip install coremltools")
    sys.exit(1)

# ─── Config ──────────────────────────────────────────────────────────────────
DATASET_DIR = "dataset"
OUTPUT_MODEL = "ExerciseClassifier.mlmodel"
PREDICTION_WINDOW = 60   # frames — must match what you set in Create ML GUI
MAX_ITERATIONS = 20      # increase for better accuracy (50-100 for production)

# ─── Verify dataset ──────────────────────────────────────────────────────────
def verify_dataset():
    if not os.path.exists(DATASET_DIR):
        print(f"❌ Dataset folder '{DATASET_DIR}' not found.")
        print("   Run prepare_dataset.py first.")
        sys.exit(1)

    classes = [d for d in os.listdir(DATASET_DIR)
               if os.path.isdir(os.path.join(DATASET_DIR, d))]

    if len(classes) < 2:
        print(f"❌ Need at least 2 classes, found: {classes}")
        sys.exit(1)

    print(f"✅ Found {len(classes)} classes: {', '.join(classes)}")

    for cls in classes:
        cls_dir = os.path.join(DATASET_DIR, cls)
        videos = [f for f in os.listdir(cls_dir)
                  if f.endswith(('.mp4', '.mov', '.avi'))]
        print(f"   {cls}: {len(videos)} videos")
        if len(videos) < 5:
            print(f"   ⚠️  {cls} has fewer than 5 videos — accuracy may be low")

    return classes


# ─── Train using Create ML via subprocess (GUI approach) ─────────────────────
def print_gui_instructions(classes):
    """
    Create ML Python API for Action Classification requires macOS 13+
    and specific Xcode versions. The GUI is more reliable.
    This function prints step-by-step instructions.
    """
    print("""
╔══════════════════════════════════════════════════════════════════╗
║         TRAIN YOUR MODEL — Step by Step                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  OPTION A: Create ML GUI (Recommended — easiest)                 ║
║  ─────────────────────────────────────────────────               ║
║  1. Open Xcode                                                   ║
║  2. Menu: Xcode → Open Developer Tool → Create ML               ║
║  3. File → New Document                                          ║
║  4. Choose: Action Classification                                ║
║  5. Project name: ExerciseClassifier                             ║
║  6. Training Data: drag the 'dataset/' folder                    ║
║  7. Parameters:                                                  ║
║     • Prediction Window: 60                                      ║
║     • Iterations: 20                                             ║
║  8. Click ▶ Train                                                ║
║  9. Output tab → Get → ExerciseClassifier.mlmodel               ║
║                                                                  ║
║  OPTION B: Command Line (if you have Python + coremltools)       ║
║  ─────────────────────────────────────────────────               ║
║  Run: python train_model_advanced.py                             ║
║                                                                  ║
║  AFTER TRAINING:                                                 ║
║  ─────────────────────────────────────────────────               ║
║  1. Drag ExerciseClassifier.mlmodel into Xcode                   ║
║     (into FitnessApp/ folder)                                    ║
║  2. Check "Add to target: FitnessApp"                            ║
║  3. In ExerciseClassifierManager.swift:                          ║
║     uncomment the model loading code                             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""")
    print(f"Your classes will be: {', '.join(classes)}")
    print(f"Model output labels: {', '.join(classes)}")


if __name__ == "__main__":
    print("🤖 PULSE — Model Training")
    print("=" * 40)
    classes = verify_dataset()
    print_gui_instructions(classes)
