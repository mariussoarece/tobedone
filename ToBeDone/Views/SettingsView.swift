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
    @AppStorage(ReminderScheduler.hourKey) private var reminderHour: Int = ReminderScheduler.defaultHour
    @AppStorage(ReminderScheduler.minuteKey) private var reminderMinute: Int = ReminderScheduler.defaultMinute
    @AppStorage(ReminderScheduler.summaryEnabledKey) private var dailySummaryEnabled = true
    @AppStorage(ReminderScheduler.activityStartEnabledKey) private var activityStartEnabled = true
    @State private var notificationsDenied = false

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
                    Section {
                        Toggle("Daily summary", isOn: $dailySummaryEnabled)
                        if dailySummaryEnabled {
                            DatePicker(
                                "Time",
                                selection: Binding(
                                    get: {
                                        Calendar.current.date(from: DateComponents(
                                            hour: reminderHour,
                                            minute: reminderMinute
                                        )) ?? Date()
                                    },
                                    set: { newValue in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                        reminderHour = comps.hour ?? ReminderScheduler.defaultHour
                                        reminderMinute = comps.minute ?? ReminderScheduler.defaultMinute
                                        ReminderScheduler.refresh(context: modelContext)
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                        Toggle("When an activity starts", isOn: $activityStartEnabled)

                        if notificationsDenied {
                            Button("Turn On Notifications in iPhone Settings") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    } header: {
                        Text("Notifications")
                    } footer: {
                        Text(notificationsDenied
                             ? "Notifications are turned off for ToBeDone. Turn them on, with Lock Screen, Notification Center and Banners, in iPhone Settings."
                             : "The daily summary lists the tasks and Daily Routine activities you haven't finished. If everything is done, no notification is sent.")
                    }
                    .onChange(of: dailySummaryEnabled) { ReminderScheduler.refresh(context: modelContext) }
                    .onChange(of: activityStartEnabled) { ReminderScheduler.refresh(context: modelContext) }

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
                .task {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    notificationsDenied = settings.authorizationStatus == .denied
                }
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
