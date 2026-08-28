import Foundation

extension AppleNormalizedProposal {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(caseID, forKey: .caseID)
        try container.encode(proposalType, forKey: .proposalType)
        try container.encode(intent, forKey: .intent)
        if let tool {
            try container.encode(tool, forKey: .tool)
        } else {
            try container.encodeNil(forKey: .tool)
        }
        try container.encode(arguments, forKey: .arguments)
        try container.encode(missingArguments, forKey: .missingArguments)
        try container.encode(reasonCode, forKey: .reasonCode)
        try container.encode(repetitionDetected, forKey: .repetitionDetected)
        try container.encode(truncationDetected, forKey: .truncationDetected)
    }
}

extension AppleGenerationConfig {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(samplingMode, forKey: .samplingMode)
        try container.encode(samplingEnabled, forKey: .samplingEnabled)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(topP, forKey: .topP)
        try container.encodeNil(forKey: .topK)
        try container.encode(maximumResponseTokens, forKey: .maximumResponseTokens)
        try container.encode(seedSupported, forKey: .seedSupported)
        try container.encodeNil(forKey: .seed)
        try container.encode(includeSchemaInPrompt, forKey: .includeSchemaInPrompt)
        try container.encode(toolsCount, forKey: .toolsCount)
    }
}
