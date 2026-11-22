import AppIntents
import UniformTypeIdentifiers

@available(iOS 18.0, *)
struct CheckImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Bild für Fieldglass prüfen"
    static var description = IntentDescription("Prüft einen Experiment-Link mit dem übergebenen Bild und gibt den Ergebnisbericht zurück.")
    static var openAppWhenRun = false

    @Parameter(title: "Experiment-Link") var link: String
    @Parameter(title: "Bild", supportedContentTypes: [.image]) var image: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let url = URL(string: link), let experiment = Experiment(link: url) else {
            throw FieldglassInputError.invalidExperiment
        }
        let bytes = image.data
        guard bytes.count <= 24 * 1024 * 1024 else { throw FieldglassInputError.imageTooLarge }
        let found = try Reader.read(bytes, experiment: experiment)
        return .result(value: Reading(experimentId: experiment.id, region: experiment.region.rawValue,
                                      source: "selected-image", outcome: found ? "match" : "no-match").json)
    }
}

private enum FieldglassInputError: LocalizedError {
    case invalidExperiment, imageTooLarge
    var errorDescription: String? {
        switch self {
        case .invalidExperiment: "Bitte einen gültigen Fieldglass-Experiment-Link übergeben."
        case .imageTooLarge: "Bitte ein Bild mit höchstens 24 MiB auswählen."
        }
    }
}
