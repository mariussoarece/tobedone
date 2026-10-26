//
//  AddActivitySheet.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

// MARK: - Add Sheet
struct AddActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var details: String = ""
    @State private var duration: Double = 60
    @State private var date: Date
    @State private var repeatWeekly: Bool = false
    @State private var repeatDailyWholeWeek: Bool = true
    @State private var repeatWeeksCount: Int = 4   // 1…52
    @State private var showingOverlapAlert = false
    @State private var pendingItem: ActivityItem?

    var onSave: ([ActivityItem]) -> Void

    init(defaultDate: Date, onSave: @escaping ([ActivityItem]) -> Void) {
        // Set default time to 10:00 ONLY when creating a new activity
            let cal = Calendar.current
            let tenAM = cal.date(
                bySettingHour: 10,
                minute: 0,
                second: 0,
                of: defaultDate
            ) ?? defaultDate
        self._date = State(initialValue: tenAM)
        self.onSave = onSave
        }

    private func overlaps(_ newItem: ActivityItem, in existing: [ActivityItem]) -> Bool {
        let cal = Calendar.current

        for item in existing {
            if cal.isDate(item.date, inSameDayAs: newItem.date) {
                let startA = item.date
                let endA = item.date.addingTimeInterval(TimeInterval(item.durationMinutes * 60))

                let startB = newItem.date
                let endB = newItem.date.addingTimeInterval(TimeInterval(newItem.durationMinutes * 60))

                if startA < endB && startB < endA {
                    return true
                }
            }
        }
        return false
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Repeat weekly (same weekday)", isOn: $repeatWeekly)
                    if repeatWeekly {
                        Stepper(value: $repeatWeeksCount, in: 1...52) {
                            Text("For \(repeatWeeksCount) week\(repeatWeeksCount == 1 ? "" : "s")")
                        }
                    }
                }
                Section("Activity") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $details, axis: .vertical).lineLimit(1...3)
                    HStack {
                        Text("Duration")
                        Spacer()
                        Stepper(value: $duration, in: 0...480, step: 5) { Text("\(Int(duration)) min") }
                    }
                }
            }
            .navigationTitle("New Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        var newItems: [ActivityItem] = []

                        if repeatWeekly {
                            let sid = UUID()
                            for w in 0..<repeatWeeksCount {
                                let next = Calendar.current.date(byAdding: .weekOfYear, value: w, to: date)!
                                let item = ActivityItem(
                                    date: next,
                                    name: trimmed,
                                    details: details,
                                    durationMinutes: Int(duration)
                                )
                                item.seriesId = sid

                                // ⭐ OVERLAP CHECK
                                if overlaps(item, in: (try? modelContext.fetch(FetchDescriptor<ActivityItem>())) ?? []) {
                                    pendingItem = item
                                    showingOverlapAlert = true
                                    break
                                }

                                newItems.append(item)
                            }
                        } else {
                            let item = ActivityItem(
                                date: date,
                                name: trimmed,
                                details: details,
                                durationMinutes: Int(duration)
                            )

                            // ⭐ OVERLAP CHECK
                            if overlaps(item, in: (try? modelContext.fetch(FetchDescriptor<ActivityItem>())) ?? []) {
                                pendingItem = item
                                showingOverlapAlert = true
                            } else {
                                newItems.append(item)
                            }

                        }

                        // ⭐ Only save if no overlap alert is shown
                        if !showingOverlapAlert {
                            onSave(newItems)
                            dismiss()
                        }
                    }

                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .alert("Activity Overlaps", isPresented: $showingOverlapAlert) {
                        Button("Create Anyway") {
                            if let item = pendingItem {
                                onSave([item])
                                dismiss()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This activity overlaps an existing one.")
                    }
                }

            }
        }
    }

}
