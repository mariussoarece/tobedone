//
//  SettingsView.swift
//  ToBeDone
//

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedTheme") private var selectedTheme: String = "Default"
    @AppStorage("selectedCurrency") private var selectedCurrency: String = "USD"
    @AppStorage("reminderHour") private var reminderHour: Int = 22
    @AppStorage("reminderMinute") private var reminderMinute: Int = 0

    // Backup & restore
    @State private var lastBackup: AppBackup?
    @State private var confirmRestore = false
    @State private var dataMessage: String?

    let currencies = [
        "USD", "EUR", "GBP", "RON", "JPY", "CNY", "INR", "AUD", "CAD", "CHF",
        "SEK", "NOK", "DKK", "NZD", "ZAR", "RUB", "BRL", "MXN", "SGD", "HKD",
        "TRY", "PLN", "HUF", "CZK", "ARS", "KRW", "THB", "AED", "SAR", "EGP",
        "NGN", "MYR", "IDR", "VND", "ILS", "BGN", "UAH", "PKR"
    ]
    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                // ✅ Custom large title — not next to the back button
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.top)

                Form {
                    Section(header: Text("Appearance")) {
                        Picker("Theme", selection: $selectedTheme) {
                            Text("Default").tag("Default")
                            Text("Light").tag("Light")
                            Text("Dark").tag("Dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    Section(header: Text("Currency")) {
                        Picker("Currency", selection: $selectedCurrency) {
                            ForEach(currencies, id: \.self) { currency in
                                Text(currency)
                            }
                        }
                    }
                    Section(header: Text("Daily Activity Reminder")) {
                        DatePicker(
                            "Reminder Time",
                            selection: Binding(
                                get: {
                                    Calendar.current.date(from: DateComponents(
                                        hour: reminderHour,
                                        minute: reminderMinute
                                    )) ?? Date()
                                },
                                set: { newValue in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                    reminderHour = comps.hour ?? 22
                                    reminderMinute = comps.minute ?? 0
                                    UserDefaults.standard.set(true, forKey: ActivityReminderScheduler.enabledKey)
                                    ActivityReminderScheduler.refresh(context: modelContext)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Section {
                        if let backup = lastBackup {
                            LabeledContent("Last backup",
                                           value: backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                            LabeledContent("Items in backup", value: "\(backup.totalCount)")
                        } else {
                            Text("No backup yet")
                                .foregroundStyle(.secondary)
                        }

                        Button("Back Up Now") {
                            let ok = BackupManager.writeBackup(context: modelContext)
                            lastBackup = BackupManager.readLatestBackup()
                            dataMessage = ok ? "Backup saved." : "Nothing to back up yet."
                        }

                        Button("Restore from Last Backup") { confirmRestore = true }
                            .disabled(lastBackup == nil)

                        if let error = DataStore.openError {
                            Text("At the last launch the database could not be opened (\(error)). A copy of it was kept on the phone.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Data & Backup")
                    } footer: {
                        Text("The app backs up automatically every time you open or leave it. Backups are in the Files app under On My iPhone › ToBeDone › Backups.")
                    }
                }
                .onAppear { lastBackup = BackupManager.readLatestBackup() }
                .confirmationDialog("Restore from the last backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
                    Button("Restore") {
                        if let backup = BackupManager.readLatestBackup() {
                            let added = BackupManager.restore(backup, into: modelContext)
                            dataMessage = "\(added) items restored."
                        }
                    }
                } message: {
                    Text("Items missing from the app are added back. Nothing is deleted or changed.")
                }
                .alert("Data & Backup", isPresented: Binding(
                    get: { dataMessage != nil },
                    set: { if !$0 { dataMessage = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(dataMessage ?? "")
                }
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline) // optional
            .navigationTitle("")
        }
    }
}
