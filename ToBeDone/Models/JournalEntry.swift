//
//  JournalEntry.swift
//  ToBeDone
//
//  One Journalling entry: how the day felt (Awesome … Worse) and formatted
//  text (bold, italic, underline, colours). The text is kept twice: as RTF for
//  the formatting, and as plain text for searching.
//  Every property has a default value, so adding this model never affects the
//  data that is already stored.
//

import SwiftUI
import SwiftData

enum JournalMood: String, CaseIterable, Identifiable, Codable {
    case awesome = "Awesome"
    case excellent = "Excellent"
    case good = "Good"
    case notBad = "Not Bad"
    case couldBeBetter = "Could be better"
    case bad = "Bad"
    case worse = "Worse"

    var id: String { rawValue }
    var title: String { rawValue }

    var emoji: String {
        switch self {
        case .awesome: return "🤩"
        case .excellent: return "😄"
        case .good: return "🙂"
        case .notBad: return "😐"
        case .couldBeBetter: return "😕"
        case .bad: return "🙁"
        case .worse: return "😣"
        }
    }

    /// From green (Awesome) to red (Worse)
    var color: Color {
        switch self {
        case .awesome: return .green
        case .excellent: return .mint
        case .good: return .teal
        case .notBad: return .blue
        case .couldBeBetter: return .yellow
        case .bad: return .orange
        case .worse: return .red
        }
    }
}

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    var moodRaw: String = JournalMood.good.rawValue
    /// The formatted text, as RTF
    @Attribute(.externalStorage) var richText: Data? = nil
    /// The same text without formatting, used by the search box
    var plainText: String = ""

    init(date: Date = .now, mood: JournalMood = .good, richText: Data? = nil, plainText: String = "") {
        self.date = date
        self.moodRaw = mood.rawValue
        self.richText = richText
        self.plainText = plainText
    }

    var mood: JournalMood {
        get { JournalMood(rawValue: moodRaw) ?? .good }
        set { moodRaw = newValue.rawValue }
    }
}
