# PULSE — Exercise Classifier ML Model

## Overview

This folder contains the training pipeline for `ExerciseClassifier.mlmodel` — a custom-trained **Action Classification** model that recognizes exercise movements from body pose sequences.

The model is trained using **Apple Create ML** with the **Action Classification** template, which uses Apple Vision's body pose detection as input features.

## Architecture

```
Camera Feed
    ↓
VisionBodyPoseAnalyzer (Apple Vision — VNDetectHumanBodyPoseRequest)
    ↓ 17 joint positions per frame
ExerciseClassifierManager (our .mlmodel)
    ↓ sliding window of 60 frames
Predicted label: "jumping_jack" | "squat" | "push_up" | "high_knees" | "lunge" | "rest"
    ↓
CameraViewModel → rep counting → UI
```

## Exercise Classes

| Label | Description |
|-------|-------------|
| `jumping_jack` | Arms raise overhead + legs spread simultaneously |
| `squat` | Hip hinge down, knees bend to ~90° |
| `push_up` | Prone position, arms extend/flex |
| `high_knees` | Alternating knee raises above hip |
| `lunge` | Step forward, lower back knee toward floor |
| `rest` | Standing still, walking, neutral pose |

## Dataset

**Source**: UCF-101 (academic benchmark dataset) + self-recorded videos  
**Reference**: Soomro et al., "UCF101: A Dataset of 101 Human Actions Classes From Videos in The Wild", arXiv 2012.

**Structure**:
```
dataset/
├── jumping_jack/   (20 videos × ~10 sec)
├── squat/          (20 videos × ~10 sec)
├── push_up/        (20 videos × ~10 sec)
├── high_knees/     (20 videos × ~10 sec)
├── lunge/          (20 videos × ~10 sec)
└── rest/           (20 videos × ~10 sec)
```

## Training

**Tool**: Apple Create ML (Action Classification template)  
**Prediction Window**: 60 frames  
**Algorithm**: Action Classifier (Vision-based pose features)  
**Iterations**: 20  

## How to Reproduce

```bash
# 1. Install dependency
pip install yt-dlp

# 2. Download dataset
python prepare_dataset.py

# 3. Train (follow GUI instructions)
python train_model.py

# 4. Add ExerciseClassifier.mlmodel to Xcode project
```

## Integration in App

The model is integrated via `ExerciseClassifierManager.swift`:

```swift
// Feed each pose observation to the classifier
ExerciseClassifierManager.shared.addPose(observation)

// Get current prediction
let label = ExerciseClassifierManager.shared.predictedLabel
let confidence = ExerciseClassifierManager.shared.confidence
```

The classifier runs alongside the rule-based `ExerciseDetector` as a secondary validation layer.
