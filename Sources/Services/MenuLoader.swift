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

    static func breakfastRoles(for preference: BreakfastPreference) -> Set<DishSlotRole> {
        switch preference {
        case .mixed:
            return [.breakfastStreet, .breakfastHome]
        case .street:
            return [.breakfastStreet]
        case .home:
            return [.breakfastHome]
        }
    }

    static func filteredPool(
        from catalog: MenuCatalog,
        roles: Set<DishSlotRole>,
        profile: UserNutritionProfile,
        minCount: Int = 1
    ) -> [Dish] {
        // Hard constraints: exact slot role + strict vegetarian separation when enabled
        let base = catalog.dishes.filter { dish in
            roles.contains(dish.slotRole) && (!profile.isVegetarian || dish.isVegetarian)
        }
        guard !base.isEmpty else { return [] }

        let regionMatches: [Dish]
        if profile.cuisineRegion == .all {
            regionMatches = base
        } else {
            let targetRegion = profile.cuisineRegion.rawValue
            let filtered = base.filter { $0.region == targetRegion || $0.region == "all" }
            regionMatches = filtered.count >= minCount ? filtered : base
        }

        let goalAndRegion = regionMatches.filter { $0.goals.contains(profile.goal) }
        if goalAndRegion.count >= minCount {
            return goalAndRegion
        }

        let goalAnyRegion = base.filter { $0.goals.contains(profile.goal) }
        if goalAnyRegion.count >= minCount && profile.cuisineRegion == .all {
            return goalAnyRegion
        }

        return regionMatches.count >= minCount ? regionMatches : base
    }

    static func generateWeeklyPlan(
        for profile: UserNutritionProfile,
        catalog: MenuCatalog,
        startDate: Date = Date(),
        seed: Int = 0
    ) -> WeeklyMealPlan {
        let evaluation = NutritionCoreBridge.evaluate(profile: profile)
        let bRoles = breakfastRoles(for: profile.breakfastPreference)

        var breakfasts = filteredPool(from: catalog, roles: bRoles, profile: profile, minCount: 2)
        if breakfasts.isEmpty {
            breakfasts = filteredPool(from: catalog, roles: [.breakfastStreet, .breakfastHome], profile: profile, minCount: 1)
        }

        let rices = filteredPool(from: catalog, roles: [.stapleRice], profile: profile, minCount: 1)
        let savories = filteredPool(from: catalog, roles: [.mainSavory], profile: profile, minCount: 6)
        let soups = filteredPool(from: catalog, roles: [.soup], profile: profile, minCount: 2)
        let fruits = filteredPool(from: catalog, roles: [.fruit], profile: profile, minCount: 2)

        var slots: [DailyMealSlot] = []
        var prevBreakfast: String?
        let safeSeed = max(0, seed)

        for dayIndex in 1...7 {
            let dayOffset = (dayIndex - 1) + safeSeed * 7

            let bDish = pickSingle(from: breakfasts, offset: dayOffset, excluding: prevBreakfast.map { [$0] } ?? [])
            let bId = bDish?.id ?? ""
            prevBreakfast = bId

            // Lunch Tray: 1 Rice + 3 Distinct Savory + 1 Soup + 1 Fruit
            let lunchRice = pickSingle(from: rices, offset: dayOffset, excluding: [])?.id ?? ""
            let lunchSavories = pickDistinct(from: savories, count: 3, startOffset: dayOffset * 3, excluding: [])
            let lunchSoup = pickSingle(from: soups, offset: dayOffset * 2, excluding: [])?.id ?? ""
            let lunchFruit = pickSingle(from: fruits, offset: dayOffset * 2, excluding: [])?.id ?? ""

            let lunchTray = MealTray(
                riceId: lunchRice,
                savoryIds: lunchSavories,
                soupId: lunchSoup,
                fruitId: lunchFruit
            )

            // Dinner Tray: 1 Rice + 3 Distinct Savory (avoiding lunch savories) + 1 Soup + 1 Fruit
            let dinnerRice = pickSingle(from: rices, offset: dayOffset + 1, excluding: [])?.id ?? ""
            let dinnerSavories = pickDistinct(
                from: savories,
                count: 3,
                startOffset: dayOffset * 3 + 3,
                excluding: Set(lunchSavories)
            )
            let dinnerSoup = pickSingle(from: soups, offset: dayOffset * 2 + 1, excluding: [lunchSoup])?.id ?? ""
            let dinnerFruit = pickSingle(from: fruits, offset: dayOffset * 2 + 1, excluding: [lunchFruit])?.id ?? ""

            let dinnerTray = MealTray(
                riceId: dinnerRice,
                savoryIds: dinnerSavories,
                soupId: dinnerSoup,
                fruitId: dinnerFruit
            )

            slots.append(
                DailyMealSlot(
                    dayIndex: dayIndex,
                    breakfastId: bId,
                    lunchTray: lunchTray,
                    dinnerTray: dinnerTray,
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
        for target: TraySlotTarget,
        excluding excludedIds: Set<String>,
        in catalog: MenuCatalog,
        profile: UserNutritionProfile
    ) -> [Dish] {
        let roles: Set<DishSlotRole>
        switch target {
        case .breakfast:
            roles = breakfastRoles(for: profile.breakfastPreference)
        case .rice:
            roles = [.stapleRice]
        case .savory:
            roles = [.mainSavory]
        case .soup:
            roles = [.soup]
        case .fruit:
            roles = [.fruit]
        }

        let pool = filteredPool(from: catalog, roles: roles, profile: profile, minCount: 2)
        return pool.filter { !excludedIds.contains($0.id) }
    }

    private static func pickSingle(
        from pool: [Dish],
        offset: Int,
        excluding excluded: Set<String>
    ) -> Dish? {
        guard !pool.isEmpty else { return nil }
        for step in 0..<pool.count {
            let candidate = pool[(offset + step) % pool.count]
            if !excluded.contains(candidate.id) {
                return candidate
            }
        }
        return pool[offset % pool.count]
    }

    private static func pickDistinct(
        from pool: [Dish],
        count: Int,
        startOffset: Int,
        excluding excluded: Set<String>
    ) -> [String] {
        guard !pool.isEmpty else { return [] }
        var picked: [String] = []
        var used = excluded

        for step in 0..<pool.count where picked.count < count {
            let candidate = pool[(startOffset + step) % pool.count]
            if !used.contains(candidate.id) {
                picked.append(candidate.id)
                used.insert(candidate.id)
            }
        }

        // If pool is small, fill remaining avoiding duplicates within the same tray
        for step in 0..<pool.count where picked.count < count {
            let candidate = pool[(startOffset + step) % pool.count]
            if !picked.contains(candidate.id) {
                picked.append(candidate.id)
            }
        }

        return picked
    }
}
