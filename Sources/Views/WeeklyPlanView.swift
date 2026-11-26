import SwiftUI

struct WeeklyPlanView: View {
    @ObservedObject var store: MealPlanStore
    @EnvironmentObject private var adManager: MealAdManager
    @State private var selectedDay: Int = 1

    private func goalTitle(_ goal: NutritionGoal) -> String {
        switch goal {
        case .loseWeight: return "Giảm cân"
        case .maintain: return "Giữ cân"
        case .gainWeight: return "Tăng cân"
        }
    }

    private func roleIcon(_ role: DishSlotRole) -> (symbol: String, color: Color) {
        switch role {
        case .breakfastStreet: return ("takeoutbag.and.cup.and.straw.fill", .orange)
        case .breakfastHome: return ("sunrise.fill", .orange)
        case .stapleRice: return ("flame.fill", .brown)
        case .mainSavory: return ("fork.knife", .blue)
        case .soup: return ("drop.fill", .teal)
        case .fruit: return ("leaf.fill", .green)
        }
    }

    private func perPersonKcal(_ dish: Dish) -> Int {
        Int((dish.baseNutrition.calories / Double(max(1, store.profile.familyMembers))).rounded())
    }

    private func trayTotalPerPersonKcal(_ items: [ScaledTrayItem]) -> Int {
        let total = items.reduce(0.0) { $0 + $1.dish.baseNutrition.calories }
        return Int((total / Double(max(1, store.profile.familyMembers))).rounded())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                Button {
                                    if selectedDay != day {
                                        selectedDay = day
                                        adManager.recordInteraction()
                                    }
                                } label: {
                                    Text("Ngày \(day)")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedDay == day
                                                ? Color.blue
                                                : Color(.tertiarySystemFill),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selectedDay == day ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Picker(
                        "Khẩu vị vùng miền",
                        selection: Binding(
                            get: { store.profile.cuisineRegion },
                            set: { newRegion in
                                store.updateCuisineRegion(newRegion)
                                adManager.recordInteraction()
                            }
                        )
                    ) {
                        ForEach(VietnameseCuisineRegion.allCases, id: \.self) { region in
                            Text(region.displayTitle).tag(region)
                        }
                    }

                    Toggle(
                        "Chế độ ăn chay",
                        isOn: Binding(
                            get: { store.profile.isVegetarian },
                            set: { newVal in
                                store.updateVegetarian(newVal)
                                adManager.recordInteraction()
                            }
                        )
                    )

                    Stepper(
                        value: Binding(
                            get: { store.profile.familyMembers },
                            set: { store.updateFamilyMembers($0) }
                        ),
                        in: 1...8
                    ) {
                        HStack {
                            Text("Khẩu phần nấu")
                            Spacer()
                            Text("\(store.profile.familyMembers) người")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    let dietLabel = store.profile.isVegetarian ? "Ăn chay · " : ""
                    Text("\(dietLabel)\(store.profile.cuisineRegion.displayTitle) · \(goalTitle(store.profile.goal))")
                }

                if let detail = store.dayDetails(for: selectedDay) {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mục tiêu 1 người")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(detail.evaluation.targetDailyKcal.rounded())) kcal")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.green)
                                    .monospacedDigit()
                            }
                            Spacer()
                            if store.profile.familyMembers > 1 {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Tổng \(store.profile.familyMembers) người")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(Int(detail.evaluation.familyTotalKcal.rounded())) kcal")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.blue)
                                        .monospacedDigit()
                                }
                            }
                        }

                        HStack(spacing: 0) {
                            macroColumn(label: "Đạm / 1 người", value: "\(Int(detail.evaluation.proteinGrams.rounded()))g")
                            Divider().frame(height: 28)
                            macroColumn(label: "Tinh bột / 1 người", value: "\(Int(detail.evaluation.carbsGrams.rounded()))g")
                            Divider().frame(height: 28)
                            macroColumn(label: "Chất béo / 1 người", value: "\(Int(detail.evaluation.fatGrams.rounded()))g")
                        }
                        .padding(.vertical, 2)
                    } header: {
                        Text("Tổng kết dinh dưỡng Ngày \(selectedDay)")
                    }

                    // BỮA SÁNG
                    if let breakfast = detail.breakfast {
                        let isDone = detail.slot.completedMeals.contains(.breakfast)
                        let icon = roleIcon(breakfast.slotRole)
                        Section {
                            HStack(spacing: 12) {
                                Button {
                                    store.toggleMealCompleted(dayIndex: selectedDay, mealType: .breakfast)
                                } label: {
                                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(isDone ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    DishDetailView(
                                        store: store,
                                        dayIndex: selectedDay,
                                        mealType: .breakfast,
                                        target: .breakfast,
                                        scaledDish: breakfast
                                    )
                                } label: {
                                    dishRowContent(
                                        subtitle: breakfast.slotRole == .breakfastStreet ? "Ăn quán tiện lợi" : "Làm nhanh ở nhà",
                                        dish: breakfast,
                                        iconSymbol: icon.symbol,
                                        iconColor: icon.color,
                                        isDone: isDone
                                    )
                                }
                            }
                        } header: {
                            Text("Bữa sáng · \(perPersonKcal(breakfast)) kcal / người")
                        }
                    }

                    // BỮA TRƯA (MÂM CƠM CHUẨN: CƠM + 3 MÓN MẶN + 1 CANH + 1 HOA QUẢ)
                    mealTraySection(
                        title: "Bữa trưa · Mâm cơm (\(trayTotalPerPersonKcal(detail.lunchItems)) kcal)",
                        mealType: .lunch,
                        items: detail.lunchItems,
                        isDone: detail.slot.completedMeals.contains(.lunch)
                    )

                    // BỮA TỐI (MÂM CƠM CHUẨN: CƠM + 3 MÓN MẶN + 1 CANH + 1 HOA QUẢ)
                    mealTraySection(
                        title: "Bữa tối · Mâm cơm (\(trayTotalPerPersonKcal(detail.dinnerItems)) kcal)",
                        mealType: .dinner,
                        items: detail.dinnerItems,
                        isDone: detail.slot.completedMeals.contains(.dinner)
                    )
                } else {
                    Section {
                        Text(store.loadErrorMessage ?? "Chưa có dữ liệu thực đơn.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Thực đơn 7 ngày")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.regenerateWeeklyPlan()
                        adManager.recordInteraction()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityLabel("Tạo lại thực đơn tuần")
                }
            }
        }
    }

    @ViewBuilder
    private func mealTraySection(
        title: String,
        mealType: MealType,
        items: [ScaledTrayItem],
        isDone: Bool
    ) -> some View {
        Section {
            Button {
                store.toggleMealCompleted(dayIndex: selectedDay, mealType: mealType)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isDone ? .green : .secondary)
                    Text(isDone ? "Đã hoàn thành mâm cơm này" : "Đánh dấu hoàn thành bữa ăn")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isDone ? .secondary : .primary)
                }
            }

            ForEach(items) { item in
                let icon = roleIcon(item.dish.slotRole)
                NavigationLink {
                    DishDetailView(
                        store: store,
                        dayIndex: selectedDay,
                        mealType: mealType,
                        target: item.target,
                        scaledDish: item.dish
                    )
                } label: {
                    dishRowContent(
                        subtitle: item.target.displayLabel,
                        dish: item.dish,
                        iconSymbol: icon.symbol,
                        iconColor: icon.color,
                        isDone: isDone
                    )
                }
            }
        } header: {
            Text(title)
        }
    }

    private func dishRowContent(
        subtitle: String,
        dish: Dish,
        iconSymbol: String,
        iconColor: Color,
        isDone: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 29, height: 29)
                Image(systemName: iconSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dish.name)
                    .font(.body)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)
                Text("\(perPersonKcal(dish)) kcal / người · \(dish.prepTimeMinutes) phút")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    private func macroColumn(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
