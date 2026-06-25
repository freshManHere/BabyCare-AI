import Foundation

extension BabyEvent {
    var shortDescription: String {
        switch payload {
        case .feeding(let p):
            let method = p.method.rawValue
            if let amount = p.amountMl {
                return "\(method) · \(amount)ml"
            }
            return method
        case .sleep(let p):
            if let end = endTime {
                let minutes = Int(end.timeIntervalSince(startTime) / 60)
                let hours = minutes / 60
                let mins = minutes % 60
                let duration = hours > 0 ? "\(hours)小时\(mins > 0 ? "\(mins)分钟" : "")" : "\(mins)分钟"
                return "\(p.sleepType.rawValue) · \(duration)"
            }
            return p.sleepType.rawValue + " · 进行中"
        case .diaper(let p):
            return "排便\(p.count)次\(p.hasBloodOrMucus ? " · ⚠️有血丝" : "")"
        case .diaperChange(let p):
            return "\(p.reason.rawValue) · \(p.urineAmount.rawValue)"
        case .outing(let p):
            return p.destination.isEmpty ? p.transportation.rawValue : "\(p.destination) · \(p.transportation.rawValue)"
        case .bath(let p):
            if let temp = p.waterTempCelsius {
                return "水温 \(Int(temp))°C"
            }
            return "已完成洗澡"
        case .motorSkill(let p):
            let actions = p.actionTypes.map(\.rawValue).joined(separator: "、")
            return actions.isEmpty ? "运动记录" : actions
        case .symptom(let p):
            let types = p.types.joined(separator: "、")
            let prefix = p.isHighRisk ? "⚠️ " : ""
            return "\(prefix)\(types.isEmpty ? p.severity.rawValue : types)"
        case .other(let text):
            return text.isEmpty ? "其他记录" : text
        }
    }
}
