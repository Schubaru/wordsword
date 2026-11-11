import XCTest

/// Drives the real app end-to-end and drops a screenshot of every screen into SHOTS_DIR
/// (env var; defaults to /tmp/wordsword-shots). Doubles as the smoke test.
final class Screens: XCTestCase {
    var app: XCUIApplication!
    var dir: URL!

    override func setUp() {
        continueAfterFailure = false
        dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? "/tmp/wordsword-shots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        app = XCUIApplication()
    }

    func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: dir.appendingPathComponent(name + ".png"))
    }

    func testOnboarding() {
        app.launchArguments = ["-onboarded", "NO", "-username", "", "-contact", ""]
        app.launch()
        shot("01-onboarding-account")
        let contact = app.textFields["Email or phone"]
        contact.tap(); contact.typeText("alex@example.com")
        let user = app.textFields["Username"]
        user.tap(); user.typeText("alex")
        shot("02-onboarding-filled")
        app.buttons["Continue"].tap(); shot("03-how-1")
        app.buttons["Continue"].tap(); shot("04-how-2")
        app.buttons["Continue"].tap(); shot("05-how-3")
        app.buttons["Let's go"].tap()
        XCTAssertTrue(app.textFields["type a word"].waitForExistence(timeout: 5))
    }

    /// The landing-page reel (Scripts/demo-reel.swift): the define flow at watching pace. Run alone while `simctl io booted recordVideo` records; every tap's host time and
    /// point goes to SHOTS_DIR/taps.json so the touch dots can be drawn on afterwards.
    func testDemoReel() {
        app.launchArguments = ["-onboarded", "YES"]
        app.launch()
        var taps: [[String: Double]] = []
        func tap(_ e: XCUIElement) {
            let f = e.frame
            taps.append(["t": Date().timeIntervalSince1970, "x": f.midX, "y": f.midY])
            e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()   // keys fail the AX scroll-to-visible a plain tap() does first
        }
        defer { try? JSONSerialization.data(withJSONObject: taps).write(to: dir.appendingPathComponent("taps.json")) }
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); sleep(2)
        usleep(300_000)                                 // Home opens focused; a tap on the field only pops AutoFill
        for c in ProcessInfo.processInfo.environment["REEL_WORD"] ?? "ephemeral" { field.typeText(String(c)); usleep(120_000) }   // the sim's hardware keyboard: no key taps to show
        usleep(400_000); field.typeText("\n")
        XCTAssertTrue(app.staticTexts["adjective"].waitForExistence(timeout: 20)); sleep(2)
        tap(app.buttons["More synonyms"]); sleep(3)   // no model needed, so the take never waits on the sim's
        tap(app.buttons["Add to wordlist"]); sleep(1)
        let row = app.staticTexts["Book club"]
        if !row.exists {                          // a fresh sim has none: make it (cut from the reel), untick it
            let name = app.textFields["New wordlist"]
            name.tap(); name.typeText("Book club\n"); sleep(1); row.tap(); sleep(1)
        }
        tap(row); sleep(2)
        row.tap(); sleep(1)                        // untick it again so the next run starts the same
        app.buttons["Done"].tap()
    }

    func testDefineFlow() {
        app.launchArguments = ["-onboarded", "YES"]
        app.launch()
        shot("10-home")
        let field = app.textFields["type a word"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("sanguine\n")
        XCTAssertTrue(app.staticTexts["adjective"].waitForExistence(timeout: 20), "definition should arrive")
        sleep(1); shot("11-define")
        app.buttons["Use it in a sentence"].tap(); sleep(2); shot("12-sentence")
        app.buttons["Explain it differently"].tap(); sleep(2); shot("13-explain")
        // tap the first synonym chip → chain
        let syn = app.buttons.matching(NSPredicate(format: "label == 'optimistic' OR label == 'hopeful' OR label == 'confident' OR label == 'positive'")).firstMatch
        if syn.waitForExistence(timeout: 3) {
            syn.tap()
            _ = app.buttons["Save chain"].waitForExistence(timeout: 20)
            sleep(1); shot("14-chain")
            app.buttons["Save chain"].tap()
        }
        app.buttons["More synonyms"].tap(); sleep(3); shot("15-more-synonyms")
        app.buttons["Add to a wordlist"].tap(); sleep(1); shot("16-add-to-wordlist")
        let newList = app.textFields["New wordlist"]
        newList.tap(); newList.typeText("Book club\n"); sleep(1); shot("17-wordlist-created")
        app.buttons["Done"].tap()
        app.buttons["Back"].tap()
        sleep(1); shot("18-home-history")
        // misspelling
        field.tap(); field.typeText("ubiquitious\n")
        XCTAssertTrue(app.staticTexts["Not sure about that one. Did you mean:"].waitForExistence(timeout: 20))
        sleep(1); shot("19-did-you-mean")
        app.buttons["ubiquitous"].tap()
        XCTAssertTrue(app.staticTexts["adjective"].waitForExistence(timeout: 20))
        sleep(1); shot("20-did-you-mean-resolved")
        app.buttons["Back"].tap()
        // library + flashcards
        app.buttons["Library"].tap(); sleep(1); shot("21-library")
        app.buttons["Flashcards"].tap(); sleep(1); shot("22-flashcard-front")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Tap to reveal'")).firstMatch.tap(); sleep(1); shot("23-flashcard-back")
        app.buttons["Got it"].tap(); sleep(1); shot("24-flashcard-next")
        app.buttons["Back"].tap()
        app.buttons["Back"].tap()
        app.buttons["Settings"].tap(); sleep(1); shot("25-settings")
    }
}
