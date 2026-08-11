import Foundation

/// Builds the system prompt for the AI assistant, injecting the past 7 days of real baby data.
enum AssistantContextBuilder {

    @MainActor
    static func buildSystemPrompt(baby: Baby?, store: EventStore) -> String {
        var lines: [String] = []

        lines.append("""
        你是一位专业、温暖的育儿顾问助手，专门帮助新手父母照料婴幼儿。
        回答时：
        - 语言简洁、友好、有据可依
        - 遇到医疗紧急情况，始终建议立即就医或拨打120
        - 不替代医生诊断，但可以提供参考建议
        - 优先基于宝宝的真实数据回答，而非泛泛而谈
        - 数据来源为宝宝近7天的真实记录
        """)

        guard let baby else {
            lines.append("\n当前尚未设置宝宝信息。")
            return lines.joined(separator: "\n")
        }

        // Baby profile
        lines.append("\n【宝宝信息】")
        lines.append("- 昵称：\(baby.nickname)")
        lines.append("- 性别：\(baby.gender.rawValue)")
        lines.append("- 月龄：\(baby.ageDescription)")

        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!
        let _ = weekStart // used implicitly via dayOffset loops

        // Per-day summary for last 7 days
        lines.append("\n【近7天每日记录（详细）】")
        for dayOffset in (0...6).reversed() {
            guard let dayStart = cal.date(byAdding: .day, value: -dayOffset, to: cal.startOfDay(for: now)),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let dayLabel = dayOffset == 0 ? "今天" : (dayOffset == 1 ? "昨天" : "\(dayOffset)天前")
            let dayEvents = store.events(babyId: baby.id, from: dayStart, to: dayEnd)

            var parts: [String] = []

            // Feeding
            let dayFeedings = dayEvents.filter { $0.label == .feeding }
            if !dayFeedings.isEmpty {
                var bottleMl = 0; var breastMins = 0
                for e in dayFeedings {
                    if case .feeding(let p) = e.payload {
                        bottleMl += p.amountMl ?? 0
                        breastMins += p.durationMinutes ?? 0
                    }
                }
                var feedStr = "喂养\(dayFeedings.count)次"
                if bottleMl > 0 { feedStr += "·瓶\(bottleMl)ml" }
                if breastMins > 0 { feedStr += "·亲\(breastMins)min" }
                parts.append(feedStr)
            }

            // Diapers
            let dayDiapers = dayEvents.filter { $0.label == .diaperChange }
            if !dayDiapers.isEmpty {
                let poopCount = dayDiapers.filter {
                    if case .diaperChange(let p) = $0.payload { return p.hadPoop }
                    return false
                }.count
                var diaperStr = "换尿布\(dayDiapers.count)次"
                if poopCount > 0 { diaperStr += "(大便\(poopCount)次)" }
                parts.append(diaperStr)
            }

            // Sleep
            let daySleeps = dayEvents.filter { $0.label == .sleep }
            if !daySleeps.isEmpty {
                let totalMins = daySleeps.reduce(0) { sum, e -> Int in
                    guard let end = e.endTime else { return sum }
                    return sum + Int(end.timeIntervalSince(e.startTime) / 60)
                }
                if totalMins > 0 {
                    let h = totalMins / 60, m = totalMins % 60
                    parts.append("睡眠\(h > 0 ? "\(h)h" : "")\(m > 0 ? "\(m)m" : "")")
                } else {
                    parts.append("睡眠进行中")
                }
            }

            // Symptoms
            let daySymptoms = dayEvents.filter { $0.label == .symptom }
            if !daySymptoms.isEmpty {
                parts.append("症状\(daySymptoms.count)条")
            }

            lines.append("- \(dayLabel)：\(parts.isEmpty ? "无记录" : parts.joined(separator: "，"))")
        }

        // Weekly buckets for days 8–30 (week 2, week 3, week 4)
        lines.append("\n【近30天按周汇总（第2–4周）】")
        let weekRanges: [(label: String, offset: Int)] = [
            ("第2周（8-14天前）", 8),
            ("第3周（15-21天前）", 15),
            ("第4周（22-30天前）", 22)
        ]
        for bucket in weekRanges {
            let endOffset = bucket.offset == 22 ? 30 : bucket.offset + 6
            guard let bucketEnd = cal.date(byAdding: .day, value: -(bucket.offset - 1), to: cal.startOfDay(for: now)),
                  let bucketStart = cal.date(byAdding: .day, value: -endOffset, to: cal.startOfDay(for: now)) else { continue }
            let bucketEvents = store.events(babyId: baby.id, from: bucketStart, to: bucketEnd)
            guard !bucketEvents.isEmpty else {
                lines.append("- \(bucket.label)：无记录")
                continue
            }
            let feedings = bucketEvents.filter { $0.label == .feeding }.count
            let diapers  = bucketEvents.filter { $0.label == .diaperChange }
            let poops    = diapers.filter {
                if case .diaperChange(let p) = $0.payload { return p.hadPoop }
                return false
            }.count
            let symptoms = bucketEvents.filter { $0.label == .symptom }.count
            var parts = ["喂养\(feedings)次", "换尿布\(diapers.count)次(大便\(poops)次)"]
            if symptoms > 0 { parts.append("症状\(symptoms)条") }
            lines.append("- \(bucket.label)：\(parts.joined(separator: "，"))")
        }

        return lines.joined(separator: "\n")
    }
}
