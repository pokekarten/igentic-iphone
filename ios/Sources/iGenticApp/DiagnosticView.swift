#if canImport(SwiftUI)
import SwiftUI

public struct DiagnosticView: View {
    private let state: DiagnosticViewState

    public init(state: DiagnosticViewState = DiagnosticViewState()) {
        self.state = state
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Safety") {
                    LabeledContent("Operating mode", value: state.operatingMode)
                    LabeledContent("Runtime status", value: state.runtimeStatus)
                    LabeledContent("Audit", value: state.auditStatus)
                    LabeledContent("Validation", value: state.validationStatus)
                    LabeledContent("Privacy", value: state.privacyNotice)
                }

                Section("Sample / preview snapshot") {
                    LabeledContent("Source", value: state.snapshotSource)

                    ForEach(state.snapshotFields) { field in
                        DiagnosticMetric(label: field.label, value: field.value)
                    }

                    DiagnosticMetric(label: "Audit events", value: state.auditEventsDescription)
                }

                Section("Synthetic scenarios") {
                    ForEach(state.rows) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.title)
                                .font(.headline)

                            DiagnosticMetric(label: "Route", value: row.route)
                            DiagnosticMetric(label: "Policy", value: row.policy)
                            DiagnosticMetric(label: "Approval", value: row.approval)
                            DiagnosticMetric(label: "Delegation", value: row.delegation)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("iGentic Diagnostics")
        }
    }
}

private struct DiagnosticMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
#endif
