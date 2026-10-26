//
//  ActivityRow.swift
//  ToBeDone
//

import SwiftUI

// MARK: - Row
struct ActivityRow: View {
    @Bindable var item: ActivityItem
    var onToggle: (ActivityItem) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Button(action: { onToggle(item) }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack{
                    Text(timeFormatter.string(from: item.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.name)
                        .font(.body.weight(.medium))
                    if !item.details.isEmpty { Text(item.details).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            if item.durationMinutes > 0 {
                Text("\(item.durationMinutes)m").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}
