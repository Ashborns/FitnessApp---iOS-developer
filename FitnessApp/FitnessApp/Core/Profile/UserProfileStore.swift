import Foundation
import Combine

/// Central store for user physical profile data.
/// Persisted via AppStorage (UserDefaults) — no CoreData schema change needed.
/// Automatically recalculates calorie goal whenever any field changes.
@MainActor
final class UserProfileStore: ObservableObject {

    // MARK: - Singleton

    static let shared = UserProfileStore()

    // MARK: - Stored Properties

    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: Keys.name) }
    }
    @Published var age: Int {
        didSet {
            UserDefaults.standard.set(age, forKey: Keys.age)
            recalculateGoal()
        }
    }
    @Published var weightKg: Double {
        didSet {
            UserDefaults.standard.set(weightKg, forKey: Keys.weightKg)
            recalculateGoal()
        }
    }
    @Published var heightCm: Double {
        didSet {
            UserDefaults.standard.set(heightCm, forKey: Keys.heightCm)
            recalculateGoal()
        }
    }
    @Published var gender: Gender {
        didSet {
            UserDefaults.standard.set(gender.rawValue, forKey: Keys.gender)
            recalculateGoal()
        }
    }
    @Published var activityLevel: ActivityLevel {
        didSet {
            UserDefaults.standard.set(activityLevel.rawValue, forKey: Keys.activityLevel)
            recalculateGoal()
        }
    }
    @Published var fitnessGoal: FitnessGoal {
        didSet {
            UserDefaults.standard.set(fitnessGoal.rawValue, forKey: Keys.fitnessGoal)
            recalculateGoal()
        }
    }

    /// Calculated daily calorie goal based on BMR × activity multiplier ± goal adjustment.
    @Published private(set) var dailyCalorieGoal: Double = 2000

    /// Whether the user has completed profile setup.
    @Published var hasCompletedProfile: Bool {
        didSet { UserDefaults.standard.set(hasCompletedProfile, forKey: Keys.hasCompletedProfile) }
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard
        name             = ud.string(forKey: Keys.name) ?? ""
        age              = ud.integer(forKey: Keys.age) == 0 ? 25 : ud.integer(forKey: Keys.age)
        weightKg         = ud.double(forKey: Keys.weightKg) == 0 ? 70 : ud.double(forKey: Keys.weightKg)
        heightCm         = ud.double(forKey: Keys.heightCm) == 0 ? 170 : ud.double(forKey: Keys.heightCm)
        gender           = Gender(rawValue: ud.string(forKey: Keys.gender) ?? "") ?? .male
        activityLevel    = ActivityLevel(rawValue: ud.string(forKey: Keys.activityLevel) ?? "") ?? .moderate
        fitnessGoal      = FitnessGoal(rawValue: ud.string(forKey: Keys.fitnessGoal) ?? "") ?? .maintain
        hasCompletedProfile = ud.bool(forKey: Keys.hasCompletedProfile)

        recalculateGoal()
    }

    // MARK: - BMR Calculation (Mifflin-St Jeor)

    /// Calculates Basal Metabolic Rate using Mifflin-St Jeor equation.
    var bmr: Double {
        switch gender {
        case .male:
            return (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        case .female:
            return (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161
        }
    }

    /// Total Daily Energy Expenditure = BMR × activity multiplier.
    var tdee: Double {
        bmr * activityLevel.multiplier
    }

    /// BMI value.
    var bmi: Double {
        let heightM = heightCm / 100
        return weightKg / (heightM * heightM)
    }

    /// BMI category string.
    var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    // MARK: - Private

    private func recalculateGoal() {
        dailyCalorieGoal = (tdee + fitnessGoal.calorieAdjustment).rounded()
        // Write to UserDefaults so other ViewModels can read without importing this class
        UserDefaults.standard.set(dailyCalorieGoal, forKey: "profile.dailyCalorieGoal")
    }

    // MARK: - Keys

    private enum Keys {
        static let name               = "profile.name"
        static let age                = "profile.age"
        static let weightKg           = "profile.weightKg"
        static let heightCm           = "profile.heightCm"
        static let gender             = "profile.gender"
        static let activityLevel      = "profile.activityLevel"
        static let fitnessGoal        = "profile.fitnessGoal"
        static let hasCompletedProfile = "profile.hasCompletedProfile"
    }
}

// MARK: - Gender

enum Gender: String, CaseIterable, Identifiable {
    case male = "male"
    case female = "female"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

// MARK: - ActivityLevel

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary   = "sedentary"
    case light       = "light"
    case moderate    = "moderate"
    case active      = "active"
    case veryActive  = "veryActive"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary:  return "Sedentary"
        case .light:      return "Lightly Active"
        case .moderate:   return "Moderately Active"
        case .active:     return "Very Active"
        case .veryActive: return "Extremely Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary:  return "Little or no exercise"
        case .light:      return "Exercise 1–3 days/week"
        case .moderate:   return "Exercise 3–5 days/week"
        case .active:     return "Exercise 6–7 days/week"
        case .veryActive: return "Hard exercise, physical job"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary:  return 1.2
        case .light:      return 1.375
        case .moderate:   return 1.55
        case .active:     return 1.725
        case .veryActive: return 1.9
        }
    }
}

// MARK: - FitnessGoal

enum FitnessGoal: String, CaseIterable, Identifiable {
    case lose     = "lose"
    case maintain = "maintain"
    case gain     = "gain"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lose:     return "Lose Weight"
        case .maintain: return "Maintain Weight"
        case .gain:     return "Gain Muscle"
        }
    }

    var description: String {
        switch self {
        case .lose:     return "500 kcal deficit/day"
        case .maintain: return "Eat at maintenance"
        case .gain:     return "300 kcal surplus/day"
        }
    }

    var calorieAdjustment: Double {
        switch self {
        case .lose:     return -500
        case .maintain: return 0
        case .gain:     return 300
        }
    }

    var icon: String {
        switch self {
        case .lose:     return "arrow.down.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .gain:     return "arrow.up.circle.fill"
        }
    }
}
