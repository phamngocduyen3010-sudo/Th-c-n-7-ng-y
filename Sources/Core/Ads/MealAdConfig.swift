import Foundation

/// AdMob configuration strictly isolated from user health/nutrition data (Apple Guideline 5.1.3).
struct MealAdConfig: Sendable, Equatable {
    static let officialTestAppID = "ca-app-pub-3940256099942544~1458002511"
    static let officialTestInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    let interstitialUnitID: String
    let triggerThreshold: Int
    let safeDelayNanoseconds: UInt64

    init(
        interstitialUnitID: String = MealAdConfig.resolvedInterstitialUnitID(),
        triggerThreshold: Int = 5,
        safeDelayNanoseconds: UInt64 = 3_000_000_000
    ) {
        self.interstitialUnitID = interstitialUnitID
        self.triggerThreshold = max(1, triggerThreshold)
        self.safeDelayNanoseconds = safeDelayNanoseconds
    }

    static func resolvedInterstitialUnitID() -> String {
        if let custom = Bundle.main.object(forInfoDictionaryKey: "AdMobInterstitialUnitID") as? String {
            let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return officialTestInterstitialUnitID
    }
}
