import SwiftUI

/// A Toggle that automatically dismisses the keyboard when it is tapped.
/// Drop-in replacement for `Toggle` in forms that contain TextFields.
struct DismissingToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .onChange(of: isOn) { _, _ in
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
    }
}
