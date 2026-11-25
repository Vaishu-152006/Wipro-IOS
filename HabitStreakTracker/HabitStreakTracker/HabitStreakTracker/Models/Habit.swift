import Foundation

struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var category: HabitCategory
    var frequency: HabitFrequency
    var startDate: Date
    /// Optional last day of the habit (`nil` = no end date).
    var endDate: Date?
    var note: String
    /// Start-of-day dates on which the habit was completed.
    var checkIns: [Date]
    /// Daily reminder (local notification) settings.
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    init(id: UUID = UUID(),
         name: String,
         category: HabitCategory,
         frequency: HabitFrequency,
         startDate: Date,
         endDate: Date? = nil,
         note: String = "",
         checkIns: [Date] = [],
         reminderEnabled: Bool = false,
         reminderHour: Int = 9,
         reminderMinute: Int = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.note = note
        self.checkIns = checkIns
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    // MARK: - Codable
    // Written by hand so habits saved by older versions (without reminder
    // fields) still load instead of being lost.

    private enum CodingKeys: String, CodingKey {
        case id, name, category, frequency, startDate, endDate, note, checkIns
        case reminderEnabled, reminderHour, reminderMinute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(HabitCategory.self, forKey: .category)
        frequency = try container.decode(HabitFrequency.self, forKey: .frequency)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        checkIns = try container.decodeIfPresent([Date].self, forKey: .checkIns) ?? []
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 9
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
    }

    // MARK: - Reminder helpers

    /// Today's date at the given clock time (used by the time picker).
    static func time(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    var reminderTime: Date {
        Habit.time(hour: reminderHour, minute: reminderMinute)
    }

    /// e.g. "9:00 AM"
    var reminderTimeText: String {
        reminderTime.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Check-in state

    /// Unique days on which the habit was done.
    private var checkInDays: Set<Date> {
        Set(checkIns.map { $0.startOfDay })
    }

    func isCheckedIn(on date: Date) -> Bool {
        checkInDays.contains(date.startOfDay)
    }

    var isCheckedInToday: Bool {
        isCheckedIn(on: Date())
    }

    var totalCheckIns: Int {
        checkInDays.count
    }

    /// True once the end date (if any) is in the past. Ended habits can no longer be checked in.
    var hasEnded: Bool {
        guard let endDate else { return false }
        return endDate.startOfDay < Date().startOfDay
    }

    // MARK: - Streaks

    /// Consecutive days ending today (or yesterday if today is still pending).
    /// Missing a full day resets this to zero.
    var currentStreak: Int {
        let days = checkInDays
        var cursor = Date().startOfDay
        if !days.contains(cursor) {
            cursor = cursor.addingDays(-1)
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            cursor = cursor.addingDays(-1)
        }
        return streak
    }

    /// Longest run of consecutive days ever recorded for this habit.
    var bestStreak: Int {
        var best = 0
        var run = 0
        var previous: Date?
        for day in checkInDays.sorted() {
            if let previous, previous.addingDays(1).isSameDay(as: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}
