import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: MealPlanStore
    var isModalEdit: Bool = false
    @Environment(\.dismiss) private var dismiss

    @State private var gender: Gender
    @State private var age: Int
    @State private var heightCm: Int
    @State private var weightKg: Int
    @State private var activityLevel: ActivityLevel
    @State private var goal: NutritionGoal
    @State private var familyMembers: Int
    @State private var unitSystem: UnitSystem
    @State private var cuisineRegion: VietnameseCuisineRegion
    @State private var isVegetarian: Bool
    @State private var breakfastPreference: BreakfastPreference

    init(store: MealPlanStore, isModalEdit: Bool = false) {
        self.store = store
        self.isModalEdit = isModalEdit
        let p = store.profile
        _gender = State(initialValue: p.gender)
        _age = State(initialValue: p.age)
        _heightCm = State(initialValue: Int(p.heightCm.rounded()))
        _weightKg = State(initialValue: Int(p.weightKg.rounded()))
        _activityLevel = State(initialValue: p.activityLevel)
        _goal = State(initialValue: p.goal)
        _familyMembers = State(initialValue: p.familyMembers)
        _unitSystem = State(initialValue: p.unitSystem)
        _cuisineRegion = State(initialValue: p.cuisineRegion)
        _isVegetarian = State(initialValue: p.isVegetarian)
        _breakfastPreference = State(initialValue: p.breakfastPreference)
    }

    private var draftProfile: UserNutritionProfile {
        UserNutritionProfile(
            gender: gender,
            age: age,
            heightCm: Double(heightCm),
            weightKg: Double(weightKg),
            activityLevel: activityLevel,
            goal: goal,
            familyMembers: familyMembers,
            regionCode: store.profile.regionCode,
            unitSystem: unitSystem,
            cuisineRegion: cuisineRegion,
            isVegetarian: isVegetarian,
            breakfastPreference: breakfastPreference
        )
    }

    private var previewEvaluation: EvaluatedNutrition {
        NutritionCoreBridge.evaluate(profile: draftProfile)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Thông số cơ thể") {
                    Picker("Giới tính", selection: $gender) {
                        Text("Nam").tag(Gender.male)
                        Text("Nữ").tag(Gender.female)
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $age, in: 14...90) {
                        HStack {
                            Text("Tuổi")
                            Spacer()
                            Text("\(age) tuổi")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Stepper(value: $heightCm, in: 130...210) {
                        HStack {
                            Text("Chiều cao")
                            Spacer()
                            Text("\(heightCm) cm")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Stepper(value: $weightKg, in: 35...180) {
                        HStack {
                            Text("Cân nặng")
                            Spacer()
                            Text("\(weightKg) kg")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section("Mục tiêu & Chế độ ăn") {
                    Picker("Mục tiêu", selection: $goal) {
                        Text("Giảm cân").tag(NutritionGoal.loseWeight)
                        Text("Giữ cân").tag(NutritionGoal.maintain)
                        Text("Tăng cân").tag(NutritionGoal.gainWeight)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Chế độ ăn chay", isOn: $isVegetarian)

                    Picker("Khẩu vị vùng miền", selection: $cuisineRegion) {
                        ForEach(VietnameseCuisineRegion.allCases, id: \.self) { region in
                            Text(region.displayTitle).tag(region)
                        }
                    }

                    Picker("Bữa sáng ưu tiên", selection: $breakfastPreference) {
                        ForEach(BreakfastPreference.allCases, id: \.self) { pref in
                            Text(pref.displayTitle).tag(pref)
                        }
                    }

                    Picker("Mức vận động", selection: $activityLevel) {
                        Text("Ít vận động").tag(ActivityLevel.sedentary)
                        Text("Nhẹ (1–3 buổi/tuần)").tag(ActivityLevel.light)
                        Text("Vừa (3–5 buổi/tuần)").tag(ActivityLevel.moderate)
                        Text("Năng động (6–7 buổi)").tag(ActivityLevel.active)
                    }

                    Stepper(value: $familyMembers, in: 1...8) {
                        HStack {
                            Text("Số người ăn")
                            Spacer()
                            Text("\(familyMembers) người")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Picker("Đơn vị nguyên liệu", selection: $unitSystem) {
                        Text("Hệ mét (g, ml)").tag(UnitSystem.metric)
                        Text("Hệ Mỹ (oz, fl oz)").tag(UnitSystem.imperial)
                    }
                }

                Section {
                    HStack {
                        Text("BMR / TDEE (1 người)")
                        Spacer()
                        Text("\(Int(previewEvaluation.bmrKcal.rounded())) / \(Int(previewEvaluation.tdeeKcal.rounded())) kcal")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Mục tiêu 1 người / ngày")
                        Spacer()
                        Text("\(Int(previewEvaluation.targetDailyKcal.rounded())) kcal")
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                            .monospacedDigit()
                    }
                    if familyMembers > 1 {
                        HStack {
                            Text("Tổng khẩu phần (\(familyMembers) người)")
                            Spacer()
                            Text("\(Int(previewEvaluation.familyTotalKcal.rounded())) kcal")
                                .foregroundStyle(.blue)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Ước tính dinh dưỡng (Mifflin-St Jeor)")
                } footer: {
                    Text("Mức giảm cân luôn giữ sàn an toàn tối thiểu 1.200 kcal/ngày. Chỉ số chỉ mang tính tham khảo lập thực đơn, không thay thế tư vấn bác sĩ.")
                }

                Section {
                    Button {
                        store.saveProfile(draftProfile, regeneratePlan: true)
                        if isModalEdit {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.green)
                                    .frame(width: 29, height: 29)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(isModalEdit ? "Lưu thay đổi & Cập nhật thực đơn" : "Bắt đầu Thực đơn 7 ngày")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isModalEdit ? "Hồ sơ dinh dưỡng" : "Thiết lập ban đầu")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isModalEdit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Đóng") { dismiss() }
                    }
                }
            }
        }
    }
}
