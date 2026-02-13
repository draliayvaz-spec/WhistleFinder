//
//  ContentView.swift
//  WhistleFinder
//
//  Created by Ali Eyvazov on 04.02.2026.
//
import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var listener: WhistleListener

    @AppStorage("didSelectLanguage") private var didSelectLanguage = false
    @AppStorage("backgroundDetectionEnabled") private var backgroundDetectionEnabled = false

    @State private var showBackgroundAlert = false
    @State private var isRunning = false
    @State private var sensitivity = 2
    @State private var flashOn = true

    var body: some View {
        
        VStack(spacing: 24) {
            if !store.isPremium {
                NavigationLink {
                    PremiumView()
                } label: {
                    Text("go_premium")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                        .foregroundColor(.blue)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(isRunning ? .green : .gray)
                    .frame(width: 8, height: 8)

                Text(isRunning ? "listening" : "not_listening")
                    .font(.caption.weight(.semibold))
            }

            Button {
                if isRunning {
                    listener.stop()
                } else {
                    listener.flashEnabled = flashOn
                    listener.sensitivity = SensitivityLevel(rawValue: sensitivity) ?? .medium
                    listener.start()
                }
                isRunning.toggle()
            } label: {
                Text(isRunning ? "stop" : "start")
                    .font(.headline)
                    .frame(width: 200, height: 56)
                    .background(isRunning ? .red : .green)
                    .foregroundColor(.white)
                    .cornerRadius(28)
            }

            VStack(alignment: .leading) {
                Text("sensitivity")

                Picker("", selection: $sensitivity) {
                    Text("low").tag(1)
                    Text("medium").tag(2)
                    Text("high").tag(3)
                }
                .pickerStyle(.segmented)
            }
            .alert("background_alert_title",
                   isPresented: $showBackgroundAlert) {

                Button("background_alert_cancel", role: .cancel) {
                    backgroundDetectionEnabled = false
                    listener.backgroundEnabled = false
                }

                Button("background_alert_continue") {
                    backgroundDetectionEnabled = true
                    listener.backgroundEnabled = true
                }

            } message: {
                Text("background_alert_message")
            }
            Toggle("flash", isOn: $flashOn)

            Toggle("enable_background_detection", isOn: Binding(
                get: { backgroundDetectionEnabled },
                set: { newValue in
                    if newValue {
                        showBackgroundAlert = true
                    } else {
                        backgroundDetectionEnabled = false
                        listener.backgroundEnabled = false
                    }
                }
            ))

            Spacer()
            if !store.isPremium {
                BannerAdView(adUnitID: "ca-app-pub-3198209400533680/9681131319")
                    .frame(height: 50)
            }
        }
        .overlay {
            if listener.isCalibrating {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Calibrating environment...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Whistle Finder")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    PrivacyView()
                }label: {
            Image(systemName: "shield")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    didSelectLanguage = false
                } label: {
                    Image(systemName: "globe")
                }
            }
        }
    }
}
