//
//  ContentView.swift
//  alininbootcamp
//
//  Created by Ali Eyvazov on 11.02.2026.
//
import SwiftUI

struct ContentView: View {

    @State private var isRunning = false
    @State private var sensitivity = 2
    @State private var flashOn = true
    @StateObject private var listener = WhistleListener()


    var body: some View {

        VStack(spacing: 24) {

            Text("WhistleFinder")
                .font(.largeTitle)
                .fontWeight(.semibold)

            HStack(spacing: 6) {
                Circle()
                    .fill(isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(isRunning ? "Listening" : "Not Listening")
                    .foregroundColor(.secondary)
            }

            Button {
                if isRunning {
                    listener.stop()
                } else {
                    listener.flashEnabled = flashOn
                    listener.sensitivity =
                        SensitivityLevel(rawValue: sensitivity) ?? .medium
                    listener.start()
                }

                isRunning.toggle()

            } label: {
                Text(isRunning ? "STOP" : "START")
                    .font(.headline)
                    .frame(width: 200, height: 56)
                    .background(isRunning ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(28)
            }

            Button("TEST ALARM") {
                listener.testAlert()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sensitivity").font(.headline)

                Picker("", selection: $sensitivity) {
                    Text("Low").tag(1)
                    Text("Medium").tag(2)
                    Text("High").tag(3)
                }
                .pickerStyle(.segmented)
            }

            Toggle("Flash", isOn: $flashOn)

            Spacer()
        }
        .padding()
        .onAppear {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

    }
}
