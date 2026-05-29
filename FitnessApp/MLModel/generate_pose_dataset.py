#!/usr/bin/env python3
"""
PULSE — Synthetic Pose Dataset Generator
=========================================
Generates synthetic pose sequences for each exercise class.
This creates CSV files that can be used to train a Core ML classifier.

No video download needed — generates pose data mathematically.

OUTPUT:
    pose_dataset/
        jumping_jack.csv
        squat.csv
        push_up.csv
        high_knees.csv
        lunge.csv
        rest.csv
    pose_dataset_combined.csv   ← all classes merged with labels
"""

import math
import random
import csv
import os

random.seed(42)

OUTPUT_DIR = "pose_dataset"
SAMPLES_PER_CLASS = 200   # sequences per exercise
WINDOW_SIZE = 60          # frames per sequence

# Joint names (matching Apple Vision VNHumanBodyPoseObservation)
JOINTS = [
    "nose",
    "left_eye", "right_eye",
    "left_ear", "right_ear",
    "left_shoulder", "right_shoulder",
    "left_elbow", "right_elbow",
    "left_wrist", "right_wrist",
    "left_hip", "right_hip",
    "left_knee", "right_knee",
    "left_ankle", "right_ankle",
    "neck"
]

def noise(scale=0.02):
    return random.gauss(0, scale)

def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))

# ─── Pose generators ─────────────────────────────────────────────────────────
# Each function returns a dict of joint -> (x, y) for one frame
# Coordinates are normalized 0-1 (Vision coordinate space)

def base_pose(cx=0.5, cy=0.5, scale=0.15):
    """Standing neutral pose centered at (cx, cy)."""
    return {
        "nose":           (cx + noise(), cy - scale*2.8 + noise()),
        "left_eye":       (cx - 0.02 + noise(), cy - scale*2.9 + noise()),
        "right_eye":      (cx + 0.02 + noise(), cy - scale*2.9 + noise()),
        "left_ear":       (cx - 0.04 + noise(), cy - scale*2.8 + noise()),
        "right_ear":      (cx + 0.04 + noise(), cy - scale*2.8 + noise()),
        "neck":           (cx + noise(), cy - scale*2.4 + noise()),
        "left_shoulder":  (cx - scale*0.8 + noise(), cy - scale*2.0 + noise()),
        "right_shoulder": (cx + scale*0.8 + noise(), cy - scale*2.0 + noise()),
        "left_elbow":     (cx - scale*0.9 + noise(), cy - scale*1.0 + noise()),
        "right_elbow":    (cx + scale*0.9 + noise(), cy - scale*1.0 + noise()),
        "left_wrist":     (cx - scale*0.9 + noise(), cy + noise()),
        "right_wrist":    (cx + scale*0.9 + noise(), cy + noise()),
        "left_hip":       (cx - scale*0.5 + noise(), cy + scale*0.5 + noise()),
        "right_hip":      (cx + scale*0.5 + noise(), cy + scale*0.5 + noise()),
        "left_knee":      (cx - scale*0.5 + noise(), cy + scale*1.5 + noise()),
        "right_knee":     (cx + scale*0.5 + noise(), cy + scale*1.5 + noise()),
        "left_ankle":     (cx - scale*0.5 + noise(), cy + scale*2.5 + noise()),
        "right_ankle":    (cx + scale*0.5 + noise(), cy + scale*2.5 + noise()),
    }

def jumping_jack_frame(t, cx=0.5, cy=0.5, scale=0.15):
    """t: 0-1 cycle. 0=closed, 0.5=open, 1=closed."""
    phase = math.sin(t * 2 * math.pi)  # -1 to 1
    arm_raise = (phase + 1) / 2        # 0 to 1
    leg_spread = (phase + 1) / 2       # 0 to 1

    p = base_pose(cx, cy, scale)
    # Arms: raise from hip level to above head
    arm_y_offset = -scale * 2.5 * arm_raise
    arm_x_spread = scale * 0.5 * arm_raise
    p["left_wrist"]  = (cx - scale*0.9 - arm_x_spread + noise(), cy + arm_y_offset + noise())
    p["right_wrist"] = (cx + scale*0.9 + arm_x_spread + noise(), cy + arm_y_offset + noise())
    p["left_elbow"]  = (cx - scale*0.9 - arm_x_spread*0.5 + noise(), cy - scale*1.0 + arm_y_offset*0.5 + noise())
    p["right_elbow"] = (cx + scale*0.9 + arm_x_spread*0.5 + noise(), cy - scale*1.0 + arm_y_offset*0.5 + noise())
    # Legs: spread apart
    leg_x = scale * 0.8 * leg_spread
    p["left_ankle"]  = (cx - scale*0.5 - leg_x + noise(), cy + scale*2.5 + noise())
    p["right_ankle"] = (cx + scale*0.5 + leg_x + noise(), cy + scale*2.5 + noise())
    p["left_knee"]   = (cx - scale*0.5 - leg_x*0.5 + noise(), cy + scale*1.5 + noise())
    p["right_knee"]  = (cx + scale*0.5 + leg_x*0.5 + noise(), cy + scale*1.5 + noise())
    return p

