import Foundation

enum RiskLevel {
    case none, medium, high
}

enum RiskDetector {
    private static let highRiskKeywords = [
        "立即就医", "拨打急救", "拨打120", "打120急救",
        "惊厥", "抽搐", "休克", "窒息", "紫绀", "发绀",
        "生命危险", "危及生命"
    ]
    private static let mediumRiskKeywords = [
        "尽快就医", "立刻就医", "马上就医", "紧急就医",
        "高烧不退", "反复抽搐", "持续惊厥"
    ]

    static func detect(in text: String) -> RiskLevel {
        if highRiskKeywords.contains(where: { text.contains($0) }) { return .high }
        if mediumRiskKeywords.contains(where: { text.contains($0) }) { return .medium }
        return .none
    }
}
