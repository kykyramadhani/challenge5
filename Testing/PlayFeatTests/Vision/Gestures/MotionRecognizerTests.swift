//
//  MotionRecognizerTests.swift
//  PlayFeatTests
//
//  The chop and scrub recognizers, checked on synthetic hand paths. Ported
//  with the recognizers from GestureLab, so the game keeps its guarantees.
//

import Foundation
import Testing
@testable import PlayFeat

struct MotionRecognizerTests {
    private func total(_ motion: ProcessMotion, _ path: [CGPoint]) -> Double {
        var recognizer = MotionRecognizer(motion: motion, minStep: 5, strokeLength: 40)
        return path.reduce(0) { $0 + recognizer.feed($1, dt: 1.0 / 30) }
    }

    private func circles(_ turns: Double, radius: CGFloat = 40) -> [CGPoint] {
        let steps = Int(turns * 36)
        return (0...steps).map {
            let angle = CGFloat($0) / 36 * 2 * .pi
            return CGPoint(x: 200 + cos(angle) * radius, y: 200 + sin(angle) * radius)
        }
    }

    private func backAndForth(strokes: Int, length: CGFloat = 60) -> [CGPoint] {
        (0..<strokes).flatMap { stroke -> [CGPoint] in
            let xs = stride(from: 0, through: length, by: 6).map { stroke.isMultiple(of: 2) ? $0 : length - $0 }
            return xs.enumerated().map { CGPoint(x: 100 + $1, y: 100 + sin(CGFloat($0 + stroke) * 7.3)) }
        }
    }

    @Test func circlesCountTurns() {
        #expect(abs(total(.circles, circles(3)) - 3) < 0.15)
    }

    @Test func backAndForthIsNotACircle() {
        #expect(total(.circles, backAndForth(strokes: 8)) < 0.2)
    }

    @Test func downStrokesNeedALiftBetween() {
        let chops = (0..<4).flatMap { _ in
            stride(from: 100, through: 40, by: -6).map { CGPoint(x: 50, y: $0) }
                + stride(from: 40, through: 100, by: 6).map { CGPoint(x: 50, y: $0) }
        }
        #expect(total(.downStrokes, chops) == 4)
        // One long slide down is a single stroke, not many.
        #expect(total(.downStrokes, stride(from: 400, through: 0, by: -6).map { CGPoint(x: 50, y: $0) }) == 1)
        #expect(total(.downStrokes, backAndForth(strokes: 8)) == 0)
    }

    @Test func jitterBelowMinStepIsIgnored() {
        let jitter = (0..<200).map { CGPoint(x: 100 + 2 * sin(CGFloat($0) * 1.7), y: 100 + 2 * cos(CGFloat($0) * 2.9)) }
        #expect(total(.circles, jitter) == 0)
        #expect(total(.downStrokes, jitter) == 0)
    }
}
