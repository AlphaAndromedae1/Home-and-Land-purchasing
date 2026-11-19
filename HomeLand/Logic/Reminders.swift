import EventKit
import Foundation
import UserNotifications

struct DeadlineReminder: Equatable {
    let id: String
    let date: Date
    let title: String
    let body: String
}

/// Works out when to remind the user about offer and tender deadlines.
enum DeadlineReminders {
    static let identifierPrefix = "deadline-"
    /// Days before the deadline to remind, at 9 a.m.
    static let dayOffsets = [7, 3, 1]
    /// iOS keeps at most 64 pending notifications per app.
    static let maximumScheduled = 60

    static func reminders(for properties: [Property], now: Date = Date(), calendar: Calendar = .current) -> [DeadlineReminder] {
        var result: [DeadlineReminder] = []
        for property in properties where property.status.isOpen {
            guard let deadline = property.deadline, deadline > now else { continue }
            let what = property.saleType == .taxSale ? "Tender closes" : "Offer deadline"
            let when = deadline.formatted(date: .abbreviated, time: .shortened)
            let body = "\(property.displayTitle) · \(when)"

            for days in dayOffsets {
                guard let day = calendar.date(byAdding: .day, value: -days, to: deadline),
                      let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                      morning > now,
                      morning < deadline
                else { continue }
                let label = days == 1 ? "tomorrow" : "in \(days) days"
                result.append(DeadlineReminder(
                    id: "\(identifierPrefix)\(property.id.uuidString)-\(days)d",
                    date: morning,
                    title: "\(what) \(label)",
                    body: body
                ))
            }

            let shortlyBefore = deadline.addingTimeInterval(-2 * 3_600)
            if shortlyBefore > now {
                result.append(DeadlineReminder(
                    id: "\(identifierPrefix)\(property.id.uuidString)-2h",
                    date: shortlyBefore,
                    title: "\(what) in 2 hours",
                    body: body
                ))
            }
        }
        return result.sorted { $0.date < $1.date }
    }
}

/// Keeps the app's scheduled local notifications in step with the watchlist.
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    private var pendingSync: Task<Void, Never>?

    /// Replaces all deadline notifications. Asks for permission the first time
    /// there's something to remind about. Calls in quick succession are coalesced.
    func sync(_ properties: [Property], enabled: Bool) {
        let reminders = enabled
            ? Array(DeadlineReminders.reminders(for: properties).prefix(DeadlineReminders.maximumScheduled))
            : []
        pendingSync?.cancel()
        pendingSync = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(DeadlineReminders.identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            guard !reminders.isEmpty else { return }

            var settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                settings = await center.notificationSettings()
            }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                break
            default:
                return
            }

            for reminder in reminders {
                guard !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = reminder.body
                content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
            }
        }
    }
}

enum CalendarEvents {
    static func event(for property: Property, deadline: Date, in store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        let what = property.saleType == .taxSale ? "Tender closes" : "Offer deadline"
        event.title = "\(what): \(property.displayTitle)"
        event.startDate = deadline
        event.endDate = deadline.addingTimeInterval(30 * 60)
        let place = [property.title.trimmed, property.municipality.trimmed].filter { !$0.isEmpty }.joined(separator: ", ")
        if !place.isEmpty {
            event.location = place
        }
        var notes = ["\(property.saleType.name) · \(property.kind.name)"]
        if let price = property.askingPrice {
            notes.append("Asking: \(Fmt.money(price))")
        }
        if let maxPrice = property.maxPrice {
            notes.append("Your maximum: \(Fmt.money(maxPrice))")
        }
        if let link = property.listingLink {
            notes.append(link.absoluteString)
        }
        event.notes = notes.joined(separator: "\n")
        event.url = property.listingLink
        event.addAlarm(EKAlarm(relativeOffset: -24 * 3_600))
        event.addAlarm(EKAlarm(relativeOffset: -3 * 3_600))
        return event
    }
}
