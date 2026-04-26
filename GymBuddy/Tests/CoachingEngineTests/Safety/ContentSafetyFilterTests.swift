import XCTest
@testable import CoachingEngine

final class ContentSafetyFilterTests: XCTestCase {
    let filter = ContentSafetyFilter()

    func testSubstitutesDiagnosis() {
        let result = filter.inspect("It sounds like a tear in your rotator cuff.")
        guard case .substituteResponse(let cat, let id) = result.action else {
            return XCTFail("Expected substitution, got \(result.action)")
        }
        XCTAssertEqual(cat, .diagnosis)
        XCTAssertEqual(id, "safety.diagnosis.deflect")
    }

    func testSubstitutesUnsafeCalorieTarget() {
        let result = filter.inspect("You should eat 1200 calories per day to cut.")
        if case .substituteResponse(let cat, _) = result.action {
            XCTAssertEqual(cat, .unsafeNutrition)
        } else {
            XCTFail("Expected nutrition substitution")
        }
    }

    func testSubstitutesShame() {
        let result = filter.inspect("That's pathetic — only three reps?")
        if case .substituteResponse(let cat, _) = result.action {
            XCTAssertEqual(cat, .shame)
        } else {
            XCTFail("Expected shame substitution")
        }
    }

    func testSubstitutesPushThroughPain() {
        let result = filter.inspect("Push through the pain — you can do it.")
        if case .substituteResponse(let cat, _) = result.action {
            XCTAssertEqual(cat, .pushThroughPain)
        } else {
            XCTFail("Expected push-through substitution")
        }
    }

    func testAllowsNormalCoachingLanguage() {
        let result = filter.inspect("Solid set. Keep your back flat next time — three more sets to go.")
        if case .proceed = result.action {
            // ok
        } else {
            XCTFail("Normal coaching should pass through")
        }
    }

    func testDoesNotFireOnColloquialDying() {
        let result = filter.inspect("That was hard — I'm dying.")
        if case .proceed = result.action {
            // ok
        } else {
            XCTFail("Colloquial 'dying' must not trigger safety filter")
        }
    }
}
