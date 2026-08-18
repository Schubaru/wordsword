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
        app.navigationBars.buttons.firstMatch.tap()   // back
        sleep(1); shot("18-home-history")
        // misspelling
        field.tap(); field.typeText("ubiquitious\n")
        XCTAssertTrue(app.staticTexts["Not sure about that one. Did you mean:"].waitForExistence(timeout: 20))
        sleep(1); shot("19-did-you-mean")
        app.buttons["ubiquitous"].tap()
        XCTAssertTrue(app.staticTexts["adjective"].waitForExistence(timeout: 20))
        sleep(1); shot("20-did-you-mean-resolved")
        app.navigationBars.buttons.firstMatch.tap()
        // library + flashcards
        app.buttons["Library"].tap(); sleep(1); shot("21-library")
        app.buttons["Flashcards"].tap(); sleep(1); shot("22-flashcard-front")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Tap to reveal'")).firstMatch.tap(); sleep(1); shot("23-flashcard-back")
        app.buttons["Got it"].tap(); sleep(1); shot("24-flashcard-next")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Settings"].tap(); sleep(1); shot("25-settings")
    }
}
