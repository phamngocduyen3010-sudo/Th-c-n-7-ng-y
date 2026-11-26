import XCTest
@testable import ThucDon7Ngay

final class NutritionCoreTests: XCTestCase {
    func testMaleLoseWeightEvaluation() {
        let profile = UserNutritionProfile(
            gender: .male,
            age: 28,
            heightCm: 175.0,
            weightKg: 80.0,
            activityLevel: .light,
            goal: .loseWeight
        )

        let result = NutritionCoreBridge.evaluate(profile: profile)

        XCTAssertEqual(result.bmrKcal, 1758.75, accuracy: 0.01)
        XCTAssertEqual(result.tdeeKcal, 2418.28125, accuracy: 0.01)
        XCTAssertEqual(result.targetDailyKcal, 2018.28125, accuracy: 0.01)
        XCTAssertEqual(result.servingMultiplier, 1.25, accuracy: 0.001)
    }

    func testFemaleLoseWeightEnforces1200KcalSafetyFloor() {
        let profile = UserNutritionProfile(
            gender: .female,
            age: 30,
            heightCm: 155.0,
            weightKg: 48.0,
            activityLevel: .sedentary,
            goal: .loseWeight
        )

        let result = NutritionCoreBridge.evaluate(profile: profile)

        XCTAssertEqual(result.targetDailyKcal, 1200.0, accuracy: 0.001)
    }

    func testMaleGainWeightEvaluation() {
        let profile = UserNutritionProfile(
            gender: .male,
            age: 24,
            heightCm: 170.0,
            weightKg: 56.0,
            activityLevel: .moderate,
            goal: .gainWeight
        )

        let result = NutritionCoreBridge.evaluate(profile: profile)

        XCTAssertEqual(result.targetDailyKcal, 2686.625, accuracy: 0.01)
    }

    func testZeroBaseCaloriesSafetyAndFamilyDishScaling() {
        let profile = UserNutritionProfile(
            gender: .male,
            age: 28,
            heightCm: 175.0,
            weightKg: 80.0,
            activityLevel: .light,
            goal: .loseWeight,
            familyMembers: 4
        )

        let zeroBaseResult = NutritionCoreBridge.evaluate(profile: profile, baseDayCalories: 0.0)
        XCTAssertEqual(zeroBaseResult.servingMultiplier, 1.0, accuracy: 0.001)

        let sampleDish = Dish(
            id: "ga-ap-chao",
            mealTypes: [.lunch, .dinner],
            dietTags: ["high-protein"],
            name: "Ức gà áp chảo",
            prepTimeMinutes: 20,
            baseNutrition: NutritionBreakdown(
                calories: 400.0,
                proteinGrams: 40.0,
                carbsGrams: 30.0,
                fatGrams: 12.0,
                fiberGrams: 5.0
            ),
            ingredients: [
                DishIngredient(id: "ing-1", name: "Ức gà", amount: 150.0, unit: "g", category: "Thịt"),
                DishIngredient(id: "ing-2", name: "Dầu ô liu", amount: 10.0, unit: "ml", category: "Gia vị")
            ],
            steps: ["Áp chảo chín vàng hai mặt."]
        )

        let scaled = NutritionCoreBridge.scaledDish(sampleDish, multiplier: 1.25, familyMembers: 4)

        XCTAssertEqual(scaled.ingredients[0].amount, 750.0, accuracy: 0.001)
        XCTAssertEqual(scaled.ingredients[1].amount, 50.0, accuracy: 0.001)
        XCTAssertEqual(scaled.baseNutrition.calories, 2000.0, accuracy: 0.001)
        XCTAssertEqual(scaled.baseNutrition.proteinGrams, 200.0, accuracy: 0.001)
    }
}
