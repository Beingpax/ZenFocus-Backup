import Foundation
import CoreData

class DailyFocusManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    @Published var dailyFocusTasks: [ZenFocusTask] = []
    @Published var availableTasks: [ZenFocusTask] = []

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadTasks()
    }
    
    private func loadTasks() {
        loadDailyFocusTasks()
        loadAvailableTasks()
    }
    
    private func loadDailyFocusTasks() {
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "isInDailyFocus == YES AND isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ZenFocusTask.dailyFocusOrder, ascending: true)]
        
        do {
            dailyFocusTasks = try viewContext.fetch(request)
        } catch {
            ZenFocusLogger.shared.error("Error loading daily focus tasks: \(error)")
        }
    }
    
    private func loadAvailableTasks() {
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "isInDailyFocus == NO AND isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ZenFocusTask.createdAt, ascending: true)]
        
        do {
            availableTasks = try viewContext.fetch(request)
        } catch {
            ZenFocusLogger.shared.error("Error loading available tasks: \(error)")
        }
    }
    
    func addTaskToDailyFocus(_ task: ZenFocusTask, at index: Int? = nil) {
        task.isInDailyFocus = true
        if let index = index {
            dailyFocusTasks.insert(task, at: min(index, dailyFocusTasks.count))
        } else {
            dailyFocusTasks.append(task)
        }
        availableTasks.removeAll { $0 == task }
        updateDailyFocusOrder()
        saveContext()
    }
    
    private func updateDailyFocusOrder() {
        for (index, task) in dailyFocusTasks.enumerated() {
            task.dailyFocusOrder = Int32(index)
        }
    }
    
    func removeTaskFromDailyFocus(_ task: ZenFocusTask) {
        task.isInDailyFocus = false
        task.dailyFocusOrder = 0
        dailyFocusTasks.removeAll { $0 == task }
        availableTasks.append(task)
        saveContext()
    }
    
    func reorderDailyFocusTasks(from source: IndexSet, to destination: Int) {
        dailyFocusTasks.move(fromOffsets: source, toOffset: destination)
        updateDailyFocusOrder()
        saveContext()
    }
    
    func resetDailyFocus() {
        for task in dailyFocusTasks {
            task.isInDailyFocus = false
            task.dailyFocusOrder = 0
            availableTasks.append(task)
        }
        dailyFocusTasks.removeAll()
        saveContext()
    }
    
    func checkAndResetDailyFocus() {
        let calendar = Calendar.current
        let now = Date()
        
        if let lastResetDate = UserDefaults.standard.object(forKey: "lastDailyFocusResetDate") as? Date {
            if !calendar.isDate(lastResetDate, inSameDayAs: now) {
                resetDailyFocus()
                UserDefaults.standard.set(now, forKey: "lastDailyFocusResetDate")
            }
        } else {
            UserDefaults.standard.set(now, forKey: "lastDailyFocusResetDate")
        }
        
        loadTasks()
    }
    
    private func saveContext() {
        do {
            if self.viewContext.hasChanges {
                try self.viewContext.save()
            }
        } catch {
            ZenFocusLogger.shared.error("Error saving context: \(error)")
        }
    }
    
    func completeTask(_ task: ZenFocusTask) {
        task.isCompleted = true
        task.completedAt = Date()
        if task.isInDailyFocus {
            dailyFocusTasks.removeAll { $0 == task }
        } else {
            availableTasks.removeAll { $0 == task }
        }
        saveContext()
        
        // Reload tasks to ensure the UI is updated
        loadTasks()
    }

    // Add this new method to handle task completion from the UI
    func toggleTaskCompletion(_ task: ZenFocusTask) {
        if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
            if task.isInDailyFocus {
                dailyFocusTasks.append(task)
            } else {
                availableTasks.append(task)
            }
        } else {
            completeTask(task)
        }
        saveContext()
        
        // Reload tasks to ensure the UI is updated
        loadTasks()
    }
    
    func addNewTask(_ task: ZenFocusTask, toDailyFocus: Bool = false) {
        if toDailyFocus {
            addTaskToDailyFocus(task)
        } else {
            availableTasks.append(task)
        }
        saveContext()
    }
    
    func deleteTask(_ task: ZenFocusTask) {
        if task.isInDailyFocus {
            dailyFocusTasks.removeAll { $0 == task }
        } else {
            availableTasks.removeAll { $0 == task }
        }
        viewContext.delete(task)
        saveContext()
    }
}