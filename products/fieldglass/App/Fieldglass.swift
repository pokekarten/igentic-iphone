import SwiftUI
import PhotosUI

@main
struct Fieldglass: App {
    var body: some Scene { WindowGroup { Workbench() } }
}

struct Workbench: View {
    @State private var experimentID = UUID()
    @State private var term = "ORBIT"
    @State private var region = Region.all
    @State private var data = Reader.sample()
    @State private var source = "example"
    @State private var selection: PhotosPickerItem?
    @State private var generation = UUID()
    @FocusState private var editingTerm: Bool
    @State private var latestCheckSucceeded = false
    @State private var busy = false
    @State private var readings: [Reading] = []
    @State private var message: String?
    @State private var alternate = false
    @State private var report: String?
    @State private var workspaceJob: WorkspaceJob?
    @State private var importing = false
    @State private var linkText = ""
    @State private var loading = false
    @State private var sampleRevision = UUID()

    private var experiment: Experiment? { Experiment(id: experimentID, term: term, region: region) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { workspaceJob = WorkspaceJob() } label: {
                        Label("Werkzeuge öffnen", systemImage: "square.grid.2x2")
                    }
                }
                Section("Bildquelle") {
                    if let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 190)
                            .frame(maxWidth: .infinity).accessibilityLabel(source == "example" ? (alternate ? "Beispielbild mit NORD oben und HAFEN unten" : "Beispielbild mit ORBIT oben und HAFEN unten") : "Ausgewähltes Bild")
                    }
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label("Bild auswählen", systemImage: "photo.on.rectangle")
                    }
                    if source == "example" && !loading {
                        Button("Beispiel wechseln") { alternate.toggle(); data = Reader.sample(alternate: alternate); invalidate() }
                    } else {
                        Button("Beispielbild verwenden") {
                            sampleRevision = UUID(); selection = nil; loading = false
                            alternate = false; data = Reader.sample(); source = "example"; invalidate()
                        }
                    }
                }
                Section("Text im Bild prüfen") {
                    TextField("Suchtext", text: Binding(get: { term }, set: { term = $0; newExperiment() }))
                        .focused($editingTerm)
                        .submitLabel(.search)
                        .onSubmit { run() }
                        .accessibilityIdentifier("term")
                    Picker("Bereich", selection: Binding(get: { region }, set: { region = $0; newExperiment() })) {
                        ForEach(Region.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    Button(action: run) {
                        Label(busy ? "Prüfung läuft" : "Jetzt prüfen", systemImage: "viewfinder")
                    }.disabled(experiment == nil || busy || loading).accessibilityIdentifier("run")
                    if let message { Text(message).foregroundStyle(.secondary).accessibilityIdentifier(latestCheckSucceeded ? "reading-ready" : "state-message") }
                }
                if !readings.isEmpty {
                    Section("Letzte Ergebnisse") {
                        ForEach(readings, id: \.readingId) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.outcome == "match" ? "Text erkannt" : "Kein Treffer erkannt")
                                    .font(.headline).accessibilityIdentifier("outcome")
                                Text("\(entry.source == "example" ? "Beispielbild" : "Ausgewähltes Bild") · \(Region(rawValue: entry.region)?.label ?? "")")
                                    .foregroundStyle(.secondary)
                                Button("Bericht ansehen") { report = entry.json }
                                    .buttonStyle(.borderless)
                                ShareLink("Ergebnis teilen", item: entry.json).buttonStyle(.borderless)
                            }.padding(.vertical, 3)
                        }
                    }
                }
            }
            .navigationTitle("Fieldglass")
            .toolbar { Button("Auftrag laden", systemImage: "square.and.arrow.down") { linkText = ""; importing = true } }
            .alert("Auftrag laden", isPresented: $importing) {
                TextField("fieldglass://…", text: $linkText).textInputAutocapitalization(.never)
                Button("Laden") { importText(linkText) }; Button("Abbrechen", role: .cancel) {}
            } message: { Text("Experiment-Link aus dem Plugin einfügen.") }
            .sheet(isPresented: Binding(get: { report != nil }, set: { if !$0 { report = nil } })) {
                NavigationStack {
                    ScrollView {
                        Text(report ?? "").font(.body.monospaced()).textSelection(.enabled)
                            .accessibilityIdentifier("receipt").padding()
                    }.navigationTitle("Ergebnisbericht")
                    .toolbar { Button("Fertig") { report = nil } }
                }
            }
            .sheet(item: $workspaceJob) { job in WorkspaceActions(job: job).id(job.id) }
            .onOpenURL { importText($0.absoluteString) }
            .task(id: selection) {
                guard let item = selection else { return }
                let revision = UUID(); sampleRevision = revision; loading = true; invalidate()
                defer { if sampleRevision == revision { loading = false } }
                do {
                    guard let image = try await item.loadTransferable(type: PickedImage.self) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    guard !Task.isCancelled, sampleRevision == revision else { return }
                    data = image.data; source = "selected-image"
                } catch {
                    if !Task.isCancelled && sampleRevision == revision { message = "Bild konnte nicht geladen werden. Die bisherige Bildquelle bleibt ausgewählt." }
                }
            }
        }.tint(Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .systemMint : UIColor(red: 0.0, green: 0.37, blue: 0.36, alpha: 1)
        }))
    }

    private func invalidate() { generation = UUID(); busy = false; latestCheckSucceeded = false; message = nil }
    private func newExperiment() { invalidate(); experimentID = UUID(); readings = [] }
    private func importText(_ text: String) {
        if let url = URL(string: text), let job = WorkspaceJob(link: url) {
            guard workspaceJob == nil else { return }
            report = nil; workspaceJob = job; return
        }
        guard let url = URL(string: text), let e = Experiment(link: url) else {
            latestCheckSucceeded = false; message = "Der Experiment-Link ist ungültig."; return
        }
        if experimentID == e.id && term == e.term && region == e.region { return }
        invalidate(); experimentID = e.id; term = e.term; region = e.region; readings = []
        message = "Auftrag geladen. Bild auswählen und Prüfung starten."
    }
    private func run() {
        editingTerm = false
        guard let experiment, !busy, !loading else { return }
        latestCheckSucceeded = false; busy = true; message = nil
        let token = UUID(); generation = token
        let bytes = data, kind = source
        Task {
            do {
                let match = try await Task.detached(priority: .userInitiated) {
                    try Reader.read(bytes, experiment: experiment)
                }.value
                guard generation == token else { return }
                let reading = Reading(experimentId: experiment.id, region: experiment.region.rawValue,
                                      source: kind, outcome: match ? "match" : "no-match")
                readings = Array(([reading] + readings).prefix(2))
                latestCheckSucceeded = true
                message = match ? "Suchtext erkannt." : "Im gewählten Bereich wurde kein Treffer erkannt."
            } catch {
                guard generation == token else { return }
                message = "Texterkennung fehlgeschlagen. Bitte Bild oder Bereich wechseln."
            }
            busy = false
        }
    }
}
