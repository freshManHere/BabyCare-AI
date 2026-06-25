import SwiftUI

struct AddRecordView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLabel: EventLabel
    @State private var store = EventStore.shared

    init(preselectedLabel: EventLabel?) {
        _selectedLabel = State(initialValue: preselectedLabel ?? .feeding)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EventLabel.allCases) { label in
                            FilterChip(
                                title: label.rawValue,
                                icon: label.icon,
                                isSelected: selectedLabel == label
                            ) {
                                selectedLabel = label
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))

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
        default:
            GenericFormView(label: selectedLabel) { event in
                store.add(event)
                dismiss()
            }
        }
    }
}
