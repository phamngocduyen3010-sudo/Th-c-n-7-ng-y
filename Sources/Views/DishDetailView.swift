import SwiftUI

struct DishDetailView: View {
    @ObservedObject var store: MealPlanStore
    let dayIndex: Int
    let mealType: MealType
    let scaledDish: Dish

    @Environment(\.dismiss) private var dismiss

    private var members: Double {
        Double(max(1, store.profile.familyMembers))
    }

    private var alternatives: [Dish] {
        MenuLoader.alternativeDishes(for: mealType, excluding: scaledDish.id, in: store.catalog)
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount == amount.rounded() {
            return String(Int(amount))
        }
        return String(format: "%.1f", amount)
    }

    var body: some View {
        List {
            Section("Dinh dưỡng (1 người / \(store.profile.familyMembers) người)") {
                HStack {
                    Text("Năng lượng")
                    Spacer()
                    Text("\(Int((scaledDish.baseNutrition.calories / members).rounded())) kcal / \(Int(scaledDish.baseNutrition.calories.rounded())) kcal")
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                HStack {
                    Text("Đạm · Tinh bột · Chất béo (1 người)")
                    Spacer()
                    let p = Int((scaledDish.baseNutrition.proteinGrams / members).rounded())
                    let c = Int((scaledDish.baseNutrition.carbsGrams / members).rounded())
                    let f = Int((scaledDish.baseNutrition.fatGrams / members).rounded())
                    Text("\(p)g · \(c)g · \(f)g")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text("Thời gian chuẩn bị")
                    Spacer()
                    Text("\(scaledDish.prepTimeMinutes) phút")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Section("Nguyên liệu cho \(store.profile.familyMembers) người") {
                ForEach(scaledDish.ingredients) { item in
                    let converted = NutritionCoreBridge.convertUnit(
                        amount: item.amount,
                        unit: item.unit,
                        to: store.profile.unitSystem
                    )
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text("\(formatAmount(converted.amount)) \(converted.unit)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            Section("Cách thực hiện") {
                ForEach(Array(scaledDish.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .monospacedDigit()
                        Text(step)
                    }
                }
            }

            if !alternatives.isEmpty {
                Section("Đổi sang món khác cùng bữa") {
                    ForEach(alternatives) { alt in
                        Button {
                            store.swapDish(dayIndex: dayIndex, mealType: mealType, newDishId: alt.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alt.name)
                                        .foregroundStyle(.primary)
                                    Text("Chuẩn gốc: \(Int(alt.baseNutrition.calories.rounded())) kcal · \(alt.prepTimeMinutes) phút")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Spacer()
                                Text("Chọn")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(scaledDish.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
