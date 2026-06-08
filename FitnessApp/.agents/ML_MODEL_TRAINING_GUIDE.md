# 🤖 ML Model Training Guide — Video-Based Exercise Classifier

## Overview

This guide explains how to train a custom **Action Classification** model in **Create ML** (Xcode 14+) using **video recordings** of exercises.

The trained `.mlmodel` will replace the existing `ExerciseClassifier.mlmodel` and can classify:
- Jumping Jacks
- Squats
- Push-Ups
- High Knees
- Lunges
- Arm Raises
- Toe Touches
- Rest (no movement)

---

## Prerequisites

- Xcode 14.0+ (macOS Monterey 12.5+)
- iPhone with iOS 16.4+ for recording videos
- 10-20 video clips per exercise (30-60 seconds each)
- Good lighting + full-body visibility

---

## 📹 Step 1: Record Training Videos

### Recording Guidelines

1. **Use the iPhone Camera app** (rear camera, landscape orientation recommended)
2. **Record each exercise for 30-60 seconds**
3. **Vary:**
   - Speed (slow, medium, fast)
   - Position in frame (left, center, right)
   - Distance from camera (2-3 meters optimal)
   - Clothing (light/dark to generalize)
4. **Keep stable:** Don't move the camera during recording
5. **File naming:** `jumping_jacks_01.mov`, `squats_02.mov`, etc.

### Recommended Dataset Size

| Exercise | Min Videos | Ideal Videos |
|----------|-----------|-------------|
| Jumping Jacks | 5 | 15 |
| Squats | 5 | 15 |
| High Knees | 5 | 15 |
| Lunges | 5 | 15 |
| Arm Raises | 5 | 15 |
| Toe Touches | 5 | 15 |
| Push-Ups | 5 | 15 |
| Rest | 3 | 10 |

**Total:** ~40-120 videos (5-10 GB)

---

## 📂 Step 2: Organize Training Data

Create ML requires this folder structure:

```
TrainingData/
├── jumping_jacks/
│   ├── video_01.mov
│   ├── video_02.mov
│   └── video_03.mov
├── squats/
│   ├── video_01.mov
│   └── video_02.mov
├── high_knees/
│   └── ...
├── lunges/
│   └── ...
├── arm_raises/
│   └── ...
├── toe_touches/
│   └── ...
├── push_ups/
│   └── ...
└── rest/
    ├── standing_still.mov
    └── sitting.mov
```

**IMPORTANT:**
- Folder names = class labels (use lowercase with underscores)
- Create ML will automatically extract poses from videos
- No need to manually extract frames

---

## 🛠 Step 3: Train Model in Create ML

### 3.1 Open Create ML

1. Launch **Xcode**
2. Menu: **Xcode → Open Developer Tool → Create ML**
3. Click **New Document**
4. Select **Action Classification** template
5. Save project as `ExerciseClassifier.mlproj`

### 3.2 Import Training Data

1. **Training Data:** Drag the `TrainingData/` folder into the "Training Data" section
2. Create ML will show:
   ```
   Classes: 8
   Videos: [your total count]
   Estimated Processing Time: 15-45 minutes
   ```
3. (Optional) **Validation Data:** Create a separate `ValidationData/` folder with 20% of your videos for testing

### 3.3 Configure Model Parameters

| Parameter | Recommended Value | Notes |
|-----------|------------------|-------|
| **Prediction Window Size** | 60 frames | Matches app's sliding window |
| **Augmentation** | ✅ Enabled | Adds horizontal flip, slight rotation |
| **Algorithm** | Automatic | Create ML chooses best architecture |
| **Max Iterations** | 25-50 | More iterations = better accuracy, longer training |

### 3.4 Start Training

1. Click **Train**
2. Training takes **30-90 minutes** (depends on video count + Mac specs)
3. Create ML will show:
   - Training Accuracy
   - Validation Accuracy
   - Confusion Matrix

**Target Accuracy:** 85%+ on validation set

### 3.5 Evaluate Model

1. Check **Confusion Matrix** — most errors should be in "rest" vs actual exercise
2. **Test** tab: Drag a new video (not in training set) to see real-time prediction
3. If accuracy < 80%, add more training videos or increase iterations

### 3.6 Export Model

1. Click **Get** (Output tab)
2. Save as `ExerciseClassifier.mlmodel`
3. **Replace** the old model in Xcode project:
   - Drag `ExerciseClassifier.mlmodel` into `Features/Camera/` folder
   - Check "Copy items if needed" + "FitnessApp" target

---

## 🔧 Step 4: Update App Code (if needed)

### 4.1 Check Output Names

