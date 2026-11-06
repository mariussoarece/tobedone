//
//  CompactTagToggleStyle.swift
//  ToBeDone
//

import SwiftUI

struct CompactTagToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            configuration.label
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)   // squeeze text if needed
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: 8) // equal width per column
                .background(
                    Capsule()
                        .fill(configuration.isOn ? Color(.tertiarySystemFill)
                                                  :Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}
