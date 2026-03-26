import SwiftUI

extension ChartsView {
    var inspectorTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: L10n.shared.keyInspectorSection, helpText: L10n.shared.helpKeyInspector)
                KeyInspectorView()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
