import Foundation

struct ShoppingListItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let category: String
    let totalAmount: Double
    let unit: String
    var isChecked: Bool
}

enum ShoppingListGenerator: Sendable {
    private struct AggregationBucket {
        let displayName: String
        let category: String
        var totalAmount: Double
        let unit: String
    }

    static func generate(
        from plan: WeeklyMealPlan,
        catalog: MenuCatalog,
        profile: UserNutritionProfile
    ) -> [ShoppingListItem] {
        let dishById = Dictionary(uniqueKeysWithValues: catalog.dishes.map { ($0.id, $0) })
        var buckets: [String: AggregationBucket] = [:]

        for day in plan.days {
            let dayDishes = day.allDishIds.compactMap { dishById[$0] }
            let baseDayCalories = dayDishes.reduce(0.0) { $0 + $1.baseNutrition.calories }
            let evaluation = NutritionCoreBridge.evaluate(
                profile: profile,
                baseDayCalories: baseDayCalories > 0.0 ? baseDayCalories : 1600.0
            )

            for dish in dayDishes {
                let scaled = NutritionCoreBridge.scaledDish(
                    dish,
                    multiplier: evaluation.servingMultiplier,
                    familyMembers: profile.familyMembers
                )

                for ingredient in scaled.ingredients {
                    let converted = NutritionCoreBridge.convertUnit(
                        amount: ingredient.amount,
                        unit: ingredient.unit,
                        to: profile.unitSystem
                    )

                    let normalizedName = ingredient.name
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .folding(options: [.caseInsensitive], locale: .current)
                    let normalizedUnit = converted.unit
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    let key = "\(normalizedName)|\(normalizedUnit)"

                    if var existing = buckets[key] {
                        existing.totalAmount += converted.amount
                        buckets[key] = existing
                    } else {
                        buckets[key] = AggregationBucket(
                            displayName: ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: ingredient.category,
                            totalAmount: converted.amount,
                            unit: converted.unit
                        )
                    }
                }
            }
        }

        return buckets.map { key, bucket in
            ShoppingListItem(
                id: key,
                name: bucket.displayName,
                category: bucket.category,
                totalAmount: (bucket.totalAmount * 10.0).rounded() / 10.0,
                unit: bucket.unit,
                isChecked: false
            )
        }
        .sorted { lhs, rhs in
            if lhs.category != rhs.category {
                return lhs.category.localizedStandardCompare(rhs.category) == .orderedAscending
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
