import Foundation
import SwiftData

// MARK: - Meetings

extension DataStore {
    func meetings() async -> [AppMeeting] {
        if isServer { return (try? await meetingsAPI.list()) ?? [] }
        return fetchAll(PMeeting.self).map { $0.toApp() }
    }

    @discardableResult
    func createMeeting(_ m: AppMeeting) async -> AppMeeting? {
        if isServer { return try? await meetingsAPI.create(m) }
        let p = PMeeting(title: m.title, date: m.date, allDay: m.allDay, startTime: m.startTime,
                          endTime: m.endTime, location: m.location, note: m.description, colorHex: m.colorHex)
        modelContext.insert(p); save()
        return p.toApp()
    }

    func updateMeeting(_ m: AppMeeting) async {
        if isServer { _ = try? await meetingsAPI.update(id: m.id, m); return }
        guard let p = fetchAll(PMeeting.self).first(where: { $0.id == m.id }) else { return }
        p.title = m.title; p.date = m.date; p.allDay = m.allDay; p.startTime = m.startTime
        p.endTime = m.endTime; p.location = m.location; p.note = m.description; p.colorHex = m.colorHex
        save()
    }

    func deleteMeeting(id: String) async {
        if isServer { try? await meetingsAPI.delete(id: id); return }
        guard let p = fetchAll(PMeeting.self).first(where: { $0.id == id }) else { return }
        modelContext.delete(p); save()
    }
}

// MARK: - Timelines & milestones

extension DataStore {
    func timelines() async -> [AppTimeline] {
        if isServer { return (try? await timelinesAPI.list(workspaceId: appState.currentWorkspaceId)) ?? [] }
        return fetchAll(PTimeline.self).filter { !$0.isTrashed }.map { $0.toApp() }
    }

    @discardableResult
    func createTimeline(name: String, emoji: String?, colorHex: String, subtitle: String?, folderId: String?) async -> AppTimeline? {
        if isServer {
            return try? await timelinesAPI.create(name: name, emoji: emoji, color: colorHex, subtitle: subtitle,
                                                    folderId: folderId, workspaceId: appState.currentWorkspaceId)
        }
        let p = PTimeline(name: name, emoji: emoji, subtitle: subtitle, colorHex: colorHex, folderId: folderId)
        modelContext.insert(p); save()
        return p.toApp()
    }

    func updateTimeline(_ t: AppTimeline) async {
        if isServer {
            _ = try? await timelinesAPI.update(id: t.id, .init(name: t.name, emoji: t.emoji, color: t.colorHex, subtitle: t.subtitle))
            return
        }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == t.id }) else { return }
        p.name = t.name; p.emoji = t.emoji; p.subtitle = t.subtitle; p.colorHex = t.colorHex
        save()
    }

    func deleteTimeline(id: String) async {
        if isServer { try? await timelinesAPI.delete(id: id); return }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == id }) else { return }
        p.isTrashed = true; p.trashedAt = .now
        save()
    }

    @discardableResult
    func addMilestone(timelineId: String, _ m: AppMilestone) async -> AppMilestone? {
        if isServer { return try? await timelinesAPI.addMilestone(timelineId: timelineId, m) }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == timelineId }) else { return nil }
        var stored = m
        stored.id = UUID().uuidString
        p.milestones.append(stored)
        save()
        return stored
    }

    func updateMilestone(timelineId: String, _ m: AppMilestone) async {
        if isServer { _ = try? await timelinesAPI.updateMilestone(id: m.id, m); return }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == timelineId }),
              let idx = p.milestones.firstIndex(where: { $0.id == m.id }) else { return }
        p.milestones[idx] = m
        save()
    }

    func deleteMilestone(timelineId: String, milestoneId: String) async {
        if isServer { try? await timelinesAPI.deleteMilestone(id: milestoneId); return }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == timelineId }) else { return }
        p.milestones.removeAll { $0.id == milestoneId }
        save()
    }
}
