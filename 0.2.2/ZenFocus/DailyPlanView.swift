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
                    taskRowView(for: task)
                        .onDrag {
                            self.draggedTask = task
                            self.isDragging = true
                            return NSItemProvider(object: task.objectID.uriRepresentation() as NSURL)
                        }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .padding(.vertical, 2)
            
            TaskInputView(categoryManager: categoryManager) { newTask in
                ZenFocusLogger.shared.info("New task added: \(newTask.title ?? "")")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func taskRowView(for task: ZenFocusTask) -> some View {
        BetterTaskRow(task: task, categoryManager: categoryManager, onDelete: {
            deleteTask(task)
        })
        .onTapGesture {
            if selectedTasks.contains(task) {
                selectedTasks.remove(task)
            } else {
                selectedTasks.insert(task)
            }
        }
        .background(selectedTasks.contains(task) ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedTasks.contains(task) ? Color.blue : Color.clear, lineWidth: 2)
        )
        .overlay(
            draggedTask == task && isDragging ?
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2)
                : nil
        )
    }
    
    private var dailyPlanList: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Today", icon: "list.bullet.rectangle", color: .green)

            List {
                ForEach(dailyFocusManager.dailyFocusTasks, id: \.objectID) { task in
                    dailyTaskRowView(for: task)
                        .onDrag {
                            self.draggedTask = task
                            self.isDragging = true
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
            .onDrop(of: [.url], delegate: DailyPlanDropDelegate(dailyFocusManager: dailyFocusManager, viewContext: viewContext, dropTargetIndex: $dropTargetIndex, isDragging: $isDragging, draggedTask: $draggedTask))
            
            TaskInputView(categoryManager: categoryManager) { newTask in
                dailyFocusManager.addTaskToDailyFocus(newTask)
                ZenFocusLogger.shared.info("New task added to daily focus: \(newTask.title ?? "")")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDragging && draggedTask?.isInDailyFocus == false ? Color.green : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
    
    private func dailyTaskRowView(for task: ZenFocusTask) -> some View {
        BetterTaskRow(task: task, categoryManager: categoryManager)
        .background(draggedTask?.objectID == task.objectID && isDragging ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(draggedTask?.objectID == task.objectID && isDragging ? Color.green : Color.clear, lineWidth: 2)
        )
        .overlay(
            isDragging && draggedTask?.objectID != task.objectID && dropTargetIndex == dailyFocusManager.dailyFocusTasks.firstIndex(where: { $0.objectID == task.objectID }) ?
                Rectangle()
                    .fill(Color.green.opacity(0.7))
                    .frame(height: 2)
                    .offset(y: (dailyFocusManager.dailyFocusTasks.firstIndex(where: { $0.objectID == task.objectID }) ?? 0) > (dailyFocusManager.dailyFocusTasks.firstIndex(where: { $0.objectID == draggedTask?.objectID }) ?? 0) ? 25 : -25)
                : nil
        )
    }
    
    private var footer: some View {
        HStack(spacing: 16) {
            addSelectedButton
            Spacer()
            clearFocusButton
            Spacer()
            startDayButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var addSelectedButton: some View {
        Button(action: addSelectedTasks) {
            Text("Add Selected to Today's Focus")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(selectedTasks.isEmpty ? .secondary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedTasks.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedTasks.isEmpty)
    }
    
    private var clearFocusButton: some View {
        Button(action: dailyFocusManager.resetDailyFocus) {
            Text("Clear Today's Focus")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(dailyFocusManager.dailyFocusTasks.isEmpty ? .secondary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
            viewContext.delete(task)
            try viewContext.save()
            ZenFocusLogger.shared.info("Task deleted successfully: \(task.title ?? "")")
        } catch {
            ZenFocusLogger.shared.error("Error deleting task: \(error.localizedDescription)")
            // Show an alert to the user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error Deleting Task"
                alert.informativeText = "There was an error deleting the task. Please try again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    private func addSelectedTasks() {
        do {
            for task in selectedTasks {
                dailyFocusManager.addTaskToDailyFocus(task)
            }
            try viewContext.save()
            selectedTasks.removeAll()
            ZenFocusLogger.shared.info("Selected tasks added to daily focus successfully")
        } catch {
            ZenFocusLogger.shared.error("Error adding selected tasks to daily focus: \(error.localizedDescription)")
            // Show an alert to the user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error Adding Tasks"
                alert.informativeText = "There was an error adding the selected tasks to today's focus. Please try again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}

struct DailyPlanDropDelegate: DropDelegate {
    let dailyFocusManager: DailyFocusManager
    let viewContext: NSManagedObjectContext
    @Binding var dropTargetIndex: Int?
    @Binding var isDragging: Bool
    @Binding var draggedTask: ZenFocusTask?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.url]).first else {
            ZenFocusLogger.shared.warning("No valid item provider found for drop operation")
            return false
        }
        
        itemProvider.loadObject(ofClass: NSURL.self) { (urlObject, error) in
            if let error = error {
                ZenFocusLogger.shared.error("Error loading dropped object: \(error.localizedDescription)")
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
                        if let currentIndex = self.dailyFocusManager.dailyFocusTasks.firstIndex(of: task),
                           let dropIndex = self.dropTargetIndex {
                            self.dailyFocusManager.reorderDailyFocusTasks(from: IndexSet(integer: currentIndex), to: dropIndex)
                            ZenFocusLogger.shared.info("Task reordered in daily focus: \(task.title ?? "")")
                        }
                    } else {
                        // Dropping from Someday list
                        if let dropIndex = self.dropTargetIndex {
                            self.dailyFocusManager.addTaskToDailyFocus(task, at: dropIndex)
                        } else {
                            self.dailyFocusManager.addTaskToDailyFocus(task)
                        }
                        ZenFocusLogger.shared.info("Task added to daily focus: \(task.title ?? "")")
                    }
                    
                    try self.viewContext.save()
                } catch {
                    ZenFocusLogger.shared.error("Error processing dropped task: \(error.localizedDescription)")
                }
                
                self.dropTargetIndex = nil
                self.isDragging = false
                self.draggedTask = nil
            }
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let location = info.location
        let tasks = dailyFocusManager.dailyFocusTasks
        
        // Assuming each task row is about 50 points tall
        let rowHeight: CGFloat = 50
        let estimatedIndex = Int(location.y / rowHeight)
        
        dropTargetIndex = min(max(estimatedIndex, 0), tasks.count)
        
        return DropProposal(operation: .move)
    }
    
    func dropEntered(info: DropInfo) {
        isDragging = true
        ZenFocusLogger.shared.debug("Drop entered daily focus area")
    }
    
    func dropExited(info: DropInfo) {
        isDragging = false
        dropTargetIndex = nil
        ZenFocusLogger.shared.debug("Drop exited daily focus area")
    }
}

