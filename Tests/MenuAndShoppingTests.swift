import XCTest
@testable import ThucDon7Ngay

final class MenuAndShoppingTests: XCTestCase {
    private func loadTestCatalog() throws -> MenuCatalog {
        let bundles = [Bundle.main, Bundle(for: MenuAndShoppingTests.self)]
        for bundle in bundles {
            if let catalog = try? MenuLoader.loadCatalog(regionCode: "vn", bundle: bundle) {
                return catalog
            }
        }
        XCTFail("Missing menu_vn.json in test/app bundles")
        throw MenuLoaderError.fileNotFound("menu_vn.json")
    }

    func testLoadVietnameseCatalogContains9Dishes() throws {
        let catalog = try loadTestCatalog()
        XCTAssertEqual(catalog.regionCode, "vn")
        XCTAssertEqual(catalog.dishes.count, 9)
    }

    func testGenerateWeeklyPlanHas7DaysWithoutConsecutiveDuplicates() throws {
        let catalog = try loadTestCatalog()
        let profile = UserNutritionProfile(
            gender: .male,
            age: 28,
            heightCm: 175.0,
            weightKg: 80.0,
            activityLevel: .light,
            goal: .loseWeight
        )

        let plan = MenuLoader.generateWeeklyPlan(for: profile, catalog: catalog)
        XCTAssertEqual(plan.days.count, 7)

        for idx in 1..<plan.days.count {
            XCTAssertNotEqual(plan.days[idx].breakfastId, plan.days[idx - 1].breakfastId)
            XCTAssertNotEqual(plan.days[idx].lunchId, plan.days[idx - 1].lunchId)
            XCTAssertNotEqual(plan.days[idx].dinnerId, plan.days[idx - 1].dinnerId)
        }
    }

    func testShoppingListAggregatesAndScalesWithFamilyMembers() throws {
        let catalog = try loadTestCatalog()
        let singleProfile = UserNutritionProfile(
            gender: .male,
            age: 28,
            heightCm: 175.0,
            weightKg: 80.0,
            activityLevel: .light,
            goal: .loseWeight,
            familyMembers: 1
        )
        let familyProfile = UserNutritionProfile(
            gender: .male,
            age: 28,
            heightCm: 175.0,
            weightKg: 80.0,
            activityLevel: .light,
            goal: .loseWeight,
            familyMembers: 4
        )

        let planSingle = MenuLoader.generateWeeklyPlan(for: singleProfile, catalog: catalog)
        let planFamily = MenuLoader.generateWeeklyPlan(for: familyProfile, catalog: catalog)

        let singleItems = ShoppingListGenerator.generate(from: planSingle, catalog: catalog, profile: singleProfile)
        let familyItems = ShoppingListGenerator.generate(from: planFamily, catalog: catalog, profile: familyProfile)

        XCTAssertFalse(singleItems.isEmpty)
        XCTAssertEqual(singleItems.count, familyItems.count)

        if let firstSingle = singleItems.first, let firstFamily = familyItems.first(where: { $0.id == firstSingle.id }) {
            XCTAssertEqual(firstFamily.totalAmount, firstSingle.totalAmount * 4.0, accuracy: 0.5)
        }
    }
}
