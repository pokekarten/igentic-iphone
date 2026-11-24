import Foundation
import AgentCore

// Content-free, deliberately closed bridge. Never accepts a caller's risk,
// classification, approval flag, arbitrary command, or proposed permission.
let operation = CommandLine.arguments.dropFirst().first ?? ""
let risk: ActionRisk
switch operation {
case "device-status", "observe-diagnostics": risk = .read
case "open-diagnostics", "open-discovery": risk = .prepare
default:
    print("{\"allowed\":false,\"reason\":\"unsupportedOperation\",\"auditEvents\":0}")
    exit(0)
}
let decision = PolicyEngine().decide(PolicyRequest(
    privacyMode: .localOnly,
    dataClassification: .publicDefault,
    actionRisk: risk,
    requestedDelegationTarget: .localDevice
))
let audit = AuditLog()
audit.record(AuditEvent(type: .policyDecision, message: decision.reasonCode.rawValue,
                       dataSensitivity: .publicData))
let allowed = decision.isAllowed && !decision.requiresApproval
let object: [String: Any] = ["allowed": allowed, "reason": decision.reasonCode.rawValue,
                           "auditEvents": audit.allEvents().count]
let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