def squat_frame(t, cx=0.5, cy=0.5, scale=0.15):
    """t: 0=standing, 0.5=squat, 1=standing."""
    phase = math.sin(t * 2 * math.pi)
    squat_depth = (phase + 1) / 2  # 0=standing, 1=full squat

    p = base_pose(cx, cy, scale)
    # Hips drop, knees bend
    hip_drop = scale * 1.2 * squat_depth
    p["left_hip"]    = (cx - scale*0.5 + noise(), cy + scale*0.5 + hip_drop + noise())
    p["right_hip"]   = (cx + scale*0.5 + noise(), cy + scale*0.5 + hip_drop + noise())
    p["left_knee"]   = (cx - scale*0.7 + noise(), cy + scale*1.5 + hip_drop*0.5 + noise())
    p["right_knee"]  = (cx + scale*0.7 + noise(), cy + scale*1.5 + hip_drop*0.5 + noise())
    # Upper body follows hips down
    body_drop = hip_drop * 0.8
    for joint in ["nose","neck","left_shoulder","right_shoulder","left_elbow","right_elbow","left_wrist","right_wrist"]:
        x, y = p[joint]
        p[joint] = (x + noise(), y + body_drop + noise())
    return p

def push_up_frame(t, cx=0.5, cy=0.5, scale=0.15):
    """Prone position — body horizontal, arms extend/flex."""
    phase = math.sin(t * 2 * math.pi)
    arm_extend = (phase + 1) / 2  # 0=down, 1=up

    # Prone: body is horizontal
    body_y = cy + scale * 0.3
    p = {
        "nose":           (cx - scale*2.5 + noise(), body_y - scale*0.3 + noise()),
        "left_eye":       (cx - scale*2.6 + noise(), body_y - scale*0.35 + noise()),
        "right_eye":      (cx - scale*2.6 + noise(), body_y - scale*0.25 + noise()),
        "left_ear":       (cx - scale*2.7 + noise(), body_y - scale*0.3 + noise()),
        "right_ear":      (cx - scale*2.7 + noise(), body_y - scale*0.3 + noise()),
        "neck":           (cx - scale*2.0 + noise(), body_y + noise()),
        "left_shoulder":  (cx - scale*1.5 + noise(), body_y - scale*0.4 + noise()),
        "right_shoulder": (cx - scale*1.5 + noise(), body_y + scale*0.4 + noise()),
        "left_elbow":     (cx - scale*0.8 + noise(), body_y - scale*0.5 + noise()),
        "right_elbow":    (cx - scale*0.8 + noise(), body_y + scale*0.5 + noise()),
        "left_wrist":     (cx + noise(), body_y - scale*0.5 - arm_extend*scale*0.3 + noise()),
        "right_wrist":    (cx + noise(), body_y + scale*0.5 + arm_extend*scale*0.3 + noise()),
        "left_hip":       (cx + scale*1.0 + noise(), body_y - scale*0.3 + noise()),
        "right_hip":      (cx + scale*1.0 + noise(), body_y + scale*0.3 + noise()),
        "left_knee":      (cx + scale*2.0 + noise(), body_y - scale*0.2 + noise()),
        "right_knee":     (cx + scale*2.0 + noise(), body_y + scale*0.2 + noise()),
        "left_ankle":     (cx + scale*2.8 + noise(), body_y - scale*0.1 + noise()),
        "right_ankle":    (cx + scale*2.8 + noise(), body_y + scale*0.1 + noise()),
    }
    return p

def high_knees_frame(t, cx=0.5, cy=0.5, scale=0.15):
    """Alternating knee raises."""
    phase = t * 2 * math.pi
    left_up = max(0, math.sin(phase))
    right_up = max(0, math.sin(phase + math.pi))

    p = base_pose(cx, cy, scale)
    # Left knee raises
    p["left_knee"]  = (cx - scale*0.5 + noise(), cy + scale*1.5 - scale*1.5*left_up + noise())
    p["left_ankle"] = (cx - scale*0.5 + noise(), cy + scale*2.5 - scale*1.5*left_up + noise())
    # Right knee raises
    p["right_knee"]  = (cx + scale*0.5 + noise(), cy + scale*1.5 - scale*1.5*right_up + noise())
    p["right_ankle"] = (cx + scale*0.5 + noise(), cy + scale*2.5 - scale*1.5*right_up + noise())
    # Arms swing opposite
    p["left_wrist"]  = (cx - scale*0.9 + noise(), cy - scale*0.5*right_up + noise())
    p["right_wrist"] = (cx + scale*0.9 + noise(), cy - scale*0.5*left_up + noise())
    return p

