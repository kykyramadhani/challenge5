//
//  GameCenter.swift
//  GetCooking
//
//  Game Center in three calls: sign in at launch, submit the run's dish count
//  when a run ends, and open the dashboard from the Most Dishes Served card.
//
//  Everything here fails quietly on purpose. A player who declined the sign-in
//  prompt, or has no network, still gets the whole game — GameStorage.highscore
//  stays the source of truth for what the UI shows, and Game Center is a bonus
//  layer on top of it.
//

import GameKit
import UIKit

enum GameCenter {
    /// Must match the leaderboard ID created in App Store Connect character for
    /// character — a mismatch fails silently, scores just never show up.
    static let leaderboardID = "com.reability.playfeat.mostdishes"

    /// Call once, from a view that's already on screen: GameKit can hand back a
    /// sign-in screen that needs a window to be presented from.
    static func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { signInScreen, _ in
            guard let signInScreen else { return }
            rootViewController?.present(signInScreen, animated: true)
        }
    }

    /// Submit every run, not just personal bests — Game Center keeps the best
    /// score per player itself, and a submit that loses to the stored one is a
    /// no-op on their side.
    static func submit(_ dishesServed: Int) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(
                dishesServed,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID]
            )
        }
    }

    static func showLeaderboard() {
        guard GKLocalPlayer.local.isAuthenticated, let root = rootViewController else { return }
        let dashboard = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        dashboard.gameCenterDelegate = dismisser
        root.present(dashboard, animated: true)
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
    }

    /// GKGameCenterViewController never dismisses itself, and its delegate has
    /// to be an NSObject — hence this one-job singleton.
    private static let dismisser = Dismisser()

    private final class Dismisser: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
