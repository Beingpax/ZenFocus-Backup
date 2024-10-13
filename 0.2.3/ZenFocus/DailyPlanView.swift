import SwiftUI
import CoreData

struct DailyPlanView: View {
    @ObservedObject var categoryManager: CategoryManager
    @ObservedObject var dailyFocusManager: DailyFocusManager
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var windowManager: WindowManager
    @Environment(\.colorScheme) private var colorScheme
    var onDismiss: () -> Void
    var onStartDay: () -> Void
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ZenFocusTask.createdAt, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == NO AND isInDailyFocus == NO"),
        animation: .default)
    private var availableTasks: FetchedResults<ZenFocusTask>
    
    @State private var selectedTasks: Set<ZenFocusTask> = []
    @State private var isDragging = false
    @State private var draggedTask: ZenFocusTask?
    @State private var dropTargetIndex: Int?
    @State private var isDraggingIntoToday = false
    @State private var isDraggingIntoSomeday = false
    @State private var dropTargetIndexToday: Int?
    @State private var dropTargetIndexSomeday: Int?

    var body: some View {
        VStack(spacing: 0) {
            header
            
            HStack(spacing: 24) {
                allTasksList
                dailyPlanList
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            footer
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            ZenFocusLogger.shared.info("DailyPlanView appeared")
        }
        .onDisappear {
            ZenFocusLogger.shared.info("DailyPlanView disappeared")
        }
    }
    
    private var header: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("What do You Want to Get Done Today?")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text("Drag-n-drop tasks to today's focus view. And reorder the tasks based on the priority")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
    }

    private var allTasksList: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Someday", icon: "list.bullet", color: .blue)
            
            List {
                ForEach(availableTasks, id: \.self) { task in
                    taskRowView(for: task, isInDailyFocus: false)
                        .onDrag {
                            self.draggedTask = task
                            return NSItemProvider(object: task.objectID.uriRepresentation() as NSURL)
                        }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .padding(.vertical, 2)
            .onDrop(of: [.url], delegate: TaskDropDelegate(
                taskManager: dailyFocusManager,
                viewContext: viewContext,
                dropTargetIndex: $dropTargetIndexSomeday,
                isDraggingInto: $isDraggingIntoSomeday,
                draggedTask: $draggedTask,
                isTargetDailyFocus: false
            ))
            
            TaskInputView(categoryManager: categoryManager) { newTask in
                ZenFocusLogger.shared.info("New task added: \(newTask.title ?? "")")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDraggingIntoSomeday ? Color.blue : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isDraggingIntoSomeday)
    }
    
    private var dailyPlanList: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Today", icon: "list.bullet.rectangle", color: .green)

            List {
                ForEach(dailyFocusManager.dailyFocusTasks, id: \.objectID) { task in
                    taskRowView(for: task, isInDailyFocus: true)
                        .onDrag {
                            self.draggedTask = task
                            return NSItemProvider(object: task.objectID.uriRepresentation() as NSURL)
                        }
                }
                .onMove { source, destination in
                    DispatchQueue.main.async {
                        self.dailyFocusManager.reorderDailyFocusTasks(from: source, to: destination)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .padding(.vertical, 2)
            .onDrop(of: [.url], delegate: TodayTaskDropDelegate(
                taskManager: dailyFocusManager,
                viewContext: viewContext,
                dropTargetIndex: $dropTargetIndexToday,
                isDraggingInside: $isDraggingIntoToday,
                draggedTask: $draggedTask
            ))
            
            TaskInputView(categoryManager: categoryManager) { newTask in
                self.dailyFocusManager.addNewTask(newTask, toDailyFocus: true)
                ZenFocusLogger.shared.info("New task added to daily focus: \(newTask.title ?? "")")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDraggingIntoToday && draggedTask?.isInDailyFocus == false ? Color.green : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isDraggingIntoToday && draggedTask?.isInDailyFocus == false)
    }
    
    private func taskRowView(for task: ZenFocusTask, isInDailyFocus: Bool) -> some View {
        BetterTaskRow(task: task, categoryManager: categoryManager, onDelete: {
            deleteTask(task)
        }, onToggleCompletion: {
            dailyFocusManager.toggleTaskCompletion(task)
        })
        .background(backgroundColorForTask(task, isInDailyFocus: isInDailyFocus))
        .cornerRadius(8)
        .overlay(
            dropIndicator(for: task, isInDailyFocus: isInDailyFocus)
        )
    }
    
    private func backgroundColorForTask(_ task: ZenFocusTask, isInDailyFocus: Bool) -> Color {
        if draggedTask == task {
            return Color(NSColor.secondaryLabelColor.withAlphaComponent(0.3))
        } else if selectedTasks.contains(task) {
            return Color(NSColor.secondaryLabelColor.withAlphaComponent(0.2))
        } else {
            return Color.clear
        }
    }
    
    private func dropIndicator(for task: ZenFocusTask, isInDailyFocus: Bool) -> some View {
        Group {
            if isInDailyFocus && draggedTask?.objectID != task.objectID &&
               dropTargetIndexToday == dailyFocusManager.dailyFocusTasks.firstIndex(where: { $0.objectID == task.objectID }) {
                Rectangle()
                    .fill(Color.green.opacity(0.5))
                    .frame(height: 2)
                    .offset(y: (dailyFocusManager.dailyFocusTasks.firstIndex(where: { $0.objectID == task.objectID }) ?? 0) > (dailyFocusManager.dailyFocusTasks.firstIndex(where: { $0.objectID == draggedTask?.objectID }) ?? 0) ? 25 : -25)
            }
        }
    }
    
    private var footer: some View {
        HStack(spacing: 16) {
            clearFocusButton
            Spacer()
            startDayButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var clearFocusButton: some View {
        Button(action: dailyFocusManager.resetDailyFocus) {
            Text("Clear Today's Focus")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(dailyFocusManager.dailyFocusTasks.isEmpty ? .secondary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(dailyFocusManager.dailyFocusTasks.isEmpty ? Color.gray.opacity(0.3) : Color.red)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(dailyFocusManager.dailyFocusTasks.isEmpty)
    }
    
    private var startDayButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                onStartDay()
            }
        }) {
            Text("Start Your Day")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(dailyFocusManager.dailyFocusTasks.isEmpty)
    }
    
    private func deleteTask(_ task: ZenFocusTask) {
        do {
            dailyFocusManager.deleteTask(task)
            ZenFocusLogger.shared.info("Task deleted successfully: \(task.title ?? "")")
        } catch {
            ZenFocusLogger.shared.error("Failed to delete task: \(task.title ?? "")", error: error)
            // You might want to show an alert to the user here
        }
    }
    
    private func clearSelectedTasks() {
        do {
            for task in selectedTasks {
                dailyFocusManager.deleteTask(task)
            }
            selectedTasks.removeAll()
            ZenFocusLogger.shared.info("Selected tasks cleared successfully")
        } catch {
            ZenFocusLogger.shared.error("Failed to clear selected tasks", error: error)
            // You might want to show an alert to the user here
        }
    }
}

struct TaskDropDelegate: DropDelegate {
    let taskManager: DailyFocusManager
    let viewContext: NSManagedObjectContext
    @Binding var dropTargetIndex: Int?
    @Binding var isDraggingInto: Bool
    @Binding var draggedTask: ZenFocusTask?
    let isTargetDailyFocus: Bool
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.url]).first else {
            ZenFocusLogger.shared.warning("No valid item provider found for drop operation")
            return false
        }
        
        itemProvider.loadObject(ofClass: NSURL.self) { (urlObject, error) in
            if let error = error {
                ZenFocusLogger.shared.error("Error loading dropped object", error: error)
                return
            }
            
            guard let url = urlObject as? URL,
                  let objectID = self.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
                ZenFocusLogger.shared.warning("Invalid URL or object ID for dropped task")
                return
            }
            
            DispatchQueue.main.async {
                do {
                    guard let task = try self.viewContext.existingObject(with: objectID) as? ZenFocusTask else {
                        ZenFocusLogger.shared.warning("Dropped object is not a valid ZenFocusTask")
                        return
                    }
                    
                    if self.isTargetDailyFocus {
                        // Dropping from Someday list to Today list
                        if let dropIndex = self.dropTargetIndex {
                            self.taskManager.addTaskToDailyFocus(task, at: dropIndex)
                        } else {
                            self.taskManager.addTaskToDailyFocus(task)
                        }
                        ZenFocusLogger.shared.info("Task added to daily focus: \(task.title ?? "")")
                    } else {
                        // Dropping from Today list to Someday list
                        if task.isInDailyFocus {
                            self.taskManager.removeTaskFromDailyFocus(task)
                            ZenFocusLogger.shared.info("Task removed from daily focus: \(task.title ?? "")")
                        }
                    }
                    
                    try self.viewContext.save()
                    ZenFocusLogger.shared.info("Task drop operation completed successfully")
                } catch {
                    ZenFocusLogger.shared.error("Error processing dropped task", error: error)
                    // You might want to show an alert to the user here
                }
                
                self.dropTargetIndex = nil
                self.isDraggingInto = false
                self.draggedTask = nil
            }
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let location = info.location
        let tasks = isTargetDailyFocus ? taskManager.dailyFocusTasks : taskManager.availableTasks
        
        // Assuming each task row is about 50 points tall
        let rowHeight: CGFloat = 50
        let estimatedIndex = Int(location.y / rowHeight)
        
        dropTargetIndex = min(max(estimatedIndex, 0), tasks.count)
        
        return DropProposal(operation: .move)
    }
    
    func dropEntered(info: DropInfo) {
        if isTargetDailyFocus {
            isDraggingInto = draggedTask?.isInDailyFocus == false
        } else {
            isDraggingInto = draggedTask?.isInDailyFocus == true
        }
        ZenFocusLogger.shared.debug("Drop entered \(isTargetDailyFocus ? "daily focus" : "someday") area")
    }
    
    func dropExited(info: DropInfo) {
        isDraggingInto = false
        dropTargetIndex = nil
        ZenFocusLogger.shared.debug("Drop exited \(isTargetDailyFocus ? "daily focus" : "someday") area")
    }
}

