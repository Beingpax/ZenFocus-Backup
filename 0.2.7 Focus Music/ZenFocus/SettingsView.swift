import SwiftUI
import CoreData
import Sparkle
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingResetConfirmation = false
    
    @AppStorage("reminderInterval") private var reminderInterval = 600
    @AppStorage("reminderSound") private var reminderSound = "Glass"
    @AppStorage("userName") private var userName = ""
    @AppStorage("customCode") private var customCode = "Ready to get shit done?"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("autoShowHideMainWindow") private var autoShowHideMainWindow = true
    
    let availableSounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                generalSection
                reminderSection
                quickAddSection // Renamed from quickFocusSection
                feedbackSection
                dataManagementSection
            }
            .padding(30)
        }
        .frame(maxWidth: 700, maxHeight: .infinity)
    }
    
    var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "General Settings", icon: "gear", color: .blue)
            
            VStack(alignment: .leading, spacing: 12) {
                SettingsTextField(title: "Your Name", text: $userName)
                SettingsTextField(title: "Custom Quote", text: $customCode)
                
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    var reminderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Reminder Settings", icon: "bell", color: .orange)
            
            VStack(alignment: .leading, spacing: 12) {
                SettingsPicker(title: "Reminder Interval", selection: $reminderInterval) {
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                    Text("15 minutes").tag(900)
                    Text("20 minutes").tag(1200)
                    Text("30 minutes").tag(1800)
                }
                
                SettingsPicker(title: "Reminder Sound", selection: $reminderSound) {
                    ForEach(availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                
                Button("Test Sound") {
                    testSound()
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Quick Add", icon: "bolt", color: .purple)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Shortcut")
                    .font(.caption)
                    .foregroundColor(.secondary)
                KeyboardShortcuts.Recorder(for: .toggleQuickAdd)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Feedback", icon: "envelope", color: .green)
            
            Button("Send Bugs & Feature Requests") {
                suggestFeaturesOrReportBugs()
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Data Management", icon: "externaldrive", color: .red)
            
            Button("Reset All Data") {
                showingResetConfirmation = true
            }
            .buttonStyle(BorderlessButtonStyle())
            .alert(isPresented: $showingResetConfirmation) {
                Alert(
                    title: Text("Reset All Data"),
                    message: Text("Are you sure you want to reset all data? This action cannot be undone."),
                    primaryButton: .destructive(Text("Reset")) {
                        resetAllData()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private func testSound() {
        if let sound = NSSound(named: NSSound.Name(reminderSound)) {
            sound.play()
        }
    }
    
    private func suggestFeaturesOrReportBugs() {
        if let url = URL(string: "https://zenfocus.featurebase.app/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func resetAllData() {
        // Reset UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Reset CoreData
        let entities = viewContext.persistentStoreCoordinator?.managedObjectModel.entities ?? []
        for entity in entities {
            if let name = entity.name {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: name)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                
                do {
                    try viewContext.execute(deleteRequest)
                } catch {
                    print("Error deleting \(name) entities: \(error)")
                }
            }
        }
        
        // Save changes
        do {
            try viewContext.save()
        } catch {
            print("Error saving context after reset: \(error)")
        }
        
        // Initialize default values
        initializeDefaultValues()
        
        // Show alert and restart app
        DispatchQueue.main.async {
            self.showRestartAlert()
        }
    }
    
    private func showRestartAlert() {
        let alert = NSAlert()
        alert.messageText = "Data Reset Complete"
        alert.informativeText = "All data has been reset. The app will now restart for the changes to take effect."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart Now")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            restartApp()
        }
    }
    
    private func restartApp() {
        appDelegate.restartApp()
    }
    
    private func initializeDefaultValues() {
        // Reinitialize your default values here
        reminderInterval = 600
        reminderSound = "Glass"
        userName = ""
        customCode = "Ready to get shit done?"
        
        // You may need to reinitialize other UserDefaults values or CoreData entities here
    }
    
    
    struct SettingsTextField: View {
        let title: String
        @Binding var text: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    struct SettingsToggle: View {
        let title: String
        @Binding var isOn: Bool
        
        var body: some View {
            Toggle(title, isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
        }
    }
    
    struct SettingsPicker<SelectionValue: Hashable, Content: View>: View {
        let title: String
        @Binding var selection: SelectionValue
        @ViewBuilder let content: () -> Content
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker(title, selection: $selection) {
                    content()
                }
                .pickerStyle(DefaultPickerStyle())
            }
        }
    }
    
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            SettingsView()
                .environmentObject(AppDelegate())
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
