//
//  SettingsView.swift
//  GetCooking
//
//  Reached from the gear button on the main menu. One-hand mode relaxes the
//  seat check (SeatCalibrationView) to require only the chosen hand instead
//  of both — gameplay itself already tracks each hand independently and
//  needs no change to play one-handed.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("oneHandModeEnabled") private var oneHandModeEnabled = false
    @AppStorage("preferredHand") private var preferredHand: HandSide = .right

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("One-Hand Mode", isOn: $oneHandModeEnabled.animation())

                    if oneHandModeEnabled {
                        Picker("Hand", selection: $preferredHand) {
                            ForEach(HandSide.allCases) { side in
                                Text(side.displayName).tag(side)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    Text("Only the chosen hand needs to be raised to pass the seat check.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
