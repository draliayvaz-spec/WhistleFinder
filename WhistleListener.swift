//
//  WhistleListener.swift
//  WhistleFinder
//
//  Created by Ali Eyvazov on 04.02.2026.
//
import Foundation
import AVFoundation
import UIKit
import UserNotifications
import Combine
import Accelerate

final class WhistleListener: ObservableObject {

    // MARK: Published (UI)

    @Published var isRunning: Bool = false
    @Published var flashEnabled: Bool = true
    @Published var backgroundEnabled: Bool = false
    @Published var selectedSound: String = "alarm"
    @Published var isPremium: Bool = false
    // MARK: - Calibrating
    
    @Published var isCalibrating: Bool = false
    private var ambientBaseline: Float = 0.02
    // MARK: Public

    var sensitivity: SensitivityLevel = .medium

    // MARK: Audio

    private let engine = AVAudioEngine()
    private var alarmPlayer: AVAudioPlayer?
    private var keepAlivePlayer: AVAudioPlayer?

    // MARK: Detection

    private var whistleFrames = 0
    private let requiredFrames = 8
    private var stableFrameCount = 0
    private let requiredStableFrames = 5
    
    private let alarmNotificationID = "WHISTLE_ALARM"

    // MARK: START
    
    func start() {
        guard !isRunning else { return }

        requestMicPermission { granted in
            if granted {
                DispatchQueue.main.async {
                    self.beginCalibration ()
                }
            }
        }
    }
    // MARK: - Calibration
    private func beginCalibration() {

        isCalibrating = true

        configureRecordSession()

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        var samples: [Float] = []

        input.removeTap(onBus: 0)

        input.installTap(onBus: 0,
                         bufferSize: 2048,
                         format: format) { [weak self] buffer, _ in

            guard let self else { return }

            let level = self.rms(buffer: buffer)
            samples.append(level)
        }

        try? engine.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {

            self.engine.stop()
            input.removeTap(onBus: 0)

            let avg = samples.reduce(0, +) / Float(max(samples.count, 1))
            self.ambientBaseline = avg

            self.isCalibrating = false

            self.startEngine()
            self.isRunning = true
        }
    }
    // MARK: STOP

    func stop() {
        guard isRunning else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        alarmPlayer?.stop()
        keepAlivePlayer?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRunning = false
    }

    // MARK: Background Handling

    func handleAppDidEnterBackground() {
        if !backgroundEnabled {
            stop()
        }
    }

    // MARK: Engine Setup

    private func startEngine() {

        configureRecordSession()

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        input.removeTap(onBus: 0)

        input.installTap(onBus: 0,
                         bufferSize: 2048,
                         format: format) { [weak self] buffer, _ in

            guard let self else { return }

            if self.isPremium {
                if self.detectWhistleFFT(buffer: buffer) {
                    self.trigger()
                }
            } else {
                let level = self.rms(buffer: buffer)

                if level > self.threshold() {
                    self.whistleFrames += 1
                } else {
                    self.whistleFrames = 0
                }

                if self.whistleFrames >= self.requiredFrames {
                    self.whistleFrames = 0
                    self.trigger()
                }
            }
        }

        do {
            try engine.start()
        } catch {
            print("Engine start error:", error)
        }
    }

    // MARK: FFT Detection (Premium)
    private var lastTriggerTime: TimeInterval = 0
    private let triggerCooldown: TimeInterval = 2.0

