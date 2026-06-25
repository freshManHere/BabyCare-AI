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
