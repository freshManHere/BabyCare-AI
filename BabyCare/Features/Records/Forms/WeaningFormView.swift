import SwiftUI

struct WeaningFormView: View {
    @EnvironmentObject private var appState: AppState
    let onSave: (BabyEvent) -> Void

    @State private var time: Date
    @State private var foodName: String
    @State private var texture: WeaningPayload.Texture
    @State private var amount: String
    @State private var isAllergyCleared: Bool
    @State private var isAllergyTesting: Bool
    @State private var reaction: WeaningPayload.Reaction
    @State private var note: String

    private let existingEvent: BabyEvent?

    private let commonFoods = [
        "米粉", "苹果泥", "香蕉泥", "南瓜泥", "胡萝卜泥",
        "蛋黄", "西蓝花泥", "土豆泥", "米糊", "肉泥"
    ]

    init(existingEvent: BabyEvent? = nil, onSave: @escaping (BabyEvent) -> Void) {
        self.existingEvent = existingEvent
        self.onSave = onSave
        if let event = existingEvent, case .weaning(let p) = event.payload {
            _time = State(initialValue: event.startTime)
            _foodName = State(initialValue: p.foodName)
            _texture = State(initialValue: p.texture)
            _amount = State(initialValue: p.amount)
            _isAllergyCleared = State(initialValue: p.isAllergyCleared)
            _isAllergyTesting = State(initialValue: p.isAllergyTesting)
            _reaction = State(initialValue: p.reaction)
            _note = State(initialValue: event.note)
        } else {
            _time = State(initialValue: Date())
            _foodName = State(initialValue: "")
            _texture = State(initialValue: .thinPaste)
            _amount = State(initialValue: "")
            _isAllergyCleared = State(initialValue: false)
            _isAllergyTesting = State(initialValue: false)
            _reaction = State(initialValue: .none)
            _note = State(initialValue: "")
        }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("时间", selection: $time, displayedComponents: [.date, .hourAndMinute])
            }

            Section("辅食种类") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(commonFoods, id: \.self) { food in
                        SelectChip(title: food, isSelected: foodName == food) {
                            foodName = (foodName == food) ? "" : food
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                TextField("其他食材（选填）", text: $foodName)
            }

            Section("性状") {
                Picker("性状", selection: $texture) {
                    ForEach(WeaningPayload.Texture.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("食量") {
                TextField("例如 2勺 / 50g / 大半碗", text: $amount)
            }

            Section("排敏状态") {
                DismissingToggle(title: "已排敏", isOn: Binding(
                    get: { isAllergyCleared },
                    set: { setAllergyCleared($0) }
                ))
                DismissingToggle(title: "新加排敏中", isOn: Binding(
                    get: { isAllergyTesting },
                    set: { setAllergyTesting($0) }
                ))
            }

            Section("进食反应") {
                Picker("反应", selection: $reaction) {
                    ForEach(WeaningPayload.Reaction.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("备注") {
                TextField("选填", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button("保存") { save() }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(Color.pink)
            }
        }
    }

    private func save() {
        guard let baby = appState.currentBaby else { return }
        let payload = WeaningPayload(
            foodName: foodName,
            texture: texture,
            amount: amount,
            isAllergyCleared: isAllergyCleared,
            isAllergyTesting: isAllergyTesting,
            reaction: reaction
        )
        if var updated = existingEvent {
            updated.startTime = time
            updated.note = note
            updated.payload = .weaning(payload)
            onSave(updated)
        } else {
            let event = BabyEvent(
                babyId: baby.id,
                label: .weaning,
                startTime: time,
                note: note,
                payload: .weaning(payload)
            )
            onSave(event)
        }
    }

    private func setAllergyCleared(_ value: Bool) {
        isAllergyCleared = value
        if value { isAllergyTesting = false }
    }

    private func setAllergyTesting(_ value: Bool) {
        isAllergyTesting = value
        if value { isAllergyCleared = false }
    }
}