    private func detectWhistleFFT(buffer: AVAudioPCMBuffer) -> Bool {

        guard let channelData = buffer.floatChannelData?[0] else { return false }

        let frameCount = Int(buffer.frameLength)
        let log2n = vDSP_Length(log2(Float(frameCount)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return false
        }

        var real = [Float](repeating: 0, count: frameCount/2)
        var imag = [Float](repeating: 0, count: frameCount/2)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in

                var splitComplex = DSPSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )

                channelData.withMemoryRebound(to: DSPComplex.self,
                                              capacity: frameCount) { data in

                    vDSP_ctoz(data, 2,
                              &splitComplex, 1,
                              vDSP_Length(frameCount/2))
                }

                vDSP_fft_zrip(fftSetup,
                              &splitComplex,
                              1,
                              log2n,
                              FFTDirection(FFT_FORWARD))
            }
        }

        vDSP_destroy_fftsetup(fftSetup)

        let sampleRate: Float = 44100
        let binSize = sampleRate / Float(frameCount)

        var whistleEnergy: Float = 0
        var totalEnergy: Float = 0
        var peakMagnitude: Float = 0
        var peakFrequency: Float = 0

        for i in 10..<real.count {

            let frequency = Float(i) * binSize
            let magnitude = sqrt(real[i]*real[i] + imag[i]*imag[i])

            totalEnergy += magnitude

            if frequency > 1800 && frequency < 3500 {
                whistleEnergy += magnitude
            }

            if magnitude > peakMagnitude {
                peakMagnitude = magnitude
                peakFrequency = frequency
            }
        }

        let dominance = whistleEnergy / max(totalEnergy, 0.0001)

        let rmsLevel = rms(buffer: buffer)
        let minRMS = ambientBaseline * 2.0

        let isStrongEnough = rmsLevel > minRMS
        let isWhistleBand = peakFrequency > 1800 && peakFrequency < 3500
        let isDominant = dominance > 0.65

        if isStrongEnough && isWhistleBand && isDominant {
            stableFrameCount += 1
        } else {
            stableFrameCount = 0
        }

        if stableFrameCount >= requiredStableFrames {

            let now = CACurrentMediaTime()

            if now - lastTriggerTime > triggerCooldown {
                lastTriggerTime = now
                stableFrameCount = 0
                return true
            }
        }

        return false
    }

    // MARK: RMS (Free)

    private func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<count {
            sum += data[i] * data[i]
        }

        return sqrt(sum / Float(count))
    }

    // MARK: - Thresold
    private func threshold() -> Float {

        let dynamicBase = ambientBaseline * 4.0

        switch sensitivity {
        case .low:
            return dynamicBase * 1.2
        case .medium:
            return dynamicBase
        case .high:
            return dynamicBase * 0.85
        }
    }
    // MARK: Trigger

    private func trigger() {

        DispatchQueue.main.async {

            self.playSelectedSound()

            if self.flashEnabled {
                self.flash()
            }

            self.sendAlarmNotification()
        }
    }

    // MARK: Sound

    private func playSelectedSound() {

        guard let url = Bundle.main.url(
            forResource: selectedSound,
            withExtension: "wav"
        ) else {
            print("Sound file not found:", selectedSound)
            return
        }

        alarmPlayer = try? AVAudioPlayer(contentsOf: url)
        alarmPlayer?.numberOfLoops = 0
        alarmPlayer?.play()
    }
    func previewSelectedSound() {
        playSelectedSound()
    }
    // MARK: Flash

    private func flash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            try device.setTorchModeOn(level: 1)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                device.torchMode = .off
                device.unlockForConfiguration()
            }
        } catch {
            print("Flash error:", error)
        }
    }

    // MARK: Audio Session

    private func configureRecordSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker,
                          .mixWithOthers,
                          .allowBluetooth]
            )

            try AVAudioSession.sharedInstance().setActive(true)

        } catch {
            print("Session error:", error)
        }
    }

    private func requestMicPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    private func startKeepAlivePlayback() {
        guard let url = Bundle.main.url(forResource: "silent", withExtension: "wav") else { return }

        keepAlivePlayer = try? AVAudioPlayer(contentsOf: url)
        keepAlivePlayer?.numberOfLoops = -1
        keepAlivePlayer?.volume = 0.001
        keepAlivePlayer?.play()
    }

    // MARK: Notification

    private func sendAlarmNotification() {
        let content = UNMutableNotificationContent()
        content.title = "WhistleFinder"
        content.body = "Whistle detected — alarm active"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: alarmNotificationID,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
