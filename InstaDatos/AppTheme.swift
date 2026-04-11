import SwiftUI

enum AppTheme {
    static let bg = Color(hex: 0xFFFFFF)
    static let accent = Color(hex: 0xF98F53)
    /// Marca / mensajes humano (chat OpenClaw)
    static let brandOrange = Color(hex: 0xF47C20)
    /// Mensajes IA (chat)
    static let aiGrey = Color(hex: 0x94A3B8)
    static let muted = Color(hex: 0xBDB8B4)
    static let ink = Color(hex: 0x705F59)
    static let cocoa = Color(hex: 0x7A5A4F)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

