import SwiftUI

struct TextFieldPositionKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ZenFocusTask.createdAt, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == NO AND isInDailyFocus == NO"),
        animation: .default)
    private var tasks: FetchedResults<ZenFocusTask>
    
    @ObservedObject var categoryManager: CategoryManager
    @ObservedObject var dailyFocusManager: DailyFocusManager
    @State private var showingCategoryManagement = false
    
    @EnvironmentObject var windowManager: WindowManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeaderView(title: "Someday", icon: "list.bullet", color: .blue)
                .padding(.bottom, 8)
            
            taskList
            
            TaskInputView(categoryManager: categoryManager) { newTask in
                // Handle the new task if needed
            }
        }
        .frame(minWidth: 350)
        .padding()
    
        .cornerRadius(12)
        .onDrop(of: [.url], delegate: TaskListDropDelegate(viewContext: viewContext, dailyFocusManager: dailyFocusManager))
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(categoryManager: categoryManager)
        }
    }
    
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskRow(task: task, categoryManager: categoryManager, dailyFocusManager: dailyFocusManager, onDelete: {
                        deleteTask(task)
                    }, onStartFocus: { focusedTask in
                        windowManager.showFocusedTaskWindow(
                            for: focusedTask,
                            dailyFocusManager: dailyFocusManager,
                            onComplete: { completedTask in
                                // Handle task completion
                            },
                            onBreak: {
                                // Handle break
                            }
                        )
                    })
                }
            }
            .padding(.horizontal)
        }
    }

    private func deleteTask(_ task: ZenFocusTask) {
        withAnimation {
            viewContext.delete(task)
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                ZenFocusLogger.shared.error("Error deleting task: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct TaskListDropDelegate: DropDelegate {
    let viewContext: NSManagedObjectContext
    let dailyFocusManager: DailyFocusManager
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.url]).first else { return false }
        
        itemProvider.loadObject(ofClass: NSURL.self) { (urlObject, error) in
            guard let url = urlObject as? URL,
                  let objectID = self.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
                  let task = try? self.viewContext.existingObject(with: objectID) as? ZenFocusTask else {
                return
            }
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.dailyFocusManager.removeTaskFromDailyFocus(task)
                }
            }
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
