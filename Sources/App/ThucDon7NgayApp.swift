import SwiftUI

@main
struct ThucDon7NgayApp: App {
    @StateObject private var store = MealPlanStore()

    var body: some Scene {
        WindowGroup {
            if store.hasCompletedOnboarding {
                TabView {
                    WeeklyPlanView(store: store)
                        .tabItem {
                            Label("Thực đơn", systemImage: "fork.knife")
                        }

                    ShoppingListView(store: store)
                        .tabItem {
                            Label("Đi chợ", systemImage: "cart.fill")
                        }

                    SettingsAndLegalView(store: store)
                        .tabItem {
                            Label("Hồ sơ", systemImage: "person.crop.circle")
                        }
                }
            } else {
                OnboardingView(store: store, isModalEdit: false)
            }
        }
    }
}
