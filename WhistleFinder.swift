//
//  WhistleFinder.swift
//  WhistleFinderMAİNAPP
//
//  Created by Ali Eyvazov on 03.02.2026.
//
import SwiftUI
import UserNotifications
import GoogleMobileAds

@main
struct WhistleFinderApp: App {
    @StateObject private var listener = WhistleListener()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = StoreManager()

    @AppStorage("didSelectLanguage") private var didSelectLanguage: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = "en"

    init() {
        MobileAds.shared.start()
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                print("notif:", granted)
            }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {

                if !store.isReady {

                    // Splash / boş ekran
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                    }

                } else {

                    if didSelectLanguage {
                        if store.isPremium {
                            PremiumView()
                        } else {
                            ContentView()
                        }
                    } else {
                        LanguageSelectionView()
                    }

                }
            }
            .environment(\.locale, Locale(identifier: appLanguage))
            .environmentObject(store)
            .environmentObject(listener)
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .inactive, .background:
                    if !listener.backgroundEnabled {
                        listener.stop()
                    }
                case .active:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
