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

enum VietnameseCuisineRegion: String, Codable, Equatable, Sendable, CaseIterable {
    case all
    case north
    case central
    case south

    var displayTitle: String {
        switch self {
        case .all:
            return "Tất cả 3 miền"
        case .north:
            return "Miền Bắc"
        case .central:
            return "Miền Trung"
        case .south:
            return "Miền Nam"
        }
    }
}

enum BreakfastPreference: String, Codable, Equatable, Sendable, CaseIterable {
    case mixed
    case street
    case home

    var displayTitle: String {
        switch self {
        case .mixed:
            return "Kết hợp quán & nhà"
        case .street:
            return "Ưu tiên ăn quán"
        case .home:
            return "Tự làm ở nhà"
        }
    }
}

enum DishSlotRole: String, Codable, Equatable, Sendable, CaseIterable {
    case breakfastStreet = "breakfast_street"
    case breakfastHome = "breakfast_home"
    case stapleRice = "staple_rice"
    case mainSavory = "main_savory"
    case soup = "soup"
    case fruit = "fruit"

    var displayTitle: String {
        switch self {
        case .breakfastStreet:
            return "Bữa sáng · Ăn quán"
        case .breakfastHome:
            return "Bữa sáng · Làm ở nhà"
        case .stapleRice:
            return "Cơm chính"
        case .mainSavory:
            return "Món mặn"
        case .soup:
            return "Món canh"
        case .fruit:
            return "Hoa quả tráng miệng"
        }
    }
}

enum MealType: String, Codable, Equatable, Sendable, CaseIterable, Hashable {
    case breakfast
    case lunch
    case dinner
    case snack
}

enum TraySlotTarget: Equatable, Sendable, Hashable {
    case breakfast
    case rice
    case savory(index: Int)
    case soup
    case fruit

    var displayLabel: String {
        switch self {
        case .breakfast:
            return "Bữa sáng"
        case .rice:
            return "Cơm chính"
        case .savory(let idx):
            return "Món mặn \(idx + 1)"
        case .soup:
            return "Món canh"
        case .fruit:
            return "Tráng miệng"
        }
    }
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
    var cuisineRegion: VietnameseCuisineRegion
    var isVegetarian: Bool
    var breakfastPreference: BreakfastPreference

    init(
        gender: Gender,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        activityLevel: ActivityLevel,
        goal: NutritionGoal,
        familyMembers: Int = 1,
        regionCode: String = "vn",
        unitSystem: UnitSystem = .metric,
        cuisineRegion: VietnameseCuisineRegion = .all,
        isVegetarian: Bool = false,
        breakfastPreference: BreakfastPreference = .mixed
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
        self.cuisineRegion = cuisineRegion
        self.isVegetarian = isVegetarian
        self.breakfastPreference = breakfastPreference
    }

    private enum CodingKeys: String, CodingKey {
        case gender
        case age
        case heightCm
        case weightKg
        case activityLevel
        case goal
        case familyMembers
        case regionCode
        case unitSystem
        case cuisineRegion
        case isVegetarian
        case breakfastPreference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.gender = try container.decode(Gender.self, forKey: .gender)
        self.age = try container.decode(Int.self, forKey: .age)
        self.heightCm = try container.decode(Double.self, forKey: .heightCm)
        self.weightKg = try container.decode(Double.self, forKey: .weightKg)
        self.activityLevel = try container.decode(ActivityLevel.self, forKey: .activityLevel)
        self.goal = try container.decode(NutritionGoal.self, forKey: .goal)
        let decodedFamily = try container.decodeIfPresent(Int.self, forKey: .familyMembers) ?? 1
        self.familyMembers = min(12, max(1, decodedFamily))
        self.regionCode = try container.decodeIfPresent(String.self, forKey: .regionCode) ?? "vn"
        self.unitSystem = try container.decodeIfPresent(UnitSystem.self, forKey: .unitSystem) ?? .metric
        self.cuisineRegion = try container.decodeIfPresent(VietnameseCuisineRegion.self, forKey: .cuisineRegion) ?? .all
        self.isVegetarian = try container.decodeIfPresent(Bool.self, forKey: .isVegetarian) ?? false
        self.breakfastPreference = try container.decodeIfPresent(BreakfastPreference.self, forKey: .breakfastPreference) ?? .mixed
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
    var slotRole: DishSlotRole
    var region: String
    var goals: [NutritionGoal]
    var isVegetarian: Bool
    var name: String
    var prepTimeMinutes: Int
    var baseNutrition: NutritionBreakdown
    var ingredients: [DishIngredient]
    var steps: [String]
}

struct MealTray: Codable, Equatable, Sendable {
    var riceId: String
    var savoryIds: [String]
    var soupId: String
    var fruitId: String

    var allDishIds: [String] {
        [riceId] + savoryIds + [soupId, fruitId]
    }
}

struct DailyMealSlot: Codable, Equatable, Sendable {
    var dayIndex: Int
    var breakfastId: String
    var lunchTray: MealTray
    var dinnerTray: MealTray
    var completedMeals: Set<MealType>

    var allDishIds: [String] {
        [breakfastId] + lunchTray.allDishIds + dinnerTray.allDishIds
    }
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
