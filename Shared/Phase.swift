import SwiftUI

enum Phase: String, Codable, Hashable {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}

struct Palette {
    let sand: Color
    let sandShade: Color
    let frame: Color
    let frameShade: Color
    let backgroundTop: Color
    let backgroundBottom: Color

    init(phase: Phase) {
        switch phase {
        case .focus:
            sand = Color(hex: 0xF2B865)
            sandShade = Color(hex: 0xC98A3C)
            frame = Color(hex: 0x8C5D38)
            frameShade = Color(hex: 0x553620)
            backgroundTop = Color(hex: 0x231A13)
            backgroundBottom = Color(hex: 0x0E0B08)
        case .shortBreak, .longBreak:
            sand = Color(hex: 0x93DEC9)
            sandShade = Color(hex: 0x5BB39C)
            frame = Color(hex: 0x3F7068)
            frameShade = Color(hex: 0x24443F)
            backgroundTop = Color(hex: 0x12211F)
            backgroundBottom = Color(hex: 0x070D0C)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
