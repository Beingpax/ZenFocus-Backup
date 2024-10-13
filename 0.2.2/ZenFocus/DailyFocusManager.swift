import Foundation
import CoreData

class DailyFocusManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    @Published var dailyFocusTasks: [ZenFocusTask] = []

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadDailyFocusTasks()
    }
    
    private func loadDailyFocusTasks() {
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "isInDailyFocus == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ZenFocusTask.dailyFocusOrder, ascending: true)]
        
        do {
            dailyFocusTasks = try viewContext.fetch(request)
        } catch {
            ZenFocusLogger.shared.error("Error loading daily focus tasks: \(error)")
        }
    }
    
    func addTaskToDailyFocus(_ task: ZenFocusTask, at index: Int? = nil) {
        task.isInDailyFocus = true
        if let index = index {
            dailyFocusTasks.insert(task, at: min(index, dailyFocusTasks.count))
        } else {
            dailyFocusTasks.append(task)
        }
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
        saveContext()
    }
    
    func reorderDailyFocusTasks(from source: IndexSet, to destination: Int) {
        DispatchQueue.main.async {
            self.dailyFocusTasks.move(fromOffsets: source, toOffset: destination)
            self.updateDailyFocusOrder()
            self.saveContext()
        }
    }
    
    func resetDailyFocus() {
        for task in dailyFocusTasks {
            task.isInDailyFocus = false
            task.dailyFocusOrder = 0
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
        
        loadDailyFocusTasks()
    }
    
    private func saveContext() {
        do {
            if self.viewContext.hasChanges {
                try self.viewContext.save()
            }
        } catch {
            ZenFocusLogger.shared.error("Error saving context: \(error)")
            // Optionally, you can add more robust error handling here
        }
    }
    
    func completeTask(_ task: ZenFocusTask) {
        task.isCompleted = true
        task.completedAt = Date()
        if task.isInDailyFocus {
            removeTaskFromDailyFocus(task)
        }
        saveContext()
    }
}