import Foundation

enum Gender: String, Codable, Equatable, Sendable, CaseIterable {
    case male
    case female
}

enum ActivityLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case sedentary
    case light
    case moderate
    case active

    var factor: Double {
        switch self {
        case .sedentary:
            return 1.2
        case .light:
            return 1.375
        case .moderate:
            return 1.55
        case .active:
            return 1.725
        }
    }
}

enum NutritionGoal: String, Codable, Equatable, Sendable, CaseIterable {
    case loseWeight
    case maintain
    case gainWeight
}

enum UnitSystem: String, Codable, Equatable, Sendable, CaseIterable {
    case metric
    case imperial
}

enum MealType: String, Codable, Equatable, Sendable, CaseIterable, Hashable {
    case breakfast
    case lunch
    case dinner
    case snack
}

struct UserNutritionProfile: Codable, Equatable, Sendable {
    var gender: Gender
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityLevel: ActivityLevel
    var goal: NutritionGoal
    var familyMembers: Int
    var regionCode: String
    var unitSystem: UnitSystem

    init(
        gender: Gender,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        activityLevel: ActivityLevel,
        goal: NutritionGoal,
        familyMembers: Int = 1,
        regionCode: String = "vn",
        unitSystem: UnitSystem = .metric
    ) {
        self.gender = gender
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
        self.familyMembers = min(12, max(1, familyMembers))
        self.regionCode = regionCode
        self.unitSystem = unitSystem
    }
}

struct NutritionBreakdown: Codable, Equatable, Sendable {
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
}

struct DishIngredient: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var amount: Double
    var unit: String
    var category: String
}

struct Dish: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var mealTypes: [MealType]
    var dietTags: [String]
    var name: String
    var prepTimeMinutes: Int
    var baseNutrition: NutritionBreakdown
    var ingredients: [DishIngredient]
    var steps: [String]
}

struct DailyMealSlot: Codable, Equatable, Sendable {
    var dayIndex: Int
    var breakfastId: String
    var lunchId: String
    var dinnerId: String
    var completedMeals: Set<MealType>
}

struct WeeklyMealPlan: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var regionCode: String
    var startDate: Date
    var targetDailyCalories: Double
    var familyMembers: Int
    var days: [DailyMealSlot]
}

struct EvaluatedNutrition: Codable, Equatable, Sendable {
    var bmrKcal: Double
    var tdeeKcal: Double
    var targetDailyKcal: Double
    var familyTotalKcal: Double
    var servingMultiplier: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
}
