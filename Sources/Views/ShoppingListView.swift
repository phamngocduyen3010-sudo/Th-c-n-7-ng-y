import SwiftUI

struct ShoppingListView: View {
    @ObservedObject var store: MealPlanStore

    private var groupedItems: [(category: String, items: [ShoppingListItem])] {
        let items = store.shoppingItems()
        let dict = Dictionary(grouping: items, by: { $0.category })
        return dict.keys.sorted().map { key in
            (category: key, items: dict[key] ?? [])
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount == amount.rounded() {
            return String(Int(amount))
        }
        return String(format: "%.1f", amount)
    }

    var body: some View {
        NavigationStack {
            List {
                if groupedItems.isEmpty {
                    Section {
                        Text("Chưa có nguyên liệu nào cho tuần này.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(groupedItems, id: \.category) { group in
                        Section(group.category) {
                            ForEach(group.items) { item in
                                Button {
                                    store.toggleShoppingItem(item.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(item.isChecked ? .green : .secondary)

                                        Text(item.name)
                                            .strikethrough(item.isChecked)
                                            .foregroundStyle(item.isChecked ? .secondary : .primary)

                                        Spacer()

                                        Text("\(formatAmount(item.totalAmount)) \(item.unit)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Đi chợ 7 ngày (\(store.profile.familyMembers) người)")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !store.checkedShoppingIds.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Bỏ chọn hết") {
                            store.resetShoppingChecks()
                        }
                    }
                }
            }
        }
    }
}
