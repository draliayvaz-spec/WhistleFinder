import Foundation
import AVFoundation
import UIKit
import UserNotifications
import Combine

final class WhistleListener: ObservableObject {
    
    // MARK: Public
    
    var sensitivity: SensitivityLevel = .medium
    var flashEnabled = true
    
    // MARK: Audio
    
    private let engine = AVAudioEngine()
    private var alarmPlayer: AVAudioPlayer?
    private var keepAlivePlayer: AVAudioPlayer?
    
    // MARK: Trigger Control
    
    private var lastTrigger = Date.distantPast
    private let triggerCooldown: TimeInterval = 3
    
    private var whistleFrames = 0
    private let requiredFrames = 4
    
    // MARK: Start
    
    func start() {
        
        startKeepAlivePlayback()   // 🔥 background alive trick
        
        requestMicPermission { granted in
            if granted {
                self.startEnginePipeline()
            } else {
                print("mic denied")
            }
        }
    }
    
    // MARK: Stop
    
    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        alarmPlayer?.stop()
        keepAlivePlayer?.stop()

        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [alarmNotificationID])
    }

    
    // MARK: Engine Pipeline
    
    private func startEnginePipeline() {
        
        configureRecordSession()
        
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        
        input.removeTap(onBus: 0)
        
        input.installTap(onBus: 0,
                         bufferSize: 2048,
                         format: format) { [weak self] buffer, _ in
            
            guard let self else { return }
            
            let level = self.rms(buffer: buffer)
            
            if level > self.threshold() {
                self.whistleFrames += 1
            } else {
                self.whistleFrames = 0
            }
            
            if self.whistleFrames >= self.requiredFrames {
                self.whistleFrames = 0
                self.testAlert()
            }
        }
        
        do {
            try engine.start()
            print("engine started")
        } catch {
            print("engine error:", error)
        }
    }
    
    // MARK: Mic Permission
    
    private func requestMicPermission(_ block: @escaping (Bool)->Void) {
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(
                completionHandler: block
            )
        } else {
            AVAudioSession.sharedInstance()
                .requestRecordPermission(block)
        }
    }
    
    
    // MARK: Detection
    
    private func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<count { sum += data[i]*data[i] }
        
        return sqrt(sum / Float(count))
    }
    
    private func threshold() -> Float {
        switch sensitivity {
        case .low: return 0.08
        case .medium: return 0.05
        case .high: return 0.03
        }
    }
    
    // MARK: Alert
    func testAlert() {

        DispatchQueue.main.async {

            try? AVAudioSession.sharedInstance()
                .setCategory(.playback, options: [.defaultToSpeaker])

            try? AVAudioSession.sharedInstance().setActive(true)

            self.playAlarm(loop: false)

            if self.flashEnabled {
                self.flash()
            }

            self.sendAlarmNotification()
        }
    }

    // MARK: Alarm Sound
    private func playAlarm(loop: Bool) {
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "wav") else { return }

        alarmPlayer = try? AVAudioPlayer(contentsOf: url)
        alarmPlayer?.numberOfLoops = loop ? -1 : 0  
        alarmPlayer?.prepareToPlay()
        alarmPlayer?.play()
    }

    
    // MARK: Flash
    
    private func flash() {
        guard let d = AVCaptureDevice.default(for: .video),
              d.hasTorch else { return }
        
        try? d.lockForConfiguration()
        try? d.setTorchModeOn(level: 1)
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.25) {
            d.torchMode = .off
            d.unlockForConfiguration()
        }
    }
    
    // MARK: Sessions
    
    private func configureRecordSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playAndRecord,
            mode: .default,
            options: [
                .defaultToSpeaker,
                .mixWithOthers,
                .allowBluetooth
            ]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    // MARK: Background Keep Alive
    
    private func startKeepAlivePlayback() {
        
        guard let url = Bundle.main.url(forResource: "silent", withExtension: "wav") else {
            print("silent.wav missing")
            return
        }
        
        try? AVAudioSession.sharedInstance().setCategory(.playback,
                                                         options: [.mixWithOthers])
        
        keepAlivePlayer = try? AVAudioPlayer(contentsOf: url)
        keepAlivePlayer?.numberOfLoops = -1
        keepAlivePlayer?.volume = 0.001
        keepAlivePlayer?.play()
    }
    private let alarmNotificationID = "WHISTLE_ALARM"
    
    private func sendAlarmNotification() {
        
        let content = UNMutableNotificationContent()
        content.title = "WhistleFinder"
        content.body = "Islık algılandı — alarm aktif"
        content.sound = .default
        
        let req = UNNotificationRequest(
            identifier: alarmNotificationID,   // ✅ sabit ID
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(req)
    }
}

