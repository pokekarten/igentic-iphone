import Foundation
import ModelResearchSupport

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@main
struct AppleFoundationBaselineHost {
    static func main() async {
        do {
            let arguments = try Arguments.parse(Array(CommandLine.arguments.dropFirst()))
            try await AppleFoundationBaselineRunner().run(
                benchmarkURL: arguments.benchmarkURL,
                profile: arguments.profile,
                outputDirectory: arguments.outputDirectory
            )
            print("Apple Foundation Models Benchmark V0 host evidence written for \(arguments.profile.rawValue).")
        } catch let error as AppleFoundationBaselineError {
            writeError("apple-foundation-baseline: \(error.description)")
            exit(EXIT_FAILURE)
        } catch let error as ArgumentError {
            writeError("apple-foundation-baseline: \(error.description)")
            exit(EXIT_FAILURE)
        } catch {
            writeError("apple-foundation-baseline: execution failed")
            exit(EXIT_FAILURE)
        }
    }

    private static func writeError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private struct Arguments {
    let benchmarkURL: URL
    let profile: AppleBaselineProfile
    let outputDirectory: URL

    static func parse(_ arguments: [String]) throws -> Arguments {
        var benchmarkPath: String?
        var profileValue: String?
        var outputPath: String?
        var index = 0

        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else {
                throw ArgumentError.missingValue(flag)
            }
            let value = arguments[index + 1]
            switch flag {
            case "--benchmark":
                guard benchmarkPath == nil else { throw ArgumentError.duplicateFlag(flag) }
                benchmarkPath = value
            case "--profile":
                guard profileValue == nil else { throw ArgumentError.duplicateFlag(flag) }
                profileValue = value
            case "--output-dir":
                guard outputPath == nil else { throw ArgumentError.duplicateFlag(flag) }
                outputPath = value
            default:
                throw ArgumentError.unknownFlag(flag)
            }
            index += 2
        }

        guard let benchmarkPath else { throw ArgumentError.missingFlag("--benchmark") }
        guard let profileValue else { throw ArgumentError.missingFlag("--profile") }
        guard let outputPath else { throw ArgumentError.missingFlag("--output-dir") }
        guard let profile = AppleBaselineProfile(rawValue: profileValue) else {
            throw ArgumentError.invalidProfile
        }

        return Arguments(
            benchmarkURL: URL(fileURLWithPath: benchmarkPath).standardizedFileURL,
            profile: profile,
            outputDirectory: URL(fileURLWithPath: outputPath).standardizedFileURL
        )
    }
}

private enum ArgumentError: Error, CustomStringConvertible {
    case missingFlag(String)
    case missingValue(String)
    case duplicateFlag(String)
    case unknownFlag(String)
    case invalidProfile

    var description: String {
        switch self {
        case .missingFlag(let flag):
            return "missing required flag \(flag)"
        case .missingValue(let flag):
            return "missing value for \(flag)"
        case .duplicateFlag(let flag):
            return "duplicate flag \(flag)"
        case .unknownFlag(let flag):
            return "unknown flag \(flag)"
        case .invalidProfile:
            return "profile must be Router-small or Router-normal"
        }
    }
}
