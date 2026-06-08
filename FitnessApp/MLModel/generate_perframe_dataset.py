#!/usr/bin/env python3
"""
PULSE — Per-Frame Pose Dataset Generator
==========================================
Generates a CSV where each row = one pose (single frame).
Format optimized for Create ML Tabular Classification.

Each row has 36 features (18 joints × 2 coords) + 1 label column.
Much smaller than sequence-based dataset, fast to train.

OUTPUT:
    pose_perframe.csv  (~6000 rows × 37 columns)
"""

import math
import random
import csv

random.seed(42)

OUTPUT_FILE = "pose_perframe.csv"
SAMPLES_PER_CLASS = 1000   # frames per exercise

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

def base_pose(cx=0.5, cy=0.5, scale=0.15):
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


def jumping_jack_frame():
    """Random snapshot from any phase of jumping jack."""
    cx = 0.5 + random.uniform(-0.1, 0.1)
    cy = 0.5 + random.uniform(-0.1, 0.1)
    scale = random.uniform(0.12, 0.18)
    t = random.random()  # any phase
    phase = math.sin(t * 2 * math.pi)
    arm_raise = (phase + 1) / 2
    leg_spread = (phase + 1) / 2

    p = base_pose(cx, cy, scale)
    arm_y_offset = -scale * 2.5 * arm_raise
    arm_x_spread = scale * 0.5 * arm_raise
    p["left_wrist"]  = (cx - scale*0.9 - arm_x_spread + noise(), cy + arm_y_offset + noise())
    p["right_wrist"] = (cx + scale*0.9 + arm_x_spread + noise(), cy + arm_y_offset + noise())
    p["left_elbow"]  = (cx - scale*0.9 - arm_x_spread*0.5 + noise(), cy - scale*1.0 + arm_y_offset*0.5 + noise())
    p["right_elbow"] = (cx + scale*0.9 + arm_x_spread*0.5 + noise(), cy - scale*1.0 + arm_y_offset*0.5 + noise())
    leg_x = scale * 0.8 * leg_spread
    p["left_ankle"]  = (cx - scale*0.5 - leg_x + noise(), cy + scale*2.5 + noise())
    p["right_ankle"] = (cx + scale*0.5 + leg_x + noise(), cy + scale*2.5 + noise())
    p["left_knee"]   = (cx - scale*0.5 - leg_x*0.5 + noise(), cy + scale*1.5 + noise())
    p["right_knee"]  = (cx + scale*0.5 + leg_x*0.5 + noise(), cy + scale*1.5 + noise())
    return p

def squat_frame():
    cx = 0.5 + random.uniform(-0.1, 0.1)
    cy = 0.5 + random.uniform(-0.1, 0.1)
    scale = random.uniform(0.12, 0.18)
    squat_depth = random.random()  # 0=stand, 1=full squat

    p = base_pose(cx, cy, scale)
    hip_drop = scale * 1.2 * squat_depth
    p["left_hip"]    = (cx - scale*0.5 + noise(), cy + scale*0.5 + hip_drop + noise())
    p["right_hip"]   = (cx + scale*0.5 + noise(), cy + scale*0.5 + hip_drop + noise())
    p["left_knee"]   = (cx - scale*0.7 + noise(), cy + scale*1.5 + hip_drop*0.5 + noise())
    p["right_knee"]  = (cx + scale*0.7 + noise(), cy + scale*1.5 + hip_drop*0.5 + noise())
    body_drop = hip_drop * 0.8
    for joint in ["nose","neck","left_shoulder","right_shoulder","left_elbow","right_elbow","left_wrist","right_wrist"]:
        x, y = p[joint]
        p[joint] = (x + noise(), y + body_drop + noise())
    return p

