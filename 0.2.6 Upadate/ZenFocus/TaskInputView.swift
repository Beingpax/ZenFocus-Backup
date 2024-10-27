import SwiftUI
import CoreData

struct TaskInputView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var categoryManager: CategoryManager
    @State private var newTaskTitle = ""
    @FocusState private var isInputFocused: Bool
    @State private var showCategorySuggestions = false
    @State private var currentSuggestions: [String] = []
    @State private var categoryInput = ""
    @State private var showingCategoryManagement = false
    @State private var selectedSuggestionIndex: Int = 0
    @EnvironmentObject var quickFocusManager: QuickAddManager
    var showCategoryManagement: Bool
    var onAddTask: (ZenFocusTask) -> Void

    init(categoryManager: CategoryManager, showCategoryManagement: Bool = true, onAddTask: @escaping (ZenFocusTask) -> Void) {
        self.categoryManager = categoryManager
        self.showCategoryManagement = showCategoryManagement
        self.onAddTask = onAddTask
    }

    var body: some View {
        VStack {
            inputField
            
            if showCategorySuggestions {
                categorySuggestionView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(categoryManager: categoryManager)
        }
    }

    private var inputField: some View {
        HStack(spacing: 12) {
            addIcon
            textField
            submitButton
            if showCategoryManagement {
                categoryManagementButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var addIcon: some View {
        Image(systemName: "plus.circle.fill")
            .foregroundColor(Color.accentColor.opacity(0.8))
            .font(.system(size: 20))
            .frame(width: 24, height: 24)
    }

    private var textField: some View {
        TextField("Add a new task", text: $newTaskTitle)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 16))
            .frame(height: 30)
            .focused($isInputFocused)
            .onSubmit(handleSubmit)
            .onChange(of: newTaskTitle) { newValue in
                handleCategoryInput(newValue)
            }
    }

    private var submitButton: some View {
        Group {
            if !newTaskTitle.isEmpty {
                Button(action: handleSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(Color.accentColor.opacity(0.8))
                        .font(.system(size: 20))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var categoryManagementButton: some View {
        Button(action: { showingCategoryManagement = true }) {
            Image(systemName: "tag")
                .foregroundColor(Color.secondary.opacity(0.7))
                .font(.system(size: 18))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var categorySuggestionView: some View {
        CategorySuggestionView(
            input: $categoryInput,
            onSelect: handleCategorySelection,
            onAddNew: handleNewCategory,
            categoryManager: categoryManager,
            suggestions: currentSuggestions,
            selectedIndex: $selectedSuggestionIndex
        )
        .frame(height: 40)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: showCategorySuggestions)
    }

    private func handleCategoryInput(_ newValue: String) {
        if let atIndex = newValue.lastIndex(of: "@") {
            showCategorySuggestions = true
            categoryInput = String(newValue[newValue.index(after: atIndex)...])
            updateCurrentSuggestions()
            selectedSuggestionIndex = 0
        } else {
            showCategorySuggestions = false
            currentSuggestions = []
        }
    }

    private func updateCurrentSuggestions() {
        if categoryInput.isEmpty {
            currentSuggestions = Array(categoryManager.categories.keys)
        } else {
            currentSuggestions = categoryManager.categories.keys.filter { $0.lowercased().contains(categoryInput.lowercased()) }
        }
    }

    private func handleCategorySelection(_ category: String) {
        if let atIndex = newTaskTitle.lastIndex(of: "@") {
            newTaskTitle = String(newTaskTitle[..<atIndex]) + "@" + category
        }
        showCategorySuggestions = false
        currentSuggestions = []
    }

    private func handleNewCategory(_ newCategory: String) {
        categoryManager.addCategory(newCategory, color: categoryManager.nextPredefinedColor())
        handleCategorySelection(newCategory)
    }

    private func handleSubmit() {
        if showCategorySuggestions && !currentSuggestions.isEmpty {
            handleCategorySelection(currentSuggestions[selectedSuggestionIndex])
        }
        addTask()
    }

    private func addTask(title: String? = nil) {
        let taskTitle = title ?? newTaskTitle
        guard !taskTitle.isEmpty else { return }

        withAnimation {
            let newTask = createTask(with: taskTitle)
            saveTask(newTask)
            if title == nil {
                resetInputState()
            }
        }
    }

    private func createTask() -> ZenFocusTask {
        let newTask = ZenFocusTask(context: viewContext)
        let components = newTaskTitle.split(separator: "@", maxSplits: 1)
        
        newTask.title = String(components[0]).trimmingCharacters(in: .whitespaces)
        newTask.createdAt = Date()
        newTask.isCompleted = false
        
        if components.count > 1 {
            let categoryName = String(components[1]).trimmingCharacters(in: .whitespaces)
            newTask.category = categoryName
            ensureCategoryExists(categoryName)
        }
        
        return newTask
    }

    private func ensureCategoryExists(_ categoryName: String) {
        if !categoryManager.categories.keys.contains(categoryName) {
            categoryManager.addCategory(categoryName, color: categoryManager.nextPredefinedColor())
        }
    }

    private func saveTask(_ task: ZenFocusTask) {
        do {
            try viewContext.save()
            onAddTask(task)
        } catch {
            let nsError = error as NSError
            ZenFocusLogger.shared.error("Unresolved error adding task: \(nsError), \(nsError.userInfo)")
        }
    }

    private func resetInputState() {
        newTaskTitle = ""
        isInputFocused = true
        showCategorySuggestions = false
    }

    func addTask(title: String) {
        guard !title.isEmpty else { return }

        withAnimation {
            let newTask = createTask(with: title)
            saveTask(newTask)
        }
    }

    private func createTask(with title: String) -> ZenFocusTask {
        let newTask = ZenFocusTask(context: viewContext)
        let components = title.split(separator: "@", maxSplits: 1)
        
        newTask.title = String(components[0]).trimmingCharacters(in: .whitespaces)
        newTask.createdAt = Date()
        newTask.isCompleted = false
        
        if components.count > 1 {
            let categoryName = String(components[1]).trimmingCharacters(in: .whitespaces)
            newTask.category = categoryName
            ensureCategoryExists(categoryName)
        }
        
        return newTask
    }
}
