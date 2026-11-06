//
//  DailyActivitiesPreviews.swift
//  ToBeDone
//

import SwiftUI
import SwiftData

// MARK: - Integration examples
struct DailyActivitiesEntryPoint_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([ActivityItem.self, ConfidenceEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)

        return NavigationStack {
            DailyActivitiesView()
        }
        .modelContainer(container)
        .preferredColorScheme(.light)
    }
}

// Example: Add a button on your main/root page
struct RootWithDailyActivitiesButton: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ConfidenceTrackerView()
                } label: { Label("Confidence level", systemImage: "bolt.heart.fill") }

                NavigationLink {
                    DailyActivitiesView()
                } label: { Label("Daily Activities", systemImage: "calendar") }
            }
            .navigationTitle("LifeOrdering")
        }
    }
}
