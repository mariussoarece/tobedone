//
//  ReminderBeforeRows.swift
//  ToBeDone
//
//  "Remind me before" rows for adding a To Do task or a Daily Routine activity:
//  a switch, then a date & time picker for when the reminder should arrive.
//  The choice is kept as minutes before the start, so it still fits when the
//  start date or time is changed, and for every week of a repeating activity.
//

import SwiftUI

struct ReminderBeforeRows: View {
    @Binding var isOn: Bool
    @Binding var minutesBefore: Int
    let start: Date

    var body: some View {
        Toggle("Remind me before", isOn: $isOn)
        if isOn {
            DatePicker("Remind at", selection: remindAt, in: ...start,
                       displayedComponents: [.date, .hourAndMinute])
            if minutesBefore > 0 {
                Label("\(Agenda.describeMinutes(minutesBefore)) before the start", systemImage: "bell")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Choose a time before the start")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    /// The reminder time, shown as a date but stored as minutes before `start`
    private var remindAt: Binding<Date> {
        Binding(
            get: { start.addingTimeInterval(TimeInterval(-minutesBefore * 60)) },
            set: { picked in
                minutesBefore = max(0, Int((start.timeIntervalSince(picked) / 60).rounded()))
            }
        )
    }
}

/// Small "🔔 30 min before" line under a task or activity that has an early reminder.
struct ReminderBadge: View {
    let minutes: Int?

    var body: some View {
        if let minutes, minutes > 0 {
            Label("\(Agenda.describeMinutes(minutes)) before", systemImage: "bell.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}
