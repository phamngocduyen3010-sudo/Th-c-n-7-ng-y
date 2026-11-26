import Combine
import Foundation

@MainActor
final class MealPlanStore: ObservableObject {
    private enum StorageKey {
        static let profile = "td_user_profile_v1"
        static let onboardingDone = "td_onboarding_done_v1"
        static let weeklyPlan = "td_weekly_plan_v1"
        static let checkedShopping = "td_checked_shopping_v1"
    }

    @Published var profile: UserNutritionProfile
    @Published var hasCompletedOnboarding: Bool
    @Published var catalog: MenuCatalog
    @Published var currentPlan: WeeklyMealPlan
    @Published var checkedShoppingIds: Set<String>
    @Published var loadErrorMessage: String?

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedProfile: UserNutritionProfile
        if let data = defaults.data(forKey: StorageKey.profile),
           let decoded = try? JSONDecoder().decode(UserNutritionProfile.self, from: data) {
            savedProfile = decoded
        } else {
            savedProfile = UserNutritionProfile(
                gender: .male,
                age: 28,
                heightCm: 170,
                weightKg: 68,
                activityLevel: .light,
                goal: .loseWeight,
                familyMembers: 1,
                regionCode: "vn",
                unitSystem: .metric
            )
        }
        self.profile = savedProfile
        self.hasCompletedOnboarding = defaults.bool(forKey: StorageKey.onboardingDone)

        if let data = defaults.data(forKey: StorageKey.checkedShopping),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.checkedShoppingIds = ids
        } else {
            self.checkedShoppingIds = []
        }

        let loadedCatalog: MenuCatalog
        do {
            loadedCatalog = try MenuLoader.loadCatalog(regionCode: savedProfile.regionCode)
            self.loadErrorMessage = nil
        } catch {
            loadedCatalog = MenuCatalog(regionCode: savedProfile.regionCode, version: "1.0", dishes: [])
            self.loadErrorMessage = error.localizedDescription
        }
        self.catalog = loadedCatalog

        if let data = defaults.data(forKey: StorageKey.weeklyPlan),
           let savedPlan = try? JSONDecoder().decode(WeeklyMealPlan.self, from: data),
           savedPlan.days.count == 7 {
            self.currentPlan = savedPlan
        } else {
            self.currentPlan = MenuLoader.generateWeeklyPlan(for: savedProfile, catalog: loadedCatalog)
        }
    }

    func saveProfile(_ updatedProfile: UserNutritionProfile, regeneratePlan: Bool = true) {
        let regionChanged = updatedProfile.regionCode != profile.regionCode
        profile = updatedProfile
        hasCompletedOnboarding = true
        defaults.set(true, forKey: StorageKey.onboardingDone)
        persistProfile()

        if regionChanged || catalog.dishes.isEmpty {
            do {
                catalog = try MenuLoader.loadCatalog(regionCode: updatedProfile.regionCode)
                loadErrorMessage = nil
            } catch {
                loadErrorMessage = error.localizedDescription
            }
        }

        if regeneratePlan || currentPlan.days.count != 7 {
            currentPlan = MenuLoader.generateWeeklyPlan(for: updatedProfile, catalog: catalog)
            checkedShoppingIds = []
            persistCheckedShopping()
        } else {
            let eval = NutritionCoreBridge.evaluate(profile: updatedProfile)
            currentPlan.targetDailyCalories = eval.targetDailyKcal
            currentPlan.familyMembers = updatedProfile.familyMembers
        }
        persistPlan()
    }

    func updateFamilyMembers(_ members: Int) {
        let clamped = min(12, max(1, members))
        guard clamped != profile.familyMembers else { return }
        profile.familyMembers = clamped
        currentPlan.familyMembers = clamped
        persistProfile()
        persistPlan()
    }

    func regenerateWeeklyPlan() {
        currentPlan = MenuLoader.generateWeeklyPlan(for: profile, catalog: catalog)
        checkedShoppingIds = []
        persistPlan()
        persistCheckedShopping()
    }

    func toggleMealCompleted(dayIndex: Int, mealType: MealType) {
        guard let idx = currentPlan.days.firstIndex(where: { $0.dayIndex == dayIndex }) else { return }
        if currentPlan.days[idx].completedMeals.contains(mealType) {
            currentPlan.days[idx].completedMeals.remove(mealType)
        } else {
            currentPlan.days[idx].completedMeals.insert(mealType)
        }
        persistPlan()
    }

    func swapDish(dayIndex: Int, mealType: MealType, newDishId: String) {
        guard let idx = currentPlan.days.firstIndex(where: { $0.dayIndex == dayIndex }) else { return }
        switch mealType {
        case .breakfast:
            currentPlan.days[idx].breakfastId = newDishId
        case .lunch:
            currentPlan.days[idx].lunchId = newDishId
        case .dinner:
            currentPlan.days[idx].dinnerId = newDishId
        case .snack:
            break
        }
        persistPlan()
    }

    func dish(byId id: String) -> Dish? {
        catalog.dishes.first { $0.id == id }
    }

    func dayDetails(for dayIndex: Int) -> (slot: DailyMealSlot, evaluation: EvaluatedNutrition, meals: [(MealType, Dish)])? {
        guard let slot = currentPlan.days.first(where: { $0.dayIndex == dayIndex }) else { return nil }
        let pairs: [(MealType, String)] = [
            (.breakfast, slot.breakfastId),
            (.lunch, slot.lunchId),
            (.dinner, slot.dinnerId)
        ]
        let rawDishes: [(MealType, Dish)] = pairs.compactMap { mealType, dishId in
            guard let found = dish(byId: dishId) else { return nil }
            return (mealType, found)
        }
        let baseCalories = rawDishes.reduce(0.0) { $0 + $1.1.baseNutrition.calories }
        let eval = NutritionCoreBridge.evaluate(
            profile: profile,
            baseDayCalories: baseCalories > 0.0 ? baseCalories : 1600.0
        )
        let scaledMeals: [(MealType, Dish)] = rawDishes.map { mealType, rawDish in
            let scaled = NutritionCoreBridge.scaledDish(
                rawDish,
                multiplier: eval.servingMultiplier,
                familyMembers: profile.familyMembers
            )
            return (mealType, scaled)
        }
        return (slot, eval, scaledMeals)
    }

    func shoppingItems() -> [ShoppingListItem] {
        ShoppingListGenerator.generate(from: currentPlan, catalog: catalog, profile: profile).map { item in
            var copy = item
            copy.isChecked = checkedShoppingIds.contains(item.id)
            return copy
        }
    }

    func toggleShoppingItem(_ id: String) {
        if checkedShoppingIds.contains(id) {
            checkedShoppingIds.remove(id)
        } else {
            checkedShoppingIds.insert(id)
        }
        persistCheckedShopping()
    }

    func resetShoppingChecks() {
        checkedShoppingIds = []
        persistCheckedShopping()
    }

    private func persistProfile() {
        if let data = try? encoder.encode(profile) {
            defaults.set(data, forKey: StorageKey.profile)
        }
    }

    private func persistPlan() {
        if let data = try? encoder.encode(currentPlan) {
            defaults.set(data, forKey: StorageKey.weeklyPlan)
        }
    }

    private func persistCheckedShopping() {
        if let data = try? encoder.encode(checkedShoppingIds) {
            defaults.set(data, forKey: StorageKey.checkedShopping)
        }
    }
}