def lunge_frame(t, cx=0.5, cy=0.5, scale=0.15):
    """Step forward, lower back knee."""
    phase = math.sin(t * 2 * math.pi)
    lunge_depth = (phase + 1) / 2

    p = base_pose(cx, cy, scale)
    # Front leg steps forward
    step = scale * 1.0 * lunge_depth
    p["right_knee"]  = (cx + scale*0.5 + step + noise(), cy + scale*1.5 + noise())
    p["right_ankle"] = (cx + scale*0.5 + step*1.5 + noise(), cy + scale*2.5 + noise())
    # Back knee drops
    p["left_knee"]   = (cx - scale*0.5 - step*0.5 + noise(), cy + scale*1.5 + scale*0.8*lunge_depth + noise())
    p["left_ankle"]  = (cx - scale*0.5 - step + noise(), cy + scale*2.5 - scale*0.5*lunge_depth + noise())
    # Hips drop slightly
    hip_drop = scale * 0.4 * lunge_depth
    p["left_hip"]  = (cx - scale*0.5 + noise(), cy + scale*0.5 + hip_drop + noise())
    p["right_hip"] = (cx + scale*0.5 + noise(), cy + scale*0.5 + hip_drop + noise())
    return p

def rest_frame(cx=0.5, cy=0.5, scale=0.15):
    """Standing still with small random sway."""
    sway = noise(0.01)
    p = base_pose(cx + sway, cy, scale)
    return p

# ─── Sequence generators ─────────────────────────────────────────────────────

EXERCISE_GENERATORS = {
    "jumping_jack": lambda t, cx, cy, s: jumping_jack_frame(t, cx, cy, s),
    "squat":        lambda t, cx, cy, s: squat_frame(t, cx, cy, s),
    "push_up":      lambda t, cx, cy, s: push_up_frame(t, cx, cy, s),
    "high_knees":   lambda t, cx, cy, s: high_knees_frame(t, cx, cy, s),
    "lunge":        lambda t, cx, cy, s: lunge_frame(t, cx, cy, s),
    "rest":         lambda t, cx, cy, s: rest_frame(cx, cy, s),
}

def generate_sequence(exercise_name, window_size=WINDOW_SIZE):
    """Generate one sequence of `window_size` frames for an exercise."""
    gen = EXERCISE_GENERATORS[exercise_name]
    # Random position/scale variation per sequence
    cx = 0.5 + random.uniform(-0.05, 0.05)
    cy = 0.5 + random.uniform(-0.05, 0.05)
    scale = random.uniform(0.12, 0.18)
    # Random speed variation
    speed = random.uniform(0.5, 2.0)

    frames = []
    for i in range(window_size):
        t = (i / window_size) * speed
        if exercise_name == "rest":
            pose = gen(t, cx, cy, scale)
        else:
            pose = gen(t % 1.0, cx, cy, scale)
        frames.append(pose)
    return frames

def flatten_sequence(frames):
    """Flatten frames into a single feature vector."""
    features = []
    for frame in frames:
        for joint in JOINTS:
            x, y = frame.get(joint, (0.0, 0.0))
            features.append(clamp(x))
            features.append(clamp(y))
    return features

def generate_dataset():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    all_rows = []
    header = []

    # Build header
    for i in range(WINDOW_SIZE):
        for joint in JOINTS:
            header.append(f"f{i}_{joint}_x")
            header.append(f"f{i}_{joint}_y")
    header.append("label")

    print("🏋️  Generating synthetic pose dataset...")
    print(f"   {SAMPLES_PER_CLASS} samples × {len(EXERCISE_GENERATORS)} classes = {SAMPLES_PER_CLASS * len(EXERCISE_GENERATORS)} total")
    print()

    for exercise_name in EXERCISE_GENERATORS:
        rows = []
        for _ in range(SAMPLES_PER_CLASS):
            frames = generate_sequence(exercise_name)
            features = flatten_sequence(frames)
            features.append(exercise_name)
            rows.append(features)
            all_rows.append(features)

        # Save per-class CSV
        class_csv = os.path.join(OUTPUT_DIR, f"{exercise_name}.csv")
        with open(class_csv, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(header)
            writer.writerows(rows)

        print(f"  ✅ {exercise_name}: {len(rows)} sequences → {class_csv}")

    # Save combined CSV
    combined_csv = os.path.join(OUTPUT_DIR, "combined.csv")
    random.shuffle(all_rows)
    with open(combined_csv, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(all_rows)

    total = len(all_rows)
    print(f"\n  ✅ Combined: {total} sequences → {combined_csv}")
    print(f"\n📊 Dataset ready: {OUTPUT_DIR}/")
    print(f"   Features per sample: {len(header)-1} ({WINDOW_SIZE} frames × {len(JOINTS)} joints × 2 coords)")
    print(f"   Classes: {', '.join(EXERCISE_GENERATORS.keys())}")

if __name__ == "__main__":
    generate_dataset()
    print("""
╔══════════════════════════════════════════════════════════════╗
║  NEXT: Train the model                                       ║
║  Run: python train_createml.py                               ║
╚══════════════════════════════════════════════════════════════╝
""")
