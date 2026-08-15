import SwiftUI

/// Centralized styling. Warm, friendly, neutral tones with large, rounded type.
/// Kept high-legibility for elderly / low-vision users — friendly, but never faint.
enum Theme {
    // MARK: Core palette (warm + light)
    static let background    = Color(red: 0.953, green: 0.929, blue: 0.878) // warm sand
    static let surface       = Color(red: 0.996, green: 0.984, blue: 0.961) // soft cream card
    static let primaryText   = Color(red: 0.204, green: 0.176, blue: 0.145) // warm near-black
    static let secondaryText = Color(red: 0.451, green: 0.408, blue: 0.349) // muted taupe
    static let accent        = Color(red: 0.780, green: 0.451, blue: 0.271) // warm terracotta

    // Semantic (kept clearly distinct for safety cues)
    static let danger  = Color(red: 0.769, green: 0.271, blue: 0.204) // warm brick red — stop
    static let caution = Color(red: 0.886, green: 0.588, blue: 0.243) // warm amber — slow
    static let safe    = Color(red: 0.427, green: 0.549, blue: 0.373) // sage green — clear

    // MARK: Map tones
    static let wall = Color(red: 0.478, green: 0.388, blue: 0.286)     // warm brown walls
    static let floors: [Color] = [
        Color(red: 0.906, green: 0.812, blue: 0.651), // light oak
        Color(red: 0.867, green: 0.733, blue: 0.549), // honey wood
        Color(red: 0.925, green: 0.882, blue: 0.788), // warm tile
        Color(red: 0.851, green: 0.780, blue: 0.663), // greige
        Color(red: 0.898, green: 0.773, blue: 0.631)  // clay tile
    ]

    // MARK: Type (large + rounded is already friendly)
    static let hugeTitle = Font.system(size: 40, weight: .bold, design: .rounded)
    static let title = Font.system(size: 30, weight: .bold, design: .rounded)
    static let body = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let label = Font.system(size: 20, weight: .medium, design: .rounded)

    // MARK: Metrics
    static let buttonMinHeight: CGFloat = 84
    static let corner: CGFloat = 20
    static let spacing: CGFloat = 16
}
