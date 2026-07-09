import Foundation

enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case home, calendar, files, lists
    var id: String { rawValue }
}

/// Everything presented as a `.sheet` from anywhere in the app funnels
/// through one enum so only one sheet can ever be up at a time — matching
/// the prototype's single `modal` state slot in `AppShell`.
enum SheetRoute: Identifiable {
    case addTask(listId: String?, sectionId: String?, presetDeadline: String?)
    case editTask(AppTask)
    case addChoice
    case templates
    case addList(folderId: String?)
    case addFolder
    case settings
    case trash
    case meeting(existing: AppMeeting?, presetDate: String?)
    case dayAdd(date: String)
    case milestoneEditor(timelineId: String, existing: AppMilestone?)
    case addTimeline
    case workspaceSwitcher
    case workspaceWizard
    case twoFASetup
    case aiChat
    case filePreview(AppFileItem)

    var id: String {
        switch self {
        case .addTask: return "addTask"
        case .editTask(let t): return "editTask-\(t.id)"
        case .addChoice: return "addChoice"
        case .templates: return "templates"
        case .addList: return "addList"
        case .addFolder: return "addFolder"
        case .settings: return "settings"
        case .trash: return "trash"
        case .meeting(let m, _): return "meeting-\(m?.id ?? "new")"
        case .dayAdd(let d): return "dayAdd-\(d)"
        case .milestoneEditor(let tid, let m): return "milestone-\(tid)-\(m?.id ?? "new")"
        case .addTimeline: return "addTimeline"
        case .workspaceSwitcher: return "workspaceSwitcher"
        case .workspaceWizard: return "workspaceWizard"
        case .twoFASetup: return "twoFASetup"
        case .aiChat: return "aiChat"
        case .filePreview(let f): return "filePreview-\(f.id)"
        }
    }
}

enum ListsRoute: Hashable {
    case list(id: String)
    case folder(id: String)
    case timelines
    case timeline(id: String)
}

@MainActor
final class Router: ObservableObject {
    @Published var tab: MainTab = .home
    @Published var sheet: SheetRoute?
    @Published var listsPath: [ListsRoute] = []
}
