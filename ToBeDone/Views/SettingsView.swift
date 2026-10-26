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

                }
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline) // optional
            .navigationTitle("")
        }
    }
}
