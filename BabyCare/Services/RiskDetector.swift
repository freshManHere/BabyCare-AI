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
        "建议就医", "看医生", "去医院", "及时就诊", "发烧超过",
        "持续高烧", "需要就医", "尽快就医", "及时就医", "医院检查",
        "就医处理", "前往医院"
    ]

    static func detect(in text: String) -> RiskLevel {
        if highRiskKeywords.contains(where: { text.contains($0) }) { return .high }
        if mediumRiskKeywords.contains(where: { text.contains($0) }) { return .medium }
        return .none
    }
}
