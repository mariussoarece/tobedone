//
//  JournalView.swift
//  ToBeDone
//
//  Journalling: every entry with its mood, newest first, and a search box that
//  looks through the text of all entries.
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var search = ""
    @State private var showNewEntry = false

    private var results: [JournalEntry] {
        let words = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return entries }
        return entries.filter {
            $0.plainText.localizedStandardContains(words) || $0.mood.title.localizedStandardContains(words)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journalling")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .padding(.horizontal)
                .padding(.top)

            List {
                Section {
                    // Search through all entries
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search all entries", text: $search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                        if !search.isEmpty {
                            Button {
                                search = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Clear search")
                        }
                    }

                    // Blue button with white text, like Add Task in To Do
                    Button {
                        showNewEntry = true
                    } label: {
                        // Pencil and paper in white, inside the blue button
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                            Text("New Entry")
                        }
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Section(search.isEmpty ? "Entries" : "\(results.count) found") {
                    if results.isEmpty {
                        Text(search.isEmpty ? "No entries yet. Tap New Entry to write the first one."
                                            : "Nothing found for “\(search)”.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(results) { entry in
                        NavigationLink {
                            JournalEditorView(entry: entry)
                        } label: {
                            JournalRow(entry: entry)
                        }
                    }
                    .onDelete(perform: delete)
                }

                if !entries.isEmpty {
                    Section {
                        Button("Export Journal") { exportJournal() }
                            .buttonStyle(.borderedProminent)
                    } footer: {
                        Text("Saves all entries, with their formatting, in one document you can open in Pages, Word or Notes.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showNewEntry) {
            JournalEditorView(entry: nil)
        }
    }

    // MARK: - Export (no import)

    /// All entries, oldest first, in one RTF document: a bold heading with the
    /// date and mood, then the text with its formatting.
    private func exportJournal() {
        let document = NSMutableAttributedString()
        let heading: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: UIColor.label,
        ]
        let body: [NSAttributedString.Key: Any] = [
            .font: RichTextController.baseFont,
            .foregroundColor: UIColor.label,
        ]
        document.append(NSAttributedString(string: "ToBeDone – Journal\n\n",
                                           attributes: [.font: UIFont.preferredFont(forTextStyle: .title1)]))
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            let when = entry.date.formatted(date: .complete, time: .shortened)
            document.append(NSAttributedString(string: "\(when) · \(entry.mood.emoji) \(entry.mood.title)\n",
                                               attributes: heading))
            document.append(JournalText.attributed(from: entry.richText))
            document.append(NSAttributedString(string: "\n\n", attributes: body))
        }

        guard let data = JournalText.rtf(from: document) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ToBeDone-Journal.rtf")
        do {
            try data.write(to: url, options: .atomic)
            presentShareSheet(url: url)
        } catch {
            print("Journal export error:", error)
        }
    }

    private func presentShareSheet(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // Required for iPad — without this it can crash on iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }

    private func delete(at offsets: IndexSet) {
        let shown = results
        for index in offsets {
            modelContext.delete(shown[index])
        }
        try? modelContext.save()
    }
}

/// "🙂 Good · Mon, 9 Nov" and the first lines of the text
private struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.mood.emoji)
                Text(entry.mood.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(entry.mood.color)
                Spacer()
                Text(entry.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !entry.plainText.isEmpty {
                Text(entry.plainText)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor

/// Write or change an entry: choose the mood, then write with formatting.
struct JournalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: JournalEntry?

    @State private var mood: JournalMood
    @State private var date: Date
    @State private var text: NSAttributedString
    @State private var controller = RichTextController()

    /// The colours offered for the text; nil = normal (black / white)
    private struct TextColor: Identifiable {
        let name: String
        let color: UIColor?
        var id: String { name }
    }
    /// Black (white in dark mode, so it stays readable) and red
    private let colors: [TextColor] = [
        TextColor(name: "Black", color: nil), TextColor(name: "Red", color: .systemRed),
    ]

    init(entry: JournalEntry?) {
        self.entry = entry
        _mood = State(initialValue: entry?.mood ?? .good)
        _date = State(initialValue: entry?.date ?? .now)
        _text = State(initialValue: JournalText.attributed(from: entry?.richText))
    }

    var body: some View {
        Form {
            Section("How is your mood?") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(JournalMood.allCases) { option in
                            Button {
                                mood = option
                            } label: {
                                Text("\(option.emoji) \(option.title)")
                                    .font(.subheadline.weight(mood == option ? .semibold : .regular))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(mood == option ? option.color.opacity(0.25) : Color(.tertiarySystemFill),
                                                in: Capsule())
                                    .overlay(Capsule().stroke(mood == option ? option.color : .clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(mood == option ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                DatePicker("Date", selection: $date)
            }

            Section {
                formattingBar
                RichTextEditor(text: $text, controller: controller)
                    .frame(minHeight: 260)
            } header: {
                Text("Write")
            } footer: {
                Text("Select words, then tap B, I, U, black or red. Without a selection, the style applies to what you type next.")
            }
        }
        .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    /// B  I  U  and the colour dots
    private var formattingBar: some View {
        HStack(spacing: 10) {
            formatButton("bold", active: controller.isBold, label: "Bold") { controller.toggleBold() }
            formatButton("italic", active: controller.isItalic, label: "Italic") { controller.toggleItalic() }
            formatButton("underline", active: controller.isUnderlined, label: "Underline") { controller.toggleUnderline() }
            Divider().frame(height: 24)
            ForEach(colors) { item in
                Button {
                    controller.setColor(item.color)
                } label: {
                    Circle()
                        .fill(item.color.map { Color($0) } ?? Color.primary)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(item.name) colour")
            }
        }
    }

    private func formatButton(_ symbol: String, active: Bool, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 30)
                .background(active ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func save() {
        let target = entry ?? JournalEntry()
        target.mood = mood
        target.date = date
        target.richText = JournalText.rtf(from: text)
        target.plainText = text.string
        if entry == nil {
            modelContext.insert(target)
        }
        try? modelContext.save()
        Toast.show(entry == nil ? "Entry added" : "Entry saved")
        dismiss()
    }
}
