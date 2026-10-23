import SwiftUI
import AppKit

struct CCAAccount: Codable, Identifiable, Hashable {
    var name: String
    var isDefault: Bool
    var email: String?
    var org: String?
    var loggedIn: Bool
    var color: String?
    var app: String?
    var running: Bool
    var folders: [String]
    var id: String { name }
}

struct CCAState: Codable {
    var version: Int
    var `default`: String
    var colors: [String]
    var autobackup: Bool
    var snapshots: [String]
    var accounts: [CCAAccount]
}

enum CCAColor {
    static func color(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .gray
        }
    }

    static func nsColor(_ name: String) -> NSColor {
        switch name {
        case "red": return .systemRed
        case "orange": return .systemOrange
        case "yellow": return .systemYellow
        case "green": return .systemGreen
        case "teal": return .systemTeal
        case "blue": return .systemBlue
        case "purple": return .systemPurple
        case "pink": return .systemPink
        default: return .systemGray
        }
    }

    /// Non-template dot for menus; no colour gives a gray outline.
    static func dotImage(_ name: String?, size: CGFloat = 12) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let r = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
            let path = NSBezierPath(ovalIn: r)
            if let name = name {
                nsColor(name).setFill()
                path.fill()
            } else {
                NSColor.systemGray.setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
            return true
        }
        img.isTemplate = false
        return img
    }
}

struct ColorDot: View {
    var color: String?
    var size: CGFloat = 12

    var body: some View {
        Group {
            if let color = color {
                Circle().fill(CCAColor.color(color))
            } else {
                Circle().strokeBorder(Color.gray, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
    }
}
