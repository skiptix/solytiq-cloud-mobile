import Foundation
import SwiftData

// MARK: - Meetings
//
// Meetings aren't part of the sync engine's core cache (they're a
// signal-entity — `meeting` bumps `sync.entityRevisions` and the Calendar
// screen refetches), so server mode always reads them via REST.

extension DataStore {
    func meetings() async -> [AppMeeting] {
        if isServer { return (try? await meetingsAPI.list()) ?? [] }
        return fetchAll(PMeeting.self).map { $0.toApp() }
    }

    @discardableResult
    func createMeeting(_ m: AppMeeting, recurrence: MeetingRecurrence? = nil, inviteeUsernames: [String] = []) async -> AppMeeting? {
        if isServer {
            let created = try? await meetingsAPI.create(m, recurrence: recurrence, inviteeUsernames: inviteeUsernames)
            sync.noteMutationSettled()
            return created
        }
        let p = PMeeting(title: m.title, date: m.date, allDay: m.allDay, startTime: m.startTime,
                          endTime: m.endTime, location: m.location, note: m.description, colorHex: m.colorHex)
        modelContext.insert(p); save()
        return p.toApp()
    }

    func updateMeeting(_ m: AppMeeting) async {
        if isServer {
            _ = try? await meetingsAPI.update(id: m.id, m)
            sync.noteMutationSettled()
            return
        }
        guard let p = fetchAll(PMeeting.self).first(where: { $0.id == m.id }) else { return }
        p.title = m.title; p.date = m.date; p.allDay = m.allDay; p.startTime = m.startTime
        p.endTime = m.endTime; p.location = m.location; p.note = m.description; p.colorHex = m.colorHex
        save()
    }

    func deleteMeeting(id: String) async {
        if isServer {
            try? await meetingsAPI.delete(id: id)
            sync.noteMutationSettled()
            return
        }
        guard let p = fetchAll(PMeeting.self).first(where: { $0.id == id }) else { return }
        modelContext.delete(p); save()
    }
}

// MARK: - Timelines & milestones

extension DataStore {
    func timelines() async -> [AppTimeline] {
        if isServer {
            if sync.isLive { return sync.cache.timelines }
            return (try? await timelinesAPI.list(workspaceId: appState.currentWorkspaceId)) ?? []
        }
        return fetchAll(PTimeline.self).filter { !$0.isTrashed }.map { $0.toApp() }
    }

    @discardableResult
    func createTimeline(name: String, emoji: String?, colorHex: String, subtitle: String?, folderId: String?) async -> AppTimeline? {
        if isServer {
            let t = try? await timelinesAPI.create(name: name, emoji: emoji, color: colorHex, subtitle: subtitle,
                                                    folderId: folderId, workspaceId: appState.currentWorkspaceId)
            if let t {
                sync.applyLocal { $0.upsertTimeline(t) }
                sync.noteMutationSettled()
            }
            return t
        }
        let p = PTimeline(name: name, emoji: emoji, subtitle: subtitle, colorHex: colorHex, folderId: folderId)
        modelContext.insert(p); save()
        return p.toApp()
    }

    func updateTimeline(_ t: AppTimeline) async {
        if isServer {
            _ = try? await timelinesAPI.update(id: t.id, .init(name: t.name, emoji: t.emoji, color: t.colorHex, subtitle: t.subtitle))
            // Patch metadata onto the cached copy, keeping its milestones.
            sync.applyLocal { cache in
                guard let i = cache.timelines.firstIndex(where: { $0.id == t.id }) else { return }
                cache.timelines[i].name = t.name
                cache.timelines[i].emoji = t.emoji
                cache.timelines[i].subtitle = t.subtitle
                cache.timelines[i].colorHex = t.colorHex
            }
            sync.noteMutationSettled()
            return
        }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == t.id }) else { return }
        p.name = t.name; p.emoji = t.emoji; p.subtitle = t.subtitle; p.colorHex = t.colorHex
        save()
    }

    func deleteTimeline(id: String) async {
        if isServer {
            try? await timelinesAPI.delete(id: id)
            sync.applyLocal { $0.removeTimeline(id: id) }
            sync.noteMutationSettled()
            return
        }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == id }) else { return }
        p.isTrashed = true; p.trashedAt = .now
        save()
    }

    @discardableResult
    func addMilestone(timelineId: String, _ m: AppMilestone) async -> AppMilestone? {
        if isServer {
            let created = try? await timelinesAPI.addMilestone(timelineId: timelineId, m)
            if let created {
                sync.applyLocal { cache in
                    guard let i = cache.timelines.firstIndex(where: { $0.id == timelineId }) else { return }
                    cache.timelines[i].milestones.append(created)
                }
                sync.noteMutationSettled()
            }
            return created
        }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == timelineId }) else { return nil }
        var stored = m
        stored.id = UUID().uuidString
        p.milestones.append(stored)
        save()
        return stored
    }

    func updateMilestone(timelineId: String, _ m: AppMilestone) async {
        if isServer {
            let updated = try? await timelinesAPI.updateMilestone(id: m.id, m)
            sync.applyLocal { cache in
                guard let i = cache.timelines.firstIndex(where: { $0.id == timelineId }),
                      let j = cache.timelines[i].milestones.firstIndex(where: { $0.id == m.id }) else { return }
                cache.timelines[i].milestones[j] = updated ?? m
            }
            sync.noteMutationSettled()
            return
        }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == timelineId }),
              let idx = p.milestones.firstIndex(where: { $0.id == m.id }) else { return }
        p.milestones[idx] = m
        save()
    }

    func deleteMilestone(timelineId: String, milestoneId: String) async {
        if isServer {
            try? await timelinesAPI.deleteMilestone(id: milestoneId)
            sync.applyLocal { cache in
                guard let i = cache.timelines.firstIndex(where: { $0.id == timelineId }) else { return }
                cache.timelines[i].milestones.removeAll { $0.id == milestoneId }
            }
            sync.noteMutationSettled()
            return
        }
        guard let p = fetchAll(PTimeline.self).first(where: { $0.id == timelineId }) else { return }
        p.milestones.removeAll { $0.id == milestoneId }
        save()
    }
}
