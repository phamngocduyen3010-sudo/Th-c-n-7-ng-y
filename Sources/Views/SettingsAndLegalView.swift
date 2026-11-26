import SwiftUI

struct SettingsAndLegalView: View {
    @ObservedObject var store: MealPlanStore
    @State private var showEditProfile = false

    private var appVersionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Hồ sơ & Thực đơn") {
                    Button {
                        showEditProfile = true
                    } label: {
                        HStack(spacing: 14) {
                            settingsIcon("person.fill", color: .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chỉnh sửa chỉ số & mục tiêu")
                                    .foregroundStyle(.primary)
                                Text("\(Int(store.profile.heightCm.rounded())) cm · \(Int(store.profile.weightKg.rounded())) kg · \(store.profile.familyMembers) người")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section("Nguồn dinh dưỡng & Miễn trừ y tế") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cơ sở tính toán")
                            .font(.subheadline.weight(.semibold))
                        Text("Chỉ số BMR và TDEE được tính theo công thức Mifflin-St Jeor (1990) trên lõi C cục bộ. Mức giảm cân luôn duy trì sàn tối thiểu 1.200 kcal/ngày. Thành phần dinh dưỡng tham chiếu từ bảng thành phần thực phẩm phổ thông (Viện Dinh dưỡng & USDA FoodData Central).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Miễn trừ trách nhiệm y tế")
                            .font(.subheadline.weight(.semibold))
                        Text("Thông tin thực đơn và calo chỉ phục vụ mục đích tham khảo lập kế hoạch ăn uống hằng ngày, không thay thế tư vấn, chẩn đoán hoặc điều trị từ bác sĩ. Nếu bạn có bệnh lý nền hoặc đang mang thai, vui lòng tham khảo ý kiến bác sĩ trước khi thay đổi chế độ ăn.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Hỗ trợ & Pháp lý") {
                    if let supportURL = URL(string: "https://phamngocduyen3010-sudo.github.io/") {
                        Link(destination: supportURL) {
                            HStack(spacing: 14) {
                                settingsIcon("questionmark.circle.fill", color: .blue)
                                Text("Trung tâm Hỗ trợ")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let privacyURL = URL(string: "https://phamngocduyen3010-sudo.github.io/privacy.html") {
                        Link(destination: privacyURL) {
                            HStack(spacing: 14) {
                                settingsIcon("hand.raised.fill", color: .indigo)
                                Text("Chính sách Quyền riêng tư")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let mailURL = URL(string: "mailto:phamngocduyen3010@gmail.com") {
                        Link(destination: mailURL) {
                            HStack(spacing: 14) {
                                settingsIcon("envelope.fill", color: .teal)
                                Text("Liên hệ qua Email")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Thông tin ứng dụng") {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text(appVersionText)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Lưu trữ dữ liệu")
                        Spacer()
                        Text("100% cục bộ trên máy")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Hồ sơ & Pháp lý")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile) {
                OnboardingView(store: store, isModalEdit: true)
            }
        }
    }

    private func settingsIcon(_ symbol: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
                .frame(width: 29, height: 29)
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
