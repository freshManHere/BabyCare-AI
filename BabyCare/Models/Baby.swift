import Foundation

struct Baby: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var nickname: String
    var birthday: Date
    var gender: Gender
    var avatarData: Data?

    enum Gender: String, Codable, CaseIterable {
        case male = "男宝"
        case female = "女宝"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, nickname, birthday, gender
        case avatarBase64
        // avatarData is local-only UI cache, never sent to/received from server directly
    }

    init(id: UUID = UUID(), name: String, nickname: String, birthday: Date, gender: Gender, avatarData: Data? = nil) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.birthday = birthday
        self.gender = gender
        self.avatarData = avatarData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id         = try container.decodeIfPresent(UUID.self,   forKey: .id)       ?? UUID()
        name       = try container.decode(String.self,          forKey: .name)
        nickname   = try container.decode(String.self,          forKey: .nickname)
        gender     = try container.decode(Gender.self,          forKey: .gender)
        // Date handled by APIClient.decoder's custom dateDecodingStrategy
        birthday   = try container.decode(Date.self, forKey: .birthday)
        // Decode base64 avatar from server → Data
        if let b64 = try container.decodeIfPresent(String.self, forKey: .avatarBase64),
           let data = Data(base64Encoded: b64) {
            avatarData = data
        } else {
            avatarData = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id,       forKey: .id)
        try container.encode(name,     forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(gender,   forKey: .gender)
        // Encode birthday as date-only string for the backend
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        try container.encode(formatter.string(from: birthday), forKey: .birthday)
        // Encode local avatarData as base64 for server storage
        if let data = avatarData {
            try container.encode(data.base64EncodedString(), forKey: .avatarBase64)
        }
    }

    var ageInMonths: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthday, to: Date())
        return max(0, components.month ?? 0)
    }

    var ageDescription: String {
        let months = ageInMonths
        if months < 1 {
            let days = Calendar.current.dateComponents([.day], from: birthday, to: Date()).day ?? 0
            return "\(days)天"
        } else if months < 12 {
            return "\(months)个月"
        } else {
            let years = months / 12
            let remainingMonths = months % 12
            if remainingMonths == 0 {
                return "\(years)岁"
            }
            return "\(years)岁\(remainingMonths)个月"
        }
    }
}

// MARK: - Preview Data
extension Baby {
    static let preview = Baby(
        name: "小宝",
        nickname: "小宝",
        birthday: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
        gender: .male
    )
}
