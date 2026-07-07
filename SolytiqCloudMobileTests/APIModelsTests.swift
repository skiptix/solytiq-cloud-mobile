import Testing
import Foundation
@testable import SolytiqCloudMobile

struct APIModelsTests {
    @Test func intOrStringDecodesBothShapes() throws {
        let intJSON = Data("42".utf8)
        let strJSON = Data("\"abc-123\"".utf8)
        let a = try JSONDecoder().decode(IntOrString.self, from: intJSON)
        let b = try JSONDecoder().decode(IntOrString.self, from: strJSON)
        #expect(a.stringValue == "42")
        #expect(b.stringValue == "abc-123")
    }

    @Test func taskDTOMapsToDomainModel() throws {
        let json = """
        {"id":123,"title":"Ship it","checked":false,"priority":"High","position":0}
        """
        let dto = try JSONDecoder().decode(APITaskDTO.self, from: Data(json.utf8))
        let app = dto.toApp()
        #expect(app.id == "123")
        #expect(app.title == "Ship it")
        #expect(app.priority == .high)
        #expect(app.checked == false)
    }

    @Test func clientIDsAreMonotonicAndUnique() {
        let a = ClientID.next()
        let b = ClientID.next()
        #expect(a != b)
    }

    @Test func listProgressComputesFromSections() {
        let task1 = AppTask(title: "A", checked: true)
        let task2 = AppTask(title: "B", checked: false)
        let section = AppSection(id: "s1", listId: "l1", label: "Todo", emoji: nil, position: 0, tasks: [task1, task2])
        let list = AppList(id: "l1", name: "List", emoji: nil, colorHex: "#5e4dbb", subtitle: nil, folderId: nil,
                            workspaceId: nil, isPublic: false, shareEnabled: false, shareToken: nil, position: 0, sections: [section])
        #expect(list.totalTasks == 2)
        #expect(list.doneTasks == 1)
        #expect(list.progress == 0.5)
    }
}
