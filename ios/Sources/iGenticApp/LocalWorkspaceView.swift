#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// The owner, not a model or remote tool, chooses when a local note is saved.
public struct LocalWorkspaceView: View {
    private let store = LocalWorkspaceStore()
    @State private var name = "notiz"
    @State private var draft = ""
    @State private var preview: LocalWorkspacePreview?
    @State private var feedback = "Keine Änderung ausgeführt."

    public init() {}

    public var body: some View {
        Form {
            Section("Eigene Notiz") {
                TextField("Name (ohne Dateiendung)", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("igentic-workspace-name")
                Button("Notiz laden") {
                    do {
                        draft = try store.read(name: name) ?? ""
                        feedback = "Notiz lokal geladen oder neu angelegt."
                    } catch { feedback = "Nicht lesbar: \(error.localizedDescription)" }
                }
                TextEditor(text: $draft)
                    .frame(minHeight: 130)
                    .accessibilityIdentifier("igentic-workspace-editor")
                Button("Änderung prüfen") {
                    do {
                        preview = try store.preview(name: name, text: draft)
                        feedback = "Nur Vorschau. Noch nichts gespeichert."
                    } catch {
                        preview = nil
                        feedback = "Prüfung fehlgeschlagen: \(error.localizedDescription)"
                    }
                }
                .accessibilityIdentifier("igentic-workspace-preview")
                Text(feedback).font(.footnote).accessibilityIdentifier("igentic-workspace-status")
            }
            if let preview {
                Section("Vorher – \(preview.name)") {
                    Text(preview.previous ?? "(noch keine Notiz)")
                        .textSelection(.enabled)
                }
                Section("Nachher – nur lokale Vorschau") {
                    Text(preview.proposed.isEmpty ? "(leer)" : preview.proposed)
                        .textSelection(.enabled)
                    Button("Diese Version lokal speichern") {
                        do {
                            try store.apply(preview, confirmedByOwner: true)
                            feedback = "Nach ausdrücklichem Tippen lokal gespeichert."
                        } catch {
                            feedback = "Nicht gespeichert: \(error.localizedDescription)"
                        }
                        self.preview = nil
                    }
                    .accessibilityIdentifier("igentic-workspace-save")
                }
            }
            Section("Sicherheit") {
                Text("Nur .txt-Dateien mit sicheren Namen, maximal 8 KiB. Speicherung ausschließlich im iGentic-App-Sandbox. Kein Shell-Zugriff, keine automatische Synchronisierung und kein direktes Modell- oder Plugin-Schreibrecht.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Lokaler Arbeitsbereich")
        .onChange(of: name) { _, _ in preview = nil }
        .onChange(of: draft) { _, _ in preview = nil }
    }
}
#endif
