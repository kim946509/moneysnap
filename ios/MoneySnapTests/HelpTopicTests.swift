import Testing
@testable import MoneySnap

struct HelpTopicTests {
    @Test
    func guideCoversRecordShareGroupAndArchiveWithoutNotifications() {
        let titles = HelpTopic.allCases.map(\.title)
        let bodies = HelpTopic.allCases.map(\.body).joined()

        #expect(titles.contains("기록하기"))
        #expect(titles.contains("나만 보기와 공유"))
        #expect(titles.contains("그룹"))
        #expect(titles.contains("보관함"))
        #expect(bodies.contains("사진 없이"))
        #expect(bodies.contains("한 그룹"))
        #expect(!bodies.contains("알림"))
        #expect(!bodies.contains("정산"))
    }
}
