import SwiftUI

/// Hosts the four main screens behind the floating glass tab bar, and is the
/// single place that presents every sheet in the app (`Router.sheet`) so
/// only one can ever be open at once — mirroring the prototype's `AppShell`.
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch router.tab {
                case .home: DashboardView()
                case .calendar: CalendarView()
                case .files: FilesView()
                case .lists: ListsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            GlassTabBar(selected: $router.tab, connected: appState.mode == .server) {
                router.sheet = .aiChat
            }
        }
        .background(SCColor.page.ignoresSafeArea())
        .sheet(item: $router.sheet) { route in
            sheetContent(for: route)
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func sheetContent(for route: SheetRoute) -> some View {
        switch route {
        case .addTask(let listId, let sectionId, let presetDeadline):
            EditTaskSheet(mode: .create(listId: listId, sectionId: sectionId, presetDeadline: presetDeadline))
        case .editTask(let task):
            EditTaskSheet(mode: .edit(task))
        case .addChoice:
            AddChoiceSheet()
        case .templates:
            TemplatesSheet()
        case .addList(let folderId):
            AddListSheet(folderId: folderId)
        case .addFolder:
            AddFolderSheet()
        case .settings:
            SettingsView()
        case .trash:
            TrashSheet()
        case .meeting(let existing, let presetDate):
            MeetingSheet(existing: existing, presetDate: presetDate)
        case .dayAdd(let date):
            DayAddChooserSheet(date: date)
        case .milestoneEditor(let timelineId, let existing):
            MilestoneEditorSheet(timelineId: timelineId, existing: existing)
        case .addTimeline:
            AddTimelineSheet()
        case .workspaceSwitcher:
            WorkspaceSwitcherSheet()
        case .workspaceWizard:
            WorkspaceWizardSheet()
        case .twoFASetup:
            TwoFASheet()
        case .aiChat:
            AIAssistantSheet()
        case .filePreview(let file):
            FilePreviewSheet(file: file)
        }
    }
}

/// Small reusable top-right avatar button used in each main screen's
/// toolbar to open Settings — mirrors the prototype's persistent `ProfileBtn`.
struct ProfileToolbarButton: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: Router

    var body: some View {
        Button { router.sheet = .settings } label: {
            ProfileAvatarView(base64DataURL: storedAvatar, initials: initials, size: 30, fontSize: 11)
        }
    }

    private var initials: String {
        let name = appState.mode == .server ? (appState.currentUser?.fullName ?? appState.currentUser?.username ?? "U") : appState.localUsername
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private var storedAvatar: String? {
        appState.mode == .server ? appState.currentUser?.profileImageBase64 : appState.localProfileImageBase64
    }
}
