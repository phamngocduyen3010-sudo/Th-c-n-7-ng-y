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

    func testLoadVietnameseCatalogContains120ComponentDishes() throws {
        let catalog = try loadTestCatalog()
        XCTAssertEqual(catalog.regionCode, "vn")
        XCTAssertEqual(catalog.dishes.count, 120)

        XCTAssertEqual(catalog.dishes.filter { $0.slotRole == .stapleRice }.count, 3)
        XCTAssertEqual(catalog.dishes.filter { $0.slotRole == .breakfastStreet }.count, 12)
        XCTAssertEqual(catalog.dishes.filter { $0.slotRole == .breakfastHome }.count, 12)
        XCTAssertEqual(catalog.dishes.filter { $0.slotRole == .mainSavory }.count, 54)
        XCTAssertEqual(catalog.dishes.filter { $0.slotRole == .soup }.count, 27)
        XCTAssertEqual(catalog.dishes.filter { $0.slotRole == .fruit }.count, 12)
    }

    func testWeeklyPlanBuildsFullVietnameseTraysWithoutFastFoodInMainMeals() throws {
        let catalog = try loadTestCatalog()
        let dishById = Dictionary(uniqueKeysWithValues: catalog.dishes.map { ($0.id, $0) })
        let profile = UserNutritionProfile(
            gender: .male,
            age: 28,
            heightCm: 175.0,
            weightKg: 80.0,
            activityLevel: .light,
            goal: .loseWeight,
            cuisineRegion: .north,
            isVegetarian: false
        )

        let plan = MenuLoader.generateWeeklyPlan(for: profile, catalog: catalog)
        XCTAssertEqual(plan.days.count, 7)

        for day in plan.days {
            let bDish = dishById[day.breakfastId]
            XCTAssertNotNil(bDish)
            XCTAssertTrue(bDish?.slotRole == .breakfastStreet || bDish?.slotRole == .breakfastHome)

            for tray in [day.lunchTray, day.dinnerTray] {
                XCTAssertEqual(dishById[tray.riceId]?.slotRole, .stapleRice)
                XCTAssertEqual(tray.savoryIds.count, 3)
                XCTAssertEqual(Set(tray.savoryIds).count, 3)
                for savId in tray.savoryIds {
                    XCTAssertEqual(dishById[savId]?.slotRole, .mainSavory)
                }
                XCTAssertEqual(dishById[tray.soupId]?.slotRole, .soup)
                XCTAssertEqual(dishById[tray.fruitId]?.slotRole, .fruit)
            }
        }
    }

    func testVegetarianModeStrictlyExcludesNonVegetarianDishes() throws {
        let catalog = try loadTestCatalog()
        let dishById = Dictionary(uniqueKeysWithValues: catalog.dishes.map { ($0.id, $0) })

        for region in VietnameseCuisineRegion.allCases {
            let vegProfile = UserNutritionProfile(
                gender: .female,
                age: 26,
                heightCm: 160.0,
                weightKg: 54.0,
                activityLevel: .light,
                goal: .maintain,
                cuisineRegion: region,
                isVegetarian: true
            )
            let plan = MenuLoader.generateWeeklyPlan(for: vegProfile, catalog: catalog)
            XCTAssertEqual(plan.days.count, 7)

            for day in plan.days {
                for dishId in day.allDishIds {
                    let dish = dishById[dishId]
                    XCTAssertNotNil(dish)
                    XCTAssertTrue(dish?.isVegetarian == true, "Non-veg dish \(dishId) leaked into vegetarian plan")
                }
            }
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
