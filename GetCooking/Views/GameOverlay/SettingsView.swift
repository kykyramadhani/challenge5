//
//  SettingsView.swift
//  GetCooking
//
//  The in-game settings card: music and sound-effects volume, language, and
//  one-hand mode. Presented as a dimmed overlay from the main menu (see
//  MainMenuView), not a system sheet, so it matches the game's own styling.
//
//  Volumes are stored in UserDefaults under the keys AudioManager reads at
//  launch, and pushed live into AudioManager as the sliders move. Language is
//  UI-only for now — the toggle records a preference but no localization is
//  applied yet.
//

import SwiftUI

struct SettingsView: View {
    var onClose: () -> Void

    // MARK: - Persisted settings

    // Defaults mirror AudioManager's own starting values.
    @AppStorage(AudioManager.musicVolumeKey) private var musicVolume: Double = 0.45
    @AppStorage(AudioManager.sfxVolumeKey) private var sfxVolume: Double = 1.0

    // UI-only for now — recorded so the choice sticks, but not yet applied.
    @AppStorage("settings.language") private var language: AppLanguage = .english

    @AppStorage("oneHandModeEnabled") private var oneHandModeEnabled = false
    @AppStorage("preferredHand") private var preferredHand: HandSide = .right

    var body: some View {
        ZStack {
            // Dimmed backdrop — a tap anywhere off the card closes it.
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            card
                .frame(maxWidth: 1000)
                .padding(.horizontal, 40)
                .overlay(alignment: .topTrailing) { closeButton }
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 28) {
            Text("SETTINGS")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.appTertiary)
                .padding(.top, 60)
                .padding(.bottom, 60)

            settingRow(title: "Music") {
                VolumeSlider(value: $musicVolume, onChanged:  { newValue in
                    AudioManager.shared.musicVolume = Float(newValue)
                })
            }

            Divider()

            settingRow(title: "Sound Effects") {
                VolumeSlider(value: $sfxVolume, onEditingEnded: { _ in
                    // A quick tick so the player hears the new level.
                    AudioManager.shared.play(.uiClick)
                }) { newValue in
                    AudioManager.shared.effectsVolume = Float(newValue)
                }
            }

            Divider()

            settingRow(title: "Language") {
                SegmentedPill(
                    leftTitle: "English",
                    rightTitle: "Indonesia",
                    isRightSelected: Binding(
                        get: { language == .indonesia },
                        set: { language = $0 ? .indonesia : .english }
                    )
                )
            }

            Divider()

            settingRow(title: "One-hand Mode") {
                VStack(spacing: 12) {
                    SegmentedPill(
                        leftTitle: "OFF",
                        rightTitle: "ON",
                        isRightSelected: $oneHandModeEnabled
                    )
                    SegmentedPill(
                        leftTitle: HandSide.left.displayName,
                        rightTitle: HandSide.right.displayName,
                        isRightSelected: Binding(
                            get: { preferredHand == .right },
                            set: { preferredHand = $0 ? .right : .left }
                        ),
                        // Which hand only matters when one-hand mode is on.
                        isEnabled: oneHandModeEnabled
                    )
                }
            }
            
            Divider()
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 72)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.white)
        )
    }

    /// One labelled row: title on the left, its control filling the right half.
    private func settingRow<Control: View>(
        title: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 24) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.appTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            control()
                .frame(width: 500)
        }
    }

    private var closeButton: some View {
        Button(action: {
            AudioManager.shared.play(.uiClick)
            onClose()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.appBackground)
                .frame(width: 100, height: 100)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .offset(x: 0, y: -30)
    }
}

// MARK: - Volume slider

/// A rounded, draggable volume bar matching the settings design. `value` is
/// 0...1. `onChanged` fires continuously as the player drags; `onEditingEnded`
/// fires once when they let go.
struct VolumeSlider: View {
    @Binding var value: Double
    var onEditingEnded: ((Double) -> Void)? = nil
    var onChanged: ((Double) -> Void)? = nil

    private let trackHeight: CGFloat = 33
    private let thumbSize: CGFloat = 43

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(value, 0), 1)
            
            // Keep the thumb fully on the track at both ends.
            let travel = max(width - thumbSize, 0)
            let thumbX = travel * clamped

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: trackHeight)

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appTertiary.opacity(0.55))
                    .frame(width: thumbX + thumbSize / 2, height: trackHeight)

                Capsule()
                    .fill(Color.appTertiary)
                    .frame(width: 30, height: thumbSize)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .offset(x: thumbX)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let x = gesture.location.x - thumbSize / 2
                        let newValue = travel > 0 ? Double(x / travel) : 0
                        let bounded = min(max(newValue, 0), 1)
                        value = bounded
                        onChanged?(bounded)
                    }
                    .onEnded { _ in onEditingEnded?(value) }
            )
        }
        .frame(height: thumbSize)
    }
}

// MARK: - Two-option pill toggle

/// The pill-shaped segmented control used for Language and One-hand Mode.
/// The right option is selected when `isRightSelected` is true.
struct SegmentedPill: View {
    let leftTitle: String
    let rightTitle: String
    @Binding var isRightSelected: Bool
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            segment(title: leftTitle, selected: !isRightSelected) {
                isRightSelected = false
            }
            segment(title: rightTitle, selected: isRightSelected) {
                isRightSelected = true
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .allowsHitTesting(isEnabled)
    }

    private func segment(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            AudioManager.shared.play(.uiClick)
            action()
        }) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(selected ? Color.white : Color.appTertiaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected
                              ? Color.appTertiary.opacity(0.75)
                              : Color.gray.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray
        SettingsView(onClose: {})
    }
}
