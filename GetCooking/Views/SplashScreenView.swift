//
//  SplashScreenView.swift
//  GetCooking
//
//  Animated splash screen showing the lime-yellow 'PlayFeat!' mascot jumping
//  and waving with energetic squash-and-stretch physics against a pale-yellow
//  background, complete with dynamic ground shadow, energy sparks, and red-orange
//  branding text.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isVisible = false
    @State private var mascotPhase: JumpPhase = .settle

    private let paleYellowBG = Color(red: 255/255, green: 252/255, blue: 214/255) // #FFFCD6
    private let brandRedOrange = Color(red: 236/255, green: 98/255, blue: 67/255) // #EC6243
    private let purpleAccent = Color(red: 126/255, green: 96/255, blue: 191/255) // #7E60BF

    enum JumpPhase: CaseIterable {
        case anticipation
        case launch
        case peak
        case landing
        case settle

        var yOffset: CGFloat {
            switch self {
            case .anticipation: return 8
            case .launch: return -25
            case .peak: return -55
            case .landing: return 10
            case .settle: return 0
            }
        }

        var scaleX: CGFloat {
            switch self {
            case .anticipation: return 1.14
            case .launch: return 0.88
            case .peak: return 1.02
            case .landing: return 1.20
            case .settle: return 1.0
            }
        }

        var scaleY: CGFloat {
            switch self {
            case .anticipation: return 0.86
            case .launch: return 1.15
            case .peak: return 1.0
            case .landing: return 0.80
            case .settle: return 1.0
            }
        }

        var shadowScaleX: CGFloat {
            switch self {
            case .anticipation: return 1.18
            case .launch: return 0.8
            case .peak: return 0.55
            case .landing: return 1.25
            case .settle: return 1.0
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .anticipation: return 0.32
            case .launch: return 0.20
            case .peak: return 0.10
            case .landing: return 0.38
            case .settle: return 0.25
            }
        }

        var sparkScale: CGFloat {
            switch self {
            case .peak: return 1.0
            case .launch: return 0.6
            default: return 0.2
            }
        }

        var sparkOpacity: Double {
            switch self {
            case .peak: return 1.0
            case .launch: return 0.5
            default: return 0.0
            }
        }
    }

    var body: some View {
        ZStack {
            paleYellowBG
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Mascot Character with Animated Squash & Stretch + Shadow
                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        // Mascot Image
                        Image("Happy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .scaleEffect(
                                x: mascotPhase.scaleX,
                                y: mascotPhase.scaleY,
                                anchor: .bottom
                            )
                            .offset(y: mascotPhase.yOffset)

                        // Excitement / Energy Sparks near the Headband
                        HStack(spacing: 5) {
                            Capsule()
                                .fill(purpleAccent)
                                .frame(width: 4, height: 16)
                                .rotationEffect(.degrees(22))
                            Capsule()
                                .fill(purpleAccent)
                                .frame(width: 4, height: 22)
                                .rotationEffect(.degrees(28))
                        }
                        .offset(x: 18, y: mascotPhase.yOffset - 12)
                        .scaleEffect(mascotPhase.sparkScale)
                        .opacity(mascotPhase.sparkOpacity)
                    }

                    // Dynamic Ground Contact Shadow
                    Ellipse()
                        .fill(Color.black.opacity(mascotPhase.shadowOpacity))
                        .frame(
                            width: 140 * mascotPhase.shadowScaleX,
                            height: 16 * mascotPhase.shadowScaleX
                        )
                        .blur(radius: 4)
                        .offset(y: -6)
                }
                .scaleEffect(isVisible ? 1.0 : 0.85)
                .opacity(isVisible ? 1.0 : 0.0)

                // App Title / Brand Text
                Text("PlayFeat!")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(brandRedOrange)
                    .scaleEffect(isVisible ? 1.0 : 0.9)
                    .opacity(isVisible ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isVisible = true
            }
            startAnimationLoop()
        }
    }

    private func startAnimationLoop() {
        // Step 1: Anticipation squash
        withAnimation(.easeInOut(duration: 0.15)) {
            mascotPhase = .anticipation
        }
        // Step 2: Spring launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.22)) {
                mascotPhase = .launch
            }
        }
        // Step 3: Peak wave hold
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.37) {
            withAnimation(.easeInOut(duration: 0.20)) {
                mascotPhase = .peak
            }
        }
        // Step 4: Fall and landing impact squash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.57) {
            withAnimation(.easeIn(duration: 0.18)) {
                mascotPhase = .landing
            }
        }
        // Step 5: Settle & rebound
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                mascotPhase = .settle
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
