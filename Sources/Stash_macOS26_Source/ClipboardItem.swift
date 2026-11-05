import Foundation

enum ClipboardContentType: String, Codable, CaseIterable, Hashable {
    case text
    case url
    case code
    case image

    var label: String {
        switch self {
        case .text: "Text"
        case .url: "Link"
        case .code: "Code"
        case .image: "Image"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .url: "link"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .image: "photo"
        }
    }

    static func detect(_ value: String) -> ClipboardContentType {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let scheme = url.scheme,
           ["http", "https"].contains(scheme.lowercased()), url.host != nil {
            return .url
        }

        let codeMarkers = ["func ", "class ", "struct ", "import ", "const ", "let ",
                           "var ", "def ", "return ", "=>", "{", "};", "```"]
        let lines = trimmed.split(separator: "\n")
        if lines.count > 1 && codeMarkers.contains(where: { trimmed.contains($0) }) {
            return .code
        }
        return .text
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var content: String
    var createdAt: Date
    var type: ClipboardContentType
    var isPinned: Bool
    var imageData: Data?
    var imageFileName: String?

    init(content: String, createdAt: Date = .now, isPinned: Bool = false) {
        self.id = UUID()
        self.content = content
        self.createdAt = createdAt
        self.type = ClipboardContentType.detect(content)
        self.isPinned = isPinned
        self.imageData = nil
        self.imageFileName = nil
    }

    init(imageData: Data, createdAt: Date = .now, isPinned: Bool = false) {
        self.id = UUID()
        self.content = ""
        self.createdAt = createdAt
        self.type = .image
        self.isPinned = isPinned
        self.imageData = imageData
        self.imageFileName = "\(UUID().uuidString).png"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case createdAt
        case type
        case isPinned
        case imageFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        type = try container.decode(ClipboardContentType.self, forKey: .type)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        imageData = nil
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(type, forKey: .type)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
    }

    var preview: String {
        guard type != .image else { return "Image" }
        let flattened = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
        return flattened.isEmpty ? "Empty text" : flattened
    }
}
