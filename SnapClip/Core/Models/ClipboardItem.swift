import Foundation

struct ClipboardItem: Codable {
    let text: String
    let timestamp: Date
    let id: UUID
    var isPinned: Bool = false 
    
    enum CodingKeys: String, CodingKey {
        case text, timestamp, id, isPinned
    }
}

