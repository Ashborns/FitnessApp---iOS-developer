// Agent 4 owns this file
// XCUITest — onboarding happy path (welcome → auth → profile → login)

import XCTest

final class OnboardingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Tests

    /// Verify the welcome screen is displayed on launch with the correct accessibility identifier.
    func testOnboardingWelcomeScreenExists() {
        let welcomeScreen = app.otherElements["onboarding-welcome"]
        XCTAssertTrue(
            welcomeScreen.waitForExistence(timeout: 5),
            "Expected onboarding welcome screen to exist on launch"
        )
    }

    /// Swipe through all 3 onboarding screens and verify each identifier appears.
    func testOnboardingNavigationFlow() {
        let welcomeScreen = app.otherElements["onboarding-welcome"]
        XCTAssertTrue(
            welcomeScreen.waitForExistence(timeout: 5),
            "Expected onboarding welcome screen to exist"
        )

        // Swipe left to navigate to auth screen
        app.swipeLeft()

        let authScreen = app.otherElements["onboarding-auth"]
        XCTAssertTrue(
            authScreen.waitForExistence(timeout: 3),
            "Expected onboarding auth screen after first swipe"
        )

        // Swipe left to navigate to profile screen
        app.swipeLeft()

        let profileScreen = app.otherElements["onboarding-profile"]
        XCTAssertTrue(
            profileScreen.waitForExistence(timeout: 3),
            "Expected onboarding profile screen after second swipe"
        )
    }

    /// Tap the skip button and verify the login screen appears.
    func testSkipButtonNavigatesToLogin() {
        let welcomeScreen = app.otherElements["onboarding-welcome"]
        XCTAssertTrue(
            welcomeScreen.waitForExistence(timeout: 5),
            "Expected onboarding welcome screen to exist"
        )

        let skipButton = app.buttons["onboarding-skip-btn"]
        XCTAssertTrue(
            skipButton.waitForExistence(timeout: 3),
            "Expected skip button to exist on onboarding screen"
        )
        skipButton.tap()

        let emailField = app.textFields["login-email-field"]
        XCTAssertTrue(
            emailField.waitForExistence(timeout: 5),
            "Expected login email field to appear after tapping skip"
        )
    }

    /// Navigate to the last screen, tap "Get Started", and verify login appears.
    func testGetStartedNavigatesToLogin() {
        let welcomeScreen = app.otherElements["onboarding-welcome"]
        XCTAssertTrue(
            welcomeScreen.waitForExistence(timeout: 5),
            "Expected onboarding welcome screen to exist"
        )

        // Navigate to the last screen (profile) using swipes
        app.swipeLeft()
        let authScreen = app.otherElements["onboarding-auth"]
        XCTAssertTrue(
            authScreen.waitForExistence(timeout: 3),
            "Expected onboarding auth screen"
        )

        app.swipeLeft()
        let profileScreen = app.otherElements["onboarding-profile"]
        XCTAssertTrue(
            profileScreen.waitForExistence(timeout: 3),
            "Expected onboarding profile screen"
        )

        // Tap "Get Started" button on the last screen
        let getStartedButton = app.buttons["onboarding-get-started-btn"]
        XCTAssertTrue(
            getStartedButton.waitForExistence(timeout: 3),
            "Expected 'Get Started' button on the last onboarding screen"
        )
        getStartedButton.tap()

        // Verify login screen appears
        let emailField = app.textFields["login-email-field"]
        XCTAssertTrue(
            emailField.waitForExistence(timeout: 5),
            "Expected login email field to appear after tapping Get Started"
        )
    }
}