Create ML Action Classifier outputs:
- `label` (String) — predicted class name
- `labelProbabilities` (Dictionary) — confidence per class

The app expects these names. If Create ML uses different names:

**File:** `ExerciseClassifierManager.swift`

```swift
// Line 128-132 — update if needed
predictedLabel = output.featureValue(for: "label")?.stringValue ?? "rest"

if let probs = output.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String: NSNumber] {
    confidence = probs[predictedLabel]?.doubleValue ?? 0.0
}
```

### 4.2 Verify Class Label Mapping

If you used different folder names during training, update the display mapping:

**File:** `ExerciseClassifierManager.swift` (line 98-107)

```swift
var predictedDisplayName: String {
    switch predictedLabel {
    case "jumping_jacks": return "Jumping Jacks"
    case "squats":        return "Squats"
    // ... add your custom labels here
    }
}
```

---

## 📊 Step 5: Test in App

1. **Build & Run** on iPhone
2. Open **Camera** tab
3. Perform each exercise — watch the ML prediction badge (top-right)
4. Verify:
   - Prediction switches within 2-3 seconds of changing exercise
   - Confidence > 70% for clear movements
   - "Rest" appears when standing still

---

## 🐛 Troubleshooting

### Issue: Model predicts "rest" for everything

**Causes:**
- Not enough training data (< 5 videos per class)
- Videos too short (< 20 seconds)
- Poor lighting / body not visible

**Fix:** Add more diverse training videos

---

### Issue: Prediction lags 5+ seconds behind actual exercise

**Cause:** Prediction window (60 frames) too large

**Fix:** 
1. Retrain with **Prediction Window Size = 30** in Create ML
2. Update app: `ExerciseClassifierManager.swift` line 33
   ```swift
   private let predictionWindowSize: Int = 30
   ```

---

### Issue: Xcode shows "ExerciseClassifier not found"

**Fix:**
1. Check model is in project navigator (left sidebar)
2. Select model → **Target Membership** → Enable "FitnessApp"
3. Clean build folder: **Product → Clean Build Folder**

---

### Issue: Confidence always 0%

**Cause:** Bug #2 from audit — wrong output feature name

**Fix:** Apply bug fix (see next section)

---

## 🔧 Known Bugs (Fix Before Training New Model)

From camera audit report, these bugs affect ML model integration:

### Bug #2: Wrong output feature name (CRITICAL)

**File:** `ExerciseClassifierManager.swift` line 131

```swift
// ❌ WRONG
if let probs = output.featureValue(for: "classLabel")?.dictionaryValue

// ✅ CORRECT
if let probs = output.featureValue(for: "labelProbabilities")?.dictionaryValue
```

Apply this fix BEFORE testing the new model.

---

## 📈 Improving Model Accuracy

### Collect Edge Cases

Record videos of:
- Bad form (slouching, half reps)
- Transitions between exercises
- Different body types / heights
- Outdoor lighting
- Occluded body parts (arms behind back)

### Data Augmentation

Create ML automatically applies:
- Horizontal flip (mirrors video)
- Slight rotation (±5°)
- Crop & scale variations

### Increase Training Iterations

In Create ML:
- **Max Iterations:** 50-100 (default is 25)
- Longer training → better generalization

---

## 🎯 Next Steps

After training your first model:

1. **Test accuracy** — record NEW videos (not in training set) and validate predictions
2. **Compare with rule-based** — does ML classifier match `ExerciseDetector` rep counts?
3. **Iterate** — add videos where model fails
4. **Document performance** — log accuracy metrics for your thesis/report

---

## 📚 Additional Resources

- [Create ML Action Classification](https://developer.apple.com/documentation/createml/creating-an-action-classifier-model)
- [Vision Body Pose Guide](https://developer.apple.com/documentation/vision/detecting_human_body_poses_in_images)
- [Core ML Model Integration](https://developer.apple.com/documentation/coreml/integrating_a_core_ml_model_into_your_app)

---

## 📝 Notes for Academic Report

When documenting this in your thesis:

1. **Dataset description:** Number of videos per class, recording conditions
2. **Training parameters:** Prediction window size, iterations, augmentation
3. **Evaluation metrics:** Training/validation accuracy, confusion matrix
4. **Comparison:** ML classifier vs rule-based detector (precision/recall)
5. **Limitations:** Discuss why rule-based is still primary (ML trained on limited synthetic data)

---

**Questions?** Check existing model behavior first:
```bash
cd /Users/a12/Documents/fathi/FitnessApp/FitnessApp/Features/Camera
ls -la ExerciseClassifier.mlmodel
```

If model file exists, you can train a replacement following this guide.
