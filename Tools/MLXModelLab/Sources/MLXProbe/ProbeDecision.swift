import Foundation

enum ProbeDecision {
    /// Allow JSON whitespace only between tokens, not inside quoted strings.
    /// The fixed grammar has exactly five tokens; reject any additional text.
    static func matches(_ reply: String, expected: String) -> Bool {
        guard ["status.read", "model.readiness", "capabilities.read", "finish"].contains(expected), reply.utf8.count <= 256 else { return false }
        let bytes = Array(reply.utf8)
        let tokens = ["{", "\"action\"", ":", "\"\(expected)\"", "}"]
        var cursor = 0
        func skipWhitespace() {
            while cursor < bytes.count && [UInt8(9),10,13,32].contains(bytes[cursor]) { cursor += 1 }
        }
        for token in tokens {
            skipWhitespace()
            let expectedBytes = Array(token.utf8)
            guard bytes.count - cursor >= expectedBytes.count,
                  bytes[cursor..<(cursor + expectedBytes.count)].elementsEqual(expectedBytes) else { return false }
            cursor += expectedBytes.count
        }
        skipWhitespace()
        return cursor == bytes.count
    }
}
