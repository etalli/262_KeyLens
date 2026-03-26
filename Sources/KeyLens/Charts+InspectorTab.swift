import SwiftUI

extension ChartsView {
    var inspectorTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                chartSection(L10n.shared.keyInspectorSection, helpText: L10n.shared.helpKeyInspector) {
                    KeyInspectorView()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
