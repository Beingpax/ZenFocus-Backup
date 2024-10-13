import SwiftUI
import CoreData

struct TodayFocusView: View {
    @ObservedObject var dailyFocusManager: DailyFocusManager
    @ObservedObject var categoryManager: CategoryManager
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var windowManager: WindowManager
    @Binding var selectedView: MainView.ViewType
    
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 120
    @State private var totalFocusTime: TimeInterval = 0
    @State private var completedTasks: Int = 0
    @State private var animateProgress = false
    @State private var nextIncompleteTask: ZenFocusTask?
    
    @State private var lastPlanDate: Date = UserDefaults.standard.object(forKey: "lastPlanDate") as? Date ?? Date.distantPast
    
    @FetchRequest private var todayTasks: FetchedResults<ZenFocusTask>
    
    init(dailyFocusManager: DailyFocusManager, categoryManager: CategoryManager, selectedView: Binding<MainView.ViewType>) {
        self.dailyFocusManager = dailyFocusManager
        self.categoryManager = categoryManager
        self._selectedView = selectedView
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", today as NSDate, tomorrow as NSDate)
        self._todayTasks = FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ZenFocusTask.createdAt, ascending: true)], predicate: predicate, animation: .default)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 20) {
                // Left side
                ScrollView {
                    VStack(spacing: 24) {
                        summarySection
                    }
                    .frame(width: geometry.size.width * 0.35)
                }
                
                // Right side
                VStack(spacing: 24) {
                    taskListSection
                    nextTaskSection
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding()
        }
        .background(Color.clear)
        .onAppear {
            ZenFocusLogger.shared.info("TodayFocusView appeared")
            updateMetrics()
            updateNextIncompleteTask()
            animateProgress = true
        }
        .onDisappear {
            ZenFocusLogger.shared.info("TodayFocusView disappeared")
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskCompleted)) { _ in
            ZenFocusLogger.shared.info("Task completed notification received")
            updateMetrics()
            updateNextIncompleteTask()
        }
    }
    
    private var summarySection: some View {
        VStack(spacing: 24) {
            cardView(title: "Focus Progress", icon: "chart.pie.fill", color: .purple) {
                progressView
            }
            
            cardView(title: "Daily Stats", icon: "chart.bar.fill", color: .blue) {
                statsGridView
            }
        }
    }
    
    private var progressView: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(formatDuration(totalFocusTime))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Goal: \(formatDuration(Double(max(dailyGoalMinutes, 1) * 60)))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(progressPercentage)% Complete")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: animateProgress ? CGFloat(progressRatio) : 0)
                    .stroke(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: animateProgress)
                
                VStack {
                    Text("\(progressPercentage)%")
                        .font(.system(size: 32, weight: .bold))
                    Text("of daily goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)
        }
    }
    
    private var progressRatio: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(totalFocusTime / Double(dailyGoalMinutes * 60), 1.0)
    }
    
    private var progressPercentage: Int {
        Int(progressRatio * 100)
    }
    
    private var statsGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(title: "Tasks Completed", value: "\(completedTasks)", icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Remaining", value: "\(dailyFocusManager.dailyFocusTasks.filter { !$0.isCompleted }.count)", icon: "list.bullet", color: .blue)
        }
    }
    
    private var taskListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Today's Tasks", icon: "list.bullet.rectangle", color: .green)
            
            GeometryReader { geometry in
                VStack {
                    if dailyFocusManager.dailyFocusTasks.filter({ !$0.isCompleted }).isEmpty {
                        Text("You have no tasks for today. Plan your day now to get the most out of it")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        List {
                            ForEach(dailyFocusManager.dailyFocusTasks.filter { !$0.isCompleted }, id: \.self) { task in
                                BetterTaskRow(task: task, categoryManager: categoryManager, onDelete: nil)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(height: max(300, geometry.size.height - 100))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var nextTaskSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(
                title: nextIncompleteTask == nil ? "Plan Your Day" : "Next Up",
                icon: nextIncompleteTask == nil ? "calendar" : "arrow.right.circle.fill",
                color: .orange
            )
            
            HStack(spacing: 16) {
                if let nextTask = nextIncompleteTask {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextTask.title ?? "")
                            .font(.headline)
                            .lineLimit(1)
                        if let category = nextTask.category {
                            Text(category)
                                .font(.subheadline)
                                .foregroundColor(categoryManager.colorForCategory(category))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("You have no tasks for today.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button(action: {
                    if nextIncompleteTask == nil {
                        selectedView = .dailyPlan
                    } else {
                        startFocusSession()
                    }
                }) {
                    Text(nextIncompleteTask == nil ? "Plan Your Day" : "Let's Crush It! 💪")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                           startPoint: .leading,
                                           endPoint: .trailing)
                        )
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private func cardView<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private func updateMetrics() {
        ZenFocusLogger.shared.info("Updating metrics")
        DispatchQueue.global(qos: .userInitiated).async {
            let focusTime = self.todayTasks.reduce(0) { $0 + $1.focusedDuration }
            let completed = self.todayTasks.filter { $0.isCompleted }.count
            
            DispatchQueue.main.async {
                self.totalFocusTime = focusTime
                self.completedTasks = completed
                ZenFocusLogger.shared.info("Metrics updated - Total focus time: \(focusTime), Completed tasks: \(completed)")
            }
        }
    }
    
    private func startFocusSession() {
        guard let topTask = nextIncompleteTask else {
            ZenFocusLogger.shared.warning("Attempted to start focus session with no incomplete tasks")
            return
        }
        ZenFocusLogger.shared.info("Starting focus session for task: \(topTask.title ?? "")")
        startFocusSession(for: topTask)
        lastPlanDate = Date()
        UserDefaults.standard.set(lastPlanDate, forKey: "lastPlanDate")
    }
    
    private func startFocusSession(for task: ZenFocusTask) {
        windowManager.showFocusedTaskWindow(
            for: task,
            dailyFocusManager: dailyFocusManager,
            onComplete: { completedTask in
                ZenFocusLogger.shared.info("Focus session completed for task: \(task.title ?? "")")
                task.isCompleted = true
                task.completedAt = Date()
                do {
                    try viewContext.save()
                    ZenFocusLogger.shared.info("Task marked as completed and saved")
                    NotificationCenter.default.post(name: .taskCompleted, object: nil)
                    updateMetrics()
                    updateNextIncompleteTask()
                    
                    // Show the task completion animation with next task info
                    windowManager.showTaskCompletionAnimation(
                        for: task,
                        dailyFocusManager: dailyFocusManager,
                        onStartNextTask: { nextTask in
                            self.startFocusSession(for: nextTask)
                        },
                        onDismiss: {
                            self.windowManager.showMainWindow()
                        }
                    )
                } catch {
                    ZenFocusLogger.shared.error("Failed to save completed task: \(error.localizedDescription)")
                    // Show an alert to the user
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Error Saving Completed Task"
                        alert.informativeText = "There was an error saving the completed task. Please try again."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            },
            onBreak: {
                ZenFocusLogger.shared.info("Break started for task: \(task.title ?? "")")
                // Handle break
            }
        )
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func updateNextIncompleteTask() {
        nextIncompleteTask = dailyFocusManager.dailyFocusTasks.first { !$0.isCompleted }
        if let task = nextIncompleteTask {
            ZenFocusLogger.shared.info("Next incomplete task updated: \(task.title ?? "")")
        } else {
            ZenFocusLogger.shared.info("No incomplete tasks remaining")
        }
    }
}
