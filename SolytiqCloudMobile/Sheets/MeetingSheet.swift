import SwiftUI

struct MeetingSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var existing: AppMeeting?
    var presetDate: String?

    @State private var title: String
    @State private var date: Date
    @State private var allDay: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var location: String
    @State private var notes: String
    @State private var colorHex: String
    @State private var confirmDelete = false
    // §2.1 recurrence (new meetings only) · §2.2 attendees
    @State private var repeatFreq: MeetingRecurrence.Freq?
    @State private var repeatCount: Int = 4
    @State private var members: [AuthAPI.MemberBasic] = []
    @State private var selectedInvitees: Set<String> = []
    @State private var confirmLeave = false

    static let colors = ["#5e4dbb", "#3b82f6", "#0ea5e9", "#10b981", "#f59e0b", "#ef4444", "#ec4899", "#8b5cf6"]

    init(existing: AppMeeting?, presetDate: String?) {
        self.existing = existing
        self.presetDate = presetDate
        _title = State(initialValue: existing?.title ?? "")
        _date = State(initialValue: SCDate.date(fromISO: existing?.date ?? presetDate ?? SCDate.todayISO()) ?? .now)
        _allDay = State(initialValue: existing?.allDay ?? false)
        _startTime = State(initialValue: Self.time(from: existing?.startTime) ?? .now)
        _endTime = State(initialValue: Self.time(from: existing?.endTime) ?? .now)
        _location = State(initialValue: existing?.location ?? "")
        _notes = State(initialValue: existing?.description ?? "")
        _colorHex = State(initialValue: existing?.colorHex ?? "#3b82f6")
    }

    private static func time(from s: String?) -> Date? {
        guard let s else { return nil }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.date(from: s)
    }
    private static func string(from d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    /// True when viewing a meeting someone else organized (we were invited) —
    /// render read-only with a "Leave" action instead of an editable form.
    private var isInvitedOnly: Bool {
        guard let existing, let organizer = existing.organizerId, let me = appState.currentUser?.id else { return false }
        return organizer != me
    }

    var body: some View {
        NavigationStack {
            Group {
                if isInvitedOnly {
                    invitedDetail
                } else {
                    editableForm
                }
            }
            .navigationTitle(existing == nil ? "New Meeting" : (isInvitedOnly ? "Meeting" : "Edit Meeting"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(isInvitedOnly ? "Close" : "Cancel") { dismiss() } }
                if !isInvitedOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }.disabled(!canSave)
                    }
                }
            }
            .confirmDelete(isPresented: $confirmDelete, title: "Delete Meeting?", message: "\"\(existing?.title ?? "")\" will be removed.") {
                Task {
                    if let existing { await store.deleteMeeting(id: existing.id) }
                    dismiss()
                }
            }
            .confirmDelete(isPresented: $confirmLeave, title: "Leave Meeting?",
                           message: "You'll be removed from \"\(existing?.title ?? "")\" and it will disappear from your calendar.",
                           confirmLabel: "Leave") {
                Task {
                    if let existing { await store.leaveMeeting(id: existing.id) }
                    dismiss()
                }
            }
            .task {
                if existing == nil, store.isServer { members = (try? await AuthAPI().members()) ?? [] }
            }
        }
    }

    private var editableForm: some View {
        Form {
            Section {
                TextField("Meeting title", text: $title).font(.system(size: 17, weight: .semibold))
            }
            Section {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Toggle("All-day", isOn: $allDay)
                if !allDay {
                    DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                }
            }
            Section {
                TextField("Add a location", text: $location)
            }
            // §2.1 Repeat — new meetings only (a series is created server-side).
            if existing == nil, store.isServer {
                Section("Repeat") {
                    Picker("Repeat", selection: $repeatFreq) {
                        Text("None").tag(MeetingRecurrence.Freq?.none)
                        ForEach(MeetingRecurrence.Freq.allCases) { f in
                            Text(f.label).tag(MeetingRecurrence.Freq?.some(f))
                        }
                    }
                    if repeatFreq != nil {
                        Stepper("Occurrences: \(repeatCount)", value: $repeatCount, in: 2...104)
                    }
                }
                // §2.2 Attendees — invite other instance users to the new meeting.
                if !members.isEmpty {
                    Section("Invite") {
                        ForEach(members) { member in
                            Button {
                                if selectedInvitees.contains(member.username) { selectedInvitees.remove(member.username) }
                                else { selectedInvitees.insert(member.username) }
                            } label: {
                                HStack {
                                    Text(member.fullName ?? member.username).foregroundStyle(SCColor.text)
                                    Spacer()
                                    if selectedInvitees.contains(member.username) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(SCColor.primary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Section("Color") {
                HStack(spacing: 10) {
                    ForEach(Self.colors, id: \.self) { hex in
                        Circle().fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2 : 0))
                            .onTapGesture { colorHex = hex }
                    }
                }
            }
            Section("Notes") {
                TextEditor(text: $notes).frame(minHeight: 70)
            }
            // Show the series/attendees on an existing meeting you organize.
            if let existing, existing.recurrenceId != nil {
                Section { Label("Part of a repeating series", systemImage: "repeat").font(.system(size: 13)).foregroundStyle(SCColor.text3) }
            }
            if let existing, !existing.attendees.isEmpty {
                Section("Attendees") {
                    ForEach(existing.attendees) { a in
                        Text(a.fullName ?? a.username).font(.system(size: 14))
                    }
                }
            }
            if existing != nil {
                Section {
                    Button("Delete Meeting", role: .destructive) { confirmDelete = true }
                }
            }
        }
    }

    /// §2.2 — read-only view for a meeting you were invited to (not organizing).
    private var invitedDetail: some View {
        Form {
            Section {
                Text(title).font(.system(size: 18, weight: .bold))
                LabeledContent("Date", value: existing?.date ?? "")
                if !(existing?.allDay ?? true) {
                    LabeledContent("Time", value: "\(SCDate.to12h(existing?.startTime)) – \(SCDate.to12h(existing?.endTime))")
                }
                if let location = existing?.location, !location.isEmpty {
                    LabeledContent("Location", value: location)
                }
            }
            if let notes = existing?.description, !notes.isEmpty {
                Section("Notes") { Text(notes).font(.system(size: 14)) }
            }
            if let attendees = existing?.attendees, !attendees.isEmpty {
                Section("Attendees") {
                    ForEach(attendees) { a in Text(a.fullName ?? a.username).font(.system(size: 14)) }
                }
            }
            Section {
                Button("Leave Meeting", role: .destructive) { confirmLeave = true }
            }
        }
    }

    private func save() async {
        let meeting = AppMeeting(id: existing?.id ?? UUID().uuidString, title: title, date: SCDate.iso(date), allDay: allDay,
                                  startTime: allDay ? nil : Self.string(from: startTime), endTime: allDay ? nil : Self.string(from: endTime),
                                  location: location.isEmpty ? nil : location, description: notes.isEmpty ? nil : notes,
                                  colorHex: colorHex, workspaceId: nil)
        if existing != nil {
            await store.updateMeeting(meeting)
        } else {
            let recurrence = repeatFreq.map { MeetingRecurrence(freq: $0, interval: 1, count: repeatCount) }
            await store.createMeeting(meeting, recurrence: recurrence, inviteeUsernames: Array(selectedInvitees))
        }
        dismiss()
    }
}

struct DayAddChooserSheet: View {
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    var date: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text(friendlyDate).font(.system(size: 13)).foregroundStyle(SCColor.text3).padding(.top, 4)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        router.sheet = .addTask(listId: nil, sectionId: nil, presetDeadline: date)
                    }
                } label: { optionRow(icon: "checkmark.circle", color: SCColor.primary, title: "Task", subtitle: "A to-do with a deadline") }

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        router.sheet = .meeting(existing: nil, presetDate: date)
                    }
                } label: { optionRow(icon: "calendar.badge.clock", color: Color(hex: "#3b82f6"), title: "Meeting", subtitle: "A standalone calendar event") }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Add to calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(280)])
    }

    private var friendlyDate: String {
        guard let d = SCDate.date(fromISO: date) else { return date }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: d)
    }

    private func optionRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.12))
                Image(systemName: icon).foregroundStyle(color)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(SCColor.text)
                Text(subtitle).font(.system(size: 12.5)).foregroundStyle(SCColor.text3)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(SCColor.text4)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 1.5))
        .contentShape(Rectangle())
    }
}
