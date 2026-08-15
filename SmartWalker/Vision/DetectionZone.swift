import Foundation
import CoreGraphics

/// Which part of the frame an obstacle sits in.
enum DetectionZone: String {
    case left
    case center
    case right
}

/// A single object the detector found, normalized to what the safety logic needs.
struct DetectedObject {
    let label: String
    let confidence: Float
    /// Bounding box in Vision's normalized coordinates (origin bottom-left, 0...1).
    let boundingBox: CGRect

    /// Fraction of the frame area the box covers — our crude "closeness" proxy.
    var areaFraction: CGFloat { boundingBox.width * boundingBox.height }

    /// Horizontal center of the box (0 = far left, 1 = far right).
    var centerX: CGFloat { boundingBox.midX }

    /// Zone based on horizontal center, with a wide center band (the walker's path).
    var zone: DetectionZone {
        switch centerX {
        case ..<0.38:  return .left
        case 0.62...:  return .right
        default:       return .center
        }
    }
}

/// How urgent an obstacle is, driving what we say and how loudly we interrupt.
enum ObstacleUrgency: Int, Comparable {
    case none = 0      // ignore
    case caution = 1   // "slow down"
    case stop = 2      // "stop"

    static func < (lhs: ObstacleUrgency, rhs: ObstacleUrgency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// How blocked each zone is, so we can steer around an obstacle instead of only stopping.
struct ZoneReport {
    var left: ObstacleUrgency = .none
    var center: ObstacleUrgency = .none
    var right: ObstacleUrgency = .none
}

enum ZoneLogic {
    /// Area thresholds (fraction of frame) for how close something is.
    static let stopArea: CGFloat = 0.28     // big & near -> stop
    static let cautionArea: CGFloat = 0.12  // medium -> caution
    /// Below this, treat as far away / not in path -> don't nag.
    static let ignoreArea: CGFloat = 0.06
    /// Very close / filling the view -> too late to steer, just stop.
    static let imminentArea: CGFloat = 0.42

    /// Decide urgency for a single object given its size and position.
    static func urgency(for object: DetectedObject) -> ObstacleUrgency {
        if object.areaFraction < ignoreArea { return .none }
        if object.areaFraction >= stopArea { return .stop }
        if object.areaFraction >= cautionArea { return .caution }
        return .none
    }

    /// Summarize how blocked each zone is across all detected objects.
    static func assess(_ objects: [DetectedObject]) -> ZoneReport {
        var report = ZoneReport()
        for object in objects {
            let u = urgency(for: object)
            guard u != .none else { continue }
            switch object.zone {
            case .left:   report.left = max(report.left, u)
            case .center: report.center = max(report.center, u)
            case .right:  report.right = max(report.right, u)
            }
        }
        return report
    }

    /// The single best thing to say for a frame - steering around obstacles when it can,
    /// stopping outright when something is right in front, and only saying "stop" as a
    /// last resort when every direction is blocked. Returns nil when the path is clear.
    static func guidance(for objects: [DetectedObject]) -> (phrase: String, urgency: ObstacleUrgency)? {
        let report = assess(objects)

        // Something in the path ahead.
        if report.center >= .caution {
            let center = biggestCenter(objects)
            let noun = (center.flatMap { friendlyName($0.label) })?.capitalizedFirst ?? "Obstacle"
            let area = center?.areaFraction ?? 0

            // Too close to steer around — stop now.
            if area >= imminentArea {
                return ("\(noun) ahead. Stop.", .stop)
            }

            if report.center == .stop {
                if report.left == .none {
                    return ("\(noun) ahead. Step to your left.", .stop)
                } else if report.right == .none {
                    return ("\(noun) ahead. Step to your right.", .stop)
                } else {
                    return ("\(noun) ahead. Stop.", .stop)   // nowhere to go
                }
            } else { // caution
                if report.left == .none && report.right != .none {
                    return ("\(noun) ahead. Ease to your left.", .caution)
                } else if report.right == .none && report.left != .none {
                    return ("\(noun) ahead. Ease to your right.", .caution)
                } else {
                    return ("\(noun) ahead. Slow down.", .caution)
                }
            }
        }

        // Path ahead is clear - warn about anything close on the sides.
        let sideWorst = max(report.left, report.right)
        guard sideWorst >= .caution else { return nil }

        if report.left >= .caution && report.right >= .caution {
            return ("Careful. Narrow path. Stay centered.", sideWorst)
        }
        if report.left >= .caution {
            return ("Obstacle on your left. Move right.", report.left)
        }
        return ("Obstacle on your right. Move left.", report.right)
    }

    /// The most prominent (largest) obstacle in the center path, if any.
    private static func biggestCenter(_ objects: [DetectedObject]) -> DetectedObject? {
        objects
            .filter { $0.zone == .center && urgency(for: $0) != .none }
            .max { $0.areaFraction < $1.areaFraction }
    }

    /// Map raw model labels to friendly nouns; return nil to fall back to "obstacle".
    private static func friendlyName(_ label: String) -> String? {
        let l = label.lowercased()
        let known = ["chair", "table", "sofa", "couch", "door", "person",
                     "dog", "cat", "bag", "box", "bed", "tv", "bench",
                     "bottle", "bicycle", "stairs"]
        if l.contains("person") { return "person" }
        if l.contains("dog") || l.contains("cat") { return "pet" }
        if l.contains("couch") || l.contains("sofa") { return "sofa" }
        for k in known where l.contains(k) { return k }
        return nil
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
