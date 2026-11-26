import AppTrackingTransparency
import Combine
import Foundation
@preconcurrency import GoogleMobileAds
import UIKit

/// Manages Google AdMob Interstitial ads with ATT compliance and strict separation from health data.
@MainActor
final class MealAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    private static let counterStorageKey = "td_ad_interaction_count_v1"

    let config: MealAdConfig
    @Published private(set) var interactionCount: Int
    @Published private(set) var isNonPersonalizedRequired: Bool = true

    private var interstitialAd: InterstitialAd?
    private var hasStartedSDK = false
    private var isLoading = false
    private var isPresenting = false
    private var scheduledTask: Task<Void, Never>?
    private let defaults: UserDefaults

    init(config: MealAdConfig = MealAdConfig(), defaults: UserDefaults = .standard) {
        self.config = config
        self.defaults = defaults
        self.interactionCount = defaults.integer(forKey: Self.counterStorageKey)
        super.init()
    }

    func bootstrap() async {
        // Wait briefly so the first screen is active before showing Apple's ATT prompt
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        let status = ATTrackingManager.trackingAuthorizationStatus
        if status == .notDetermined {
            let updated = await ATTrackingManager.requestTrackingAuthorization()
            isNonPersonalizedRequired = (updated != .authorized)
        } else {
            isNonPersonalizedRequired = (status != .authorized)
        }

        startSDKIfNeeded()
        await preloadInterstitial()
    }

    func recordInteraction() {
        interactionCount += 1
        defaults.set(interactionCount, forKey: Self.counterStorageKey)

        guard interactionCount >= config.triggerThreshold else {
            if interstitialAd == nil && !isLoading {
                Task { await preloadInterstitial() }
            }
            return
        }

        scheduleSafePresentation()
    }

    private func startSDKIfNeeded() {
        guard !hasStartedSDK else { return }
        hasStartedSDK = true
        MobileAds.shared.start(completionHandler: nil)
    }

    private func preloadInterstitial() async {
        startSDKIfNeeded()
        guard interstitialAd == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Strictly zero health/nutrition parameters are ever attached to ad requests (Guideline 5.1.3)
        let request = GoogleMobileAds.Request()
        if isNonPersonalizedRequired {
            let extras = GoogleMobileAds.Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }

        do {
            let loaded = try await InterstitialAd.load(with: config.interstitialUnitID, request: request)
            loaded.fullScreenContentDelegate = self
            interstitialAd = loaded
        } catch {
            interstitialAd = nil
        }
    }

    private func scheduleSafePresentation() {
        scheduledTask?.cancel()
        guard !isPresenting else { return }

        let delay = config.safeDelayNanoseconds
        scheduledTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard let self, !Task.isCancelled else { return }
            await self.presentIfReady()
        }
    }

    private func presentIfReady() async {
        guard !isPresenting, interactionCount >= config.triggerThreshold else { return }
        if interstitialAd == nil {
            await preloadInterstitial()
        }
        guard let ad = interstitialAd, let rootVC = topMostViewController() else { return }

        isPresenting = true
        ad.fullScreenContentDelegate = self
        ad.present(from: rootVC)
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.interstitialAd = nil
            self.isPresenting = false
            self.interactionCount = 0
            self.defaults.set(0, forKey: Self.counterStorageKey)
            await self.preloadInterstitial()
        }
    }

    nonisolated func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.interstitialAd = nil
            self.isPresenting = false
        }
    }

    private func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let keyWindow = activeScene?.windows.first(where: { $0.isKeyWindow }) ?? activeScene?.windows.first,
              var topController = keyWindow.rootViewController else {
            return nil
        }
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }
}
