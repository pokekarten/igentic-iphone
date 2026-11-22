import Foundation
import UIKit
import Vision
import ImageIO

enum Region: String, CaseIterable {
    case all, top, bottom
    var label: String { switch self { case .all: "Ganzes Bild"; case .top: "Oben"; case .bottom: "Unten" } }
}

struct Experiment {
    let id: UUID
    let term: String
    let region: Region

    init?(id: UUID = UUID(), term: String, region: Region) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 160,
              trimmed.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
        self.id = id; self.term = trimmed; self.region = region
    }

    init?(link: URL) {
        guard link.absoluteString.utf8.count <= 2048,
              let c = URLComponents(url: link, resolvingAgainstBaseURL: false),
              c.scheme == "fieldglass", c.host == "experiment", c.path == "/v1",
              c.user == nil, c.password == nil, c.port == nil, c.fragment == nil,
              let items = c.queryItems, items.count == 3 else { return nil }
        func field(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let id = UUID(uuidString: field("id") ?? ""), let term = field("term"),
              let region = Region(rawValue: field("region") ?? "") else { return nil }
        self.init(id: id, term: term, region: region)
    }
}

struct Reading: Encodable {
    let version = 1
    let experimentId: UUID
    let readingId = UUID()
    #if targetEnvironment(simulator)
    let runtime = "simulator"
    #else
    let runtime = "device"
    #endif
    let region: String
    let source: String
    let outcome: String

    var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? String(decoding: encoder.encode(self), as: UTF8.self)) ?? ""
    }
}

enum Reader {
    static func sample(alternate: Bool = false) -> Data {
        let size = CGSize(width: 800, height: 600)
        return UIGraphicsImageRenderer(size: size, format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f
        }()).pngData { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 64, weight: .medium), .foregroundColor: UIColor.black]
            ((alternate ? "NORD" : "ORBIT") as NSString).draw(at: CGPoint(x: 70, y: 85), withAttributes: attrs)
            ("HAFEN" as NSString).draw(at: CGPoint(x: 70, y: 420), withAttributes: attrs)
        }
    }

    static func read(_ data: Data, experiment: Experiment) throws -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let upright = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        var bounds = CGRect(x: 0, y: 0, width: upright.width, height: upright.height)
        if experiment.region != .all {
            let half = upright.height / 2
            if experiment.region == .bottom { bounds.origin.y = CGFloat(half) }
            bounds.size.height = CGFloat(experiment.region == .top ? half : upright.height - half)
        }
        guard let cropped = upright.cropping(to: bounds) else { throw CocoaError(.fileReadCorruptFile) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        try VNImageRequestHandler(cgImage: cropped).perform([request])
        return (request.results ?? []).contains {
            $0.topCandidates(1).first?.string.range(of: experiment.term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
