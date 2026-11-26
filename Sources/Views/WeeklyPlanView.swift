import SwiftUI

struct WeeklyPlanView: View {
    @ObservedObject var store: MealPlanStore
    @State private var selectedDay: Int = 1

    private func goalTitle(_ goal: NutritionGoal) -> String {
        switch goal {
        case .loseWeight: return "Giảm cân"
        case .maintain: return "Giữ cân"
        case .gainWeight: return "Tăng cân"
        }
    }

    private func mealMeta(_ type: MealType) -> (title: String, symbol: String, color: Color) {
        switch type {
        case .breakfast: return ("Bữa sáng", "sunrise.fill", .orange)
        case .lunch: return ("Bữa trưa", "sun.max.fill", .blue)
        case .dinner: return ("Bữa tối", "moon.stars.fill", .indigo)
        case .snack: return ("Bữa phụ", "leaf.fill", .green)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                Button {
                                    selectedDay = day
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
                    Text("Khu vực: Việt Nam · \(goalTitle(store.profile.goal))")
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

                    Section("Thực đơn 3 bữa") {
                        ForEach(detail.meals, id: \.0) { mealType, scaledDish in
                            let meta = mealMeta(mealType)
                            let isDone = detail.slot.completedMeals.contains(mealType)
                            let perPersonKcal = Int((scaledDish.baseNutrition.calories / Double(max(1, store.profile.familyMembers))).rounded())

                            HStack(spacing: 12) {
                                Button {
                                    store.toggleMealCompleted(dayIndex: selectedDay, mealType: mealType)
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
                                        mealType: mealType,
                                        scaledDish: scaledDish
                                    )
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(meta.color)
                                                .frame(width: 29, height: 29)
                                            Image(systemName: meta.symbol)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(meta.title)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(scaledDish.name)
                                                .font(.body)
                                                .strikethrough(isDone)
                                                .foregroundStyle(isDone ? .secondary : .primary)
                                            Text("\(perPersonKcal) kcal / 1 người · \(scaledDish.prepTimeMinutes) phút")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
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
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityLabel("Tạo lại thực đơn tuần")
                }
            }
        }
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
