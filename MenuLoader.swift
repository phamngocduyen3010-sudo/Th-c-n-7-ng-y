import Foundation

struct MenuCatalog: Codable, Equatable, Sendable {
    let regionCode: String
    let version: String
    let dishes: [Dish]
}

enum MenuLoaderError: Error, LocalizedError, Equatable, Sendable {
    case fileNotFound(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Không tìm thấy tệp dữ liệu thực đơn: \(name)"
        case .decodeFailed(let detail):
            return "Lỗi đọc dữ liệu thực đơn: \(detail)"
        }
    }
}

enum MenuLoader: Sendable {
    static func loadCatalog(regionCode: String, bundle: Bundle = .main) throws -> MenuCatalog {
        let normalizedCode = regionCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let resourceName = "menu_\(normalizedCode.isEmpty ? "vn" : normalizedCode)"

        let candidateURL = bundle.url(forResource: resourceName, withExtension: "json")
            ?? bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Menus")
            ?? bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources/Menus")

        guard let url = candidateURL else {
            throw MenuLoaderError.fileNotFound("\(resourceName).json")
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(MenuCatalog.self, from: data)
        } catch let error as DecodingError {
            throw MenuLoaderError.decodeFailed(error.localizedDescription)
        } catch {
            throw MenuLoaderError.decodeFailed(error.localizedDescription)
        }
    }

    static func generateWeeklyPlan(
        for profile: UserNutritionProfile,
        catalog: MenuCatalog,
        startDate: Date = Date()
    ) -> WeeklyMealPlan {
        let evaluation = NutritionCoreBridge.evaluate(profile: profile)
        let breakfasts = catalog.dishes.filter { $0.mealTypes.contains(.breakfast) }
        let lunches = catalog.dishes.filter { $0.mealTypes.contains(.lunch) }
        let dinners = catalog.dishes.filter { $0.mealTypes.contains(.dinner) }

        var slots: [DailyMealSlot] = []
        var prevBreakfast: String?
        var prevLunch: String?
        var prevDinner: String?

        for dayIndex in 1...7 {
            let bDish = pickNonConsecutive(from: breakfasts, dayIndex: dayIndex, previousId: prevBreakfast)
            let lDish = pickNonConsecutive(from: lunches, dayIndex: dayIndex, previousId: prevLunch)
            let dDish = pickNonConsecutive(from: dinners, dayIndex: dayIndex, previousId: prevDinner)

            let bId = bDish?.id ?? ""
            let lId = lDish?.id ?? ""
            let dId = dDish?.id ?? ""

            prevBreakfast = bId
            prevLunch = lId
            prevDinner = dId

            slots.append(
                DailyMealSlot(
                    dayIndex: dayIndex,
                    breakfastId: bId,
                    lunchId: lId,
                    dinnerId: dId,
                    completedMeals: []
                )
            )
        }

        return WeeklyMealPlan(
            id: UUID(),
            regionCode: catalog.regionCode,
            startDate: startDate,
            targetDailyCalories: evaluation.targetDailyKcal,
            familyMembers: profile.familyMembers,
            days: slots
        )
    }

    static func alternativeDishes(
        for mealType: MealType,
        excluding dishId: String,
        in catalog: MenuCatalog
    ) -> [Dish] {
        catalog.dishes.filter { dish in
            dish.mealTypes.contains(mealType) && dish.id != dishId
        }
    }

    private static func pickNonConsecutive(
        from pool: [Dish],
        dayIndex: Int,
        previousId: String?
    ) -> Dish? {
        guard !pool.isEmpty else { return nil }
        if pool.count == 1 { return pool[0] }

        let startOffset = (dayIndex - 1) % pool.count
        let candidate = pool[startOffset]
        if candidate.id != previousId {
            return candidate
        }
        return pool[(startOffset + 1) % pool.count]
    }
}
