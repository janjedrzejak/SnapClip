import Foundation

// MARK: - Clipboard Item Model
struct ClipboardItem: Codable {
    let text: String
    let timestamp: Date
    let id: UUID
}
