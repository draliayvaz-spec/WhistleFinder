import SwiftUI
import StoreKit

struct PremiumView: View {
    
    @AppStorage("didSelectLanguage") private var didSelectLanguage = true
    
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var listener: WhistleListener
    
    @State private var sensitivity = 2
    @State private var showBackgroundAlert = false
    
    var body: some View {
        
        ScrollView {
            
            if store.isPremium {
                premiumContent
            } else {
                upgradeContent
            }
        }
        
        .navigationTitle("premium")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    didSelectLanguage = false
                } label: {
                    Image(systemName: "globe")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PrivacyView()
                } label: {
                    Image(systemName: "shield.lefthalf.filled")
                }
            }
        }
        .navigationBarBackButtonHidden(store.isPremium)
        .alert("background_alert_title",
               isPresented: $showBackgroundAlert) {
            
            Button("background_alert_cancel", role: .cancel) {
                listener.backgroundEnabled = false
            }
            
            Button("background_alert_continue") {
                listener.backgroundEnabled = true
            }
            
        } message: {
            Text("background_alert_message")
        }
    }
}

//////////////////////////////////////////////////////////
// MARK: - PREMIUM CONTENT
//////////////////////////////////////////////////////////

extension PremiumView {
    
    private var premiumContent: some View {
        
VStack(spacing: 28) {
            
            // Crown Header
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("premium_active")
                    .font(.title2.bold())
            }
            
            startStopButton
            sensitivityCard
            toggleCard
            soundGrid
            
        }
        .padding()
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
    }
}

//////////////////////////////////////////////////////////
// MARK: - START / STOP BUTTON
//////////////////////////////////////////////////////////

extension PremiumView {
    
    private var startStopButton: some View {
        
        Button {
            if listener.isRunning {
                listener.stop()
            } else {
                listener.sensitivity =
                SensitivityLevel(rawValue: sensitivity) ?? .medium
                listener.start()
            }
        } label: {
            
            Text(listener.isRunning ? "stop_listening" : "start_listening")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(listener.isRunning ? .red : .green)
                )
                .foregroundColor(.white)
                .shadow(
                    color: listener.isRunning
                    ? .red.opacity(0.4)
                    : .green.opacity(0.4),
                    radius: 10
                )
        }
        .animation(.easeInOut(duration: 0.2),
                   value: listener.isRunning)
    }
}

//////////////////////////////////////////////////////////
// MARK: - SENSITIVITY CARD
//////////////////////////////////////////////////////////

extension PremiumView {
    
    private var sensitivityCard: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            Text("sensitivity")
                .font(.headline)
            
            Picker("", selection: $sensitivity) {
                Text("low").tag(1)
                Text("medium").tag(2)
                Text("high").tag(3)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(18)
    }
}

//////////////////////////////////////////////////////////
// MARK: - TOGGLE CARD
//////////////////////////////////////////////////////////

extension PremiumView {
    
    private var toggleCard: some View {
        
        VStack(spacing: 16) {
            
            Toggle("flash", isOn: $listener.flashEnabled)
            
            Toggle("background_detection", isOn: Binding(
                get: { listener.backgroundEnabled },
                set: { newValue in
                    if newValue {
                        showBackgroundAlert = true
                    } else {
                        listener.backgroundEnabled = false
                    }
                }
            ))
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(18)
    }
}

//////////////////////////////////////////////////////////
// MARK: - ULTRA NEON SOUND GRID
//////////////////////////////////////////////////////////

extension PremiumView {
    
    private var soundGrid: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            Text("alert_sound")
                .font(.headline)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 3),
                spacing: 16
            ) {
                
                ForEach(["alarm","whistle","siren","horn","dog","bell"], id: \.self) { sound in
                    
                    NeonSoundButton(
                        systemName: iconForSound(sound),
                        title: sound.capitalized,
                        isSelected: listener.selectedSound == sound
                    ) {
                        listener.selectedSound = sound
                        listener.previewSelectedSound()
                    }
                }
            }
        }
    }
}

//////////////////////////////////////////////////////////
// MARK: - UPGRADE VIEW
//////////////////////////////////////////////////////////

extension PremiumView {
    
    private var upgradeContent: some View {
        
        VStack(spacing: 20) {
            
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("unlock_full_whistle_detection_power")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            if let product = store.product {
                Text(product.displayPrice)
                    .font(.largeTitle.bold())
            }
            
            Button {
                Task { await store.purchaseLifetime() }
            } label: {
                Text("upgrade_to_premium")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(16)
            }
            
            Button("restore_purchases") {
                Task { await store.restore() }
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

//////////////////////////////////////////////////////////
// MARK: - NEON BUTTON
//////////////////////////////////////////////////////////

struct NeonSoundButton: View {
    
    let systemName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var glow = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(isSelected ? .green : .white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.8))
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.green, lineWidth: 2)
                            .shadow(color: Color.green.opacity(glow ? 0.9 : 0.3),
                                    radius: glow ? 20 : 8)
                    }
                }
            )
        }
        .onAppear {
            if isSelected {
                withAnimation(.easeInOut(duration: 1)
                    .repeatForever(autoreverses: true)) {
                    glow.toggle()
                }
            }
        }
    }
}

//////////////////////////////////////////////////////////
// MARK: - Helper
//////////////////////////////////////////////////////////

extension PremiumView {
    
    private func iconForSound(_ sound: String) -> String {
        switch sound {
        case "alarm": return "alarm.fill"
        case "whistle": return "wind"
        case "siren": return "light.beacon.max.fill"
        case "horn": return "car.fill"
        case "dog": return "pawprint.fill"
        case "bell": return "bell.fill"
        default: return "speaker.wave.2.fill"
        }
    }
}