def push_up_frame():
    cx = 0.5 + random.uniform(-0.1, 0.1)
    cy = 0.5 + random.uniform(-0.1, 0.1)
    scale = random.uniform(0.12, 0.18)
    arm_extend = random.random()
    body_y = cy + scale * 0.3
    return {
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

def high_knees_frame():
    cx = 0.5 + random.uniform(-0.1, 0.1)
    cy = 0.5 + random.uniform(-0.1, 0.1)
    scale = random.uniform(0.12, 0.18)
    t = random.random()
    phase = t * 2 * math.pi
    left_up = max(0, math.sin(phase))
    right_up = max(0, math.sin(phase + math.pi))

    p = base_pose(cx, cy, scale)
    p["left_knee"]  = (cx - scale*0.5 + noise(), cy + scale*1.5 - scale*1.5*left_up + noise())
    p["left_ankle"] = (cx - scale*0.5 + noise(), cy + scale*2.5 - scale*1.5*left_up + noise())
    p["right_knee"]  = (cx + scale*0.5 + noise(), cy + scale*1.5 - scale*1.5*right_up + noise())
    p["right_ankle"] = (cx + scale*0.5 + noise(), cy + scale*2.5 - scale*1.5*right_up + noise())
    p["left_wrist"]  = (cx - scale*0.9 + noise(), cy - scale*0.5*right_up + noise())
    p["right_wrist"] = (cx + scale*0.9 + noise(), cy - scale*0.5*left_up + noise())
    return p

def lunge_frame():
    cx = 0.5 + random.uniform(-0.1, 0.1)
    cy = 0.5 + random.uniform(-0.1, 0.1)
    scale = random.uniform(0.12, 0.18)
    lunge_depth = random.random()

    p = base_pose(cx, cy, scale)
    step = scale * 1.0 * lunge_depth
    p["right_knee"]  = (cx + scale*0.5 + step + noise(), cy + scale*1.5 + noise())
    p["right_ankle"] = (cx + scale*0.5 + step*1.5 + noise(), cy + scale*2.5 + noise())
    p["left_knee"]   = (cx - scale*0.5 - step*0.5 + noise(), cy + scale*1.5 + scale*0.8*lunge_depth + noise())
    p["left_ankle"]  = (cx - scale*0.5 - step + noise(), cy + scale*2.5 - scale*0.5*lunge_depth + noise())
    hip_drop = scale * 0.4 * lunge_depth
    p["left_hip"]  = (cx - scale*0.5 + noise(), cy + scale*0.5 + hip_drop + noise())
    p["right_hip"] = (cx + scale*0.5 + noise(), cy + scale*0.5 + hip_drop + noise())
    return p

def rest_frame():
    cx = 0.5 + random.uniform(-0.1, 0.1)
    cy = 0.5 + random.uniform(-0.1, 0.1)
    scale = random.uniform(0.12, 0.18)
    return base_pose(cx, cy, scale)


GENERATORS = {
    "jumping_jack": jumping_jack_frame,
    "squat":        squat_frame,
    "push_up":      push_up_frame,
    "high_knees":   high_knees_frame,
    "lunge":        lunge_frame,
    "rest":         rest_frame,
}


def main():
    # Build header: 18 joints × (x, y) = 36 features + 1 label
    header = []
    for joint in JOINTS:
        header.append(f"{joint}_x")
        header.append(f"{joint}_y")
    header.append("label")

    rows = []
    print("🏋️  Generating per-frame pose dataset...")

    for class_name, generator in GENERATORS.items():
        for _ in range(SAMPLES_PER_CLASS):
            pose = generator()
            features = []
            for joint in JOINTS:
                x, y = pose.get(joint, (0.0, 0.0))
                features.append(round(clamp(x), 4))
                features.append(round(clamp(y), 4))
            features.append(class_name)
            rows.append(features)
        print(f"  ✅ {class_name}: {SAMPLES_PER_CLASS} frames")

    # Shuffle rows so train/test split is balanced
    random.shuffle(rows)

    # Write CSV
    with open(OUTPUT_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)

    total = len(rows)
    print(f"\n📊 Dataset ready: {OUTPUT_FILE}")
    print(f"   Rows: {total}")
    print(f"   Features: {len(header)-1} (18 joints × x,y)")
    print(f"   Classes: {', '.join(GENERATORS.keys())}")
    print()
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  NEXT: Train in Create ML                                    ║")
    print("╠══════════════════════════════════════════════════════════════╣")
    print("║  1. Open Xcode → Xcode → Open Developer Tool → Create ML    ║")
    print("║  2. New Document → Tabular Classification                    ║")
    print("║  3. Training Data: drag pose_perframe.csv                    ║")
    print("║  4. Target Column: label                                     ║")
    print("║  5. Algorithm: Boosted Tree (default — fastest & accurate)  ║")
    print("║  6. Train (1-2 minutes)                                      ║")
    print("║  7. Output → Get → ExerciseClassifier.mlmodel                ║")
    print("║  8. Drag .mlmodel into Xcode project (FitnessApp/ folder)   ║")
    print("╚══════════════════════════════════════════════════════════════╝")

if __name__ == "__main__":
    main()
