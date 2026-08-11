import XCTest

final class BabyCareTests: XCTestCase {
    func testBabyAgeCalculation() {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let baby = Baby(name: "Test", nickname: "Test", birthday: threeMonthsAgo, gender: .male)
        XCTAssertEqual(baby.ageInMonths, 3)
    }

    func testEventShortDescription() {
        let baby = Baby.preview
        let event = BabyEvent(
            babyId: baby.id,
            label: .feeding,
            startTime: Date(),
            payload: .feeding(FeedingPayload(method: .breastfeeding, amountMl: 120))
        )
        XCTAssertTrue(event.shortDescription.contains("母乳"))
        XCTAssertTrue(event.shortDescription.contains("120"))
    }
}
