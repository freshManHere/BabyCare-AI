import SwiftUI

struct AddRecordView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLabel: EventLabel
    @State private var store = EventStore.shared
    // Bug #23 fix: keep a reference to the initial label so we can re-sync state
    private let initialLabel: EventLabel

    init(preselectedLabel: EventLabel?) {
        let label = preselectedLabel ?? .feeding
        self.initialLabel = label
        _selectedLabel = State(initialValue: label)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Bug #23 + #24 fix: ScrollViewReader lets us scroll the selected chip into view
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EventLabel.allCases) { label in
                                FilterChip(
                                    title: label.rawValue,
                                    icon: label.icon,
                                    isSelected: selectedLabel == label
                                ) {
                                    selectedLabel = label
                                    withAnimation {
                                        proxy.scrollTo(label.id, anchor: .center)
                                    }
                                }
                                .id(label.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemBackground))
                    // Bug #24 fix: scroll to selected chip on appear
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo(selectedLabel.id, anchor: .center)
                        }
                    }
                }

                Divider()

                // Form
                formForSelectedLabel
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("新增记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            // Bug #23 fix: force view identity reset when preselected label differs,
            // ensuring @State selectedLabel is re-initialized from the new initialLabel
            .id(initialLabel)
        }
    }

    @ViewBuilder
    private var formForSelectedLabel: some View {
        switch selectedLabel {
        case .feeding:
            FeedingFormView { event in
                store.add(event)
                dismiss()
            }
        case .sleep:
            SleepFormView { event in
                store.add(event)
                dismiss()
            }
        case .diaperChange:
            DiaperChangeFormView { event in
                store.add(event)
                dismiss()
            }
        case .outing:
            OutingFormView { event in
                store.add(event)
                dismiss()
            }
        case .bath:
            BathFormView { event in
                store.add(event)
                dismiss()
            }
        case .motorSkill:
            MotorSkillFormView { event in
                store.add(event)
                dismiss()
            }
        case .symptom:
            SymptomFormView { event in
                store.add(event)
                dismiss()
            }
        default:
            GenericFormView(label: selectedLabel) { event in
                store.add(event)
                dismiss()
            }
        }
    }
}
