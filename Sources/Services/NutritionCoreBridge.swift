import Foundation

enum NutritionCoreBridge: Sendable {
    static func evaluate(profile: UserNutritionProfile, baseDayCalories: Double = 1600.0) -> EvaluatedNutrition {
        let cGender: Int32 = profile.gender == .male
            ? Int32(TD_MALE.rawValue)
            : Int32(TD_FEMALE.rawValue)

        let cGoal: Int32
        switch profile.goal {
        case .loseWeight:
            cGoal = Int32(TD_LOSE_WEIGHT.rawValue)
        case .maintain:
            cGoal = Int32(TD_MAINTAIN.rawValue)
        case .gainWeight:
            cGoal = Int32(TD_GAIN_WEIGHT.rawValue)
        }

        let input = TDNutritionInput(
            gender: cGender,
            age: Int32(profile.age),
            height_cm: profile.heightCm,
            weight_kg: profile.weightKg,
            activity_factor: profile.activityLevel.factor,
            goal: cGoal,
            family_members: Int32(profile.familyMembers)
        )

        let result = td_evaluate_profile(input, baseDayCalories)
        return EvaluatedNutrition(
            bmrKcal: result.bmr_kcal,
            tdeeKcal: result.tdee_kcal,
            targetDailyKcal: result.target_daily_kcal,
            familyTotalKcal: result.family_total_kcal,
            servingMultiplier: result.serving_multiplier,
            proteinGrams: result.protein_g,
            carbsGrams: result.carbs_g,
            fatGrams: result.fat_g
        )
    }

    static func scaledDish(_ dish: Dish, multiplier: Double, familyMembers: Int) -> Dish {
        let cFamily = Int32(familyMembers)

        let scaledIngredients = dish.ingredients.map { ingredient in
            DishIngredient(
                id: ingredient.id,
                name: ingredient.name,
                amount: td_scale_amount(ingredient.amount, multiplier, cFamily),
                unit: ingredient.unit,
                category: ingredient.category
            )
        }

        let scaledNutrition = NutritionBreakdown(
            calories: td_scale_amount(dish.baseNutrition.calories, multiplier, cFamily),
            proteinGrams: td_scale_amount(dish.baseNutrition.proteinGrams, multiplier, cFamily),
            carbsGrams: td_scale_amount(dish.baseNutrition.carbsGrams, multiplier, cFamily),
            fatGrams: td_scale_amount(dish.baseNutrition.fatGrams, multiplier, cFamily),
            fiberGrams: td_scale_amount(dish.baseNutrition.fiberGrams, multiplier, cFamily)
        )

        return Dish(
            id: dish.id,
            mealTypes: dish.mealTypes,
            dietTags: dish.dietTags,
            name: dish.name,
            prepTimeMinutes: dish.prepTimeMinutes,
            baseNutrition: scaledNutrition,
            ingredients: scaledIngredients,
            steps: dish.steps
        )
    }

    static func convertUnit(amount: Double, unit: String, to system: UnitSystem) -> (amount: Double, unit: String) {
        guard system == .imperial else {
            return (amount, unit)
        }

        let normalized = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "g":
            return (amount / 28.3495, "oz")
        case "ml":
            return (amount / 29.5735, "fl oz")
        default:
            return (amount, unit)
        }
    }
}