struct TodayTaskDropDelegate: DropDelegate {
    let taskManager: DailyFocusManager
    let viewContext: NSManagedObjectContext
    @Binding var dropTargetIndex: Int?
    @Binding var isDraggingInside: Bool
    @Binding var draggedTask: ZenFocusTask?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.url]).first else {
            ZenFocusLogger.shared.warning("No valid item provider found for drop operation")
            return false
        }
        
        itemProvider.loadObject(ofClass: NSURL.self) { (urlObject, error) in
            if let error = error {
                ZenFocusLogger.shared.error("Error loading dropped object", error: error)
                return
            }
            
            guard let url = urlObject as? URL,
                  let objectID = self.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
                ZenFocusLogger.shared.warning("Invalid URL or object ID for dropped task")
                return
            }
            
            DispatchQueue.main.async {
                do {
                    guard let task = try self.viewContext.existingObject(with: objectID) as? ZenFocusTask else {
                        ZenFocusLogger.shared.warning("Dropped object is not a valid ZenFocusTask")
                        return
                    }
                    
                    if task.isInDailyFocus {
                        // Reordering within Today list
                        if let currentIndex = self.taskManager.dailyFocusTasks.firstIndex(of: task),
                           let dropIndex = self.dropTargetIndex {
                            self.taskManager.reorderDailyFocusTasks(from: IndexSet(integer: currentIndex), to: dropIndex)
                            ZenFocusLogger.shared.info("Task reordered in daily focus: \(task.title ?? "")")
                        }
                    } else {
                        // Adding from Someday list to Today list
                        if let dropIndex = self.dropTargetIndex {
                            self.taskManager.addTaskToDailyFocus(task, at: dropIndex)
                        } else {
                            self.taskManager.addTaskToDailyFocus(task)
                        }
                        ZenFocusLogger.shared.info("Task added to daily focus: \(task.title ?? "")")
                    }
                    
                    try self.viewContext.save()
                    ZenFocusLogger.shared.info("Task drop operation completed successfully")
                } catch {
                    ZenFocusLogger.shared.error("Error processing dropped task", error: error)
                    // You might want to show an alert to the user here
                }
                
                self.dropTargetIndex = nil
                self.isDraggingInside = false
                self.draggedTask = nil
            }
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let location = info.location
        let tasks = taskManager.dailyFocusTasks
        
        // Assuming each task row is about 50 points tall
        let rowHeight: CGFloat = 50
        let estimatedIndex = Int(location.y / rowHeight)
        
        dropTargetIndex = min(max(estimatedIndex, 0), tasks.count)
        
        // Don't set isDraggingInside here to avoid showing feedback when reordering within the same view
        
        return DropProposal(operation: .move)
    }
    
    func dropEntered(info: DropInfo) {
        isDraggingInside = draggedTask?.isInDailyFocus == false
        ZenFocusLogger.shared.debug("Drop entered daily focus area")
    }
    
    func dropExited(info: DropInfo) {
        isDraggingInside = false
        dropTargetIndex = nil
        ZenFocusLogger.shared.debug("Drop exited daily focus area")
    }
}