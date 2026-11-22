import XCTest

// This XCTest entry point also serves as the optional Mac simulator adapter.
final class WorkbenchDriver: XCTestCase {
    func testCommand() throws {
        let env = ProcessInfo.processInfo.environment
        guard let encoded = env["FIELDGLASS_COMMAND"], let bytes = Data(base64Encoded: encoded),
              let bundle = env["FIELDGLASS_BUNDLE"] else { throw XCTSkip("Opt-in simulator adapter") }
        #if targetEnvironment(simulator)
        continueAfterFailure = false
        let commands = try JSONDecoder().decode([Command].self, from: bytes)
        guard (1...8).contains(commands.count) else { XCTFail("Invalid count"); return }
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.activate()
        var steps = [[String: Any]]()
        for command in commands {
            let result = perform(command, app)
            steps.append(result)
            if ["target-unavailable","target-not-editable","invalid-command"].contains(result["status"] as? String ?? "") { break }
        }
        attach(["steps":steps])
        #else
        throw XCTSkip("Simulator adapter requires a simulator")
        #endif
    }
    private func perform(_ command: Command, _ app: XCUIApplication) -> [String: Any] {
        var result: [String: Any] = ["status": "submitted"]
        switch command.action {
        case "inspect":
            let items = app.descendants(matching: .any).allElementsBoundByIndex.prefix(180)
            let identifiers = Array(Set(items.map(\.identifier).filter { !$0.isEmpty && $0.utf8.count <= 120 })).sorted()
            result = ["status":"observed","identifiers":identifiers,"inspected":items.count]
        case "wait-for":
            guard let id = command.identifier,
                  app.descendants(matching: .any).matching(identifier: id).firstMatch.waitForExistence(timeout: 6)
            else { return ["status":"target-unavailable"] }
            result = ["status":"present"]
        case "swipe":
            switch command.direction {
            case "up": app.swipeUp()
            case "down": app.swipeDown()
            case "left": app.swipeLeft()
            case "right": app.swipeRight()
            default: return ["status":"invalid-command"]
            }
        case "drag":
            guard let from = point(command.x,command.y,in: app),
                  let to = point(command.toX,command.toY,in: app) else { return ["status":"invalid-command"] }
            from.press(forDuration: 0.2, thenDragTo: to)
        case "tap", "double-tap", "hold", "type":
            if let identifier = command.identifier {
                let query = app.descendants(matching: .any).matching(identifier: identifier)
                guard query.count == 1, query.element.isHittable else {
                    return ["status":"target-unavailable"]
                }
                let target = query.element
                switch command.action {
                case "type":
                    guard [.textField,.textView,.searchField].contains(target.elementType), let text = command.text else {
                        return ["status":"target-not-editable"]
                    }
                    target.tap(); target.typeText(text)
                case "hold": target.press(forDuration: 0.8)
                case "double-tap": target.doubleTap()
                default: target.tap()
                }
            } else if let at = point(command.x,command.y,in: app) {
                switch command.action {
                case "tap": at.tap()
                case "double-tap": at.doubleTap()
                case "hold": at.press(forDuration: 0.8)
                default: return ["status":"invalid-command"]
                }
            } else { return ["status":"invalid-command"] }
        default: return ["status":"invalid-command"]
        }
        return result
    }
    private func point(_ x: Double?, _ y: Double?, in app: XCUIApplication) -> XCUICoordinate? {
        guard let x, let y, (0...1).contains(x), (0...1).contains(y) else { return nil }
        return app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }
    private func attach(_ report: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: report) else { XCTFail("Invalid report"); return }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "fieldglass-command.json"; attachment.lifetime = .keepAlways; add(attachment)
    }
    private struct Command: Decodable {
        let action: String
        let identifier, text, direction: String?
        let x, y, toX, toY: Double?
    }
}
