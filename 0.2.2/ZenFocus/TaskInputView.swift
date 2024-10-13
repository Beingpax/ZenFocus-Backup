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

    var onAddTask: (ZenFocusTask) -> Void

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .font(.system(size: 20))
                    .frame(width: 24, height: 24)
                
                TextField("Add a new task", text: $newTaskTitle)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16))
                    .frame(height: 30)
                    .focused($isInputFocused)
                    .onSubmit(handleSubmit)
                    .onChange(of: newTaskTitle) { newValue in
                        handleCategoryInput(newValue)
                    }
                
                if !newTaskTitle.isEmpty {
                    Button(action: handleSubmit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(Color.accentColor.opacity(0.8))
                            .font(.system(size: 20))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: { showingCategoryManagement = true }) {
                    Image(systemName: "tag")
                        .foregroundColor(Color.secondary.opacity(0.7))
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
            
            if showCategorySuggestions {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(categoryManager: categoryManager)
        }
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

    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }

        withAnimation {
            let newTask = ZenFocusTask(context: viewContext)
            
            let components = newTaskTitle.split(separator: "@", maxSplits: 1)
            newTask.title = String(components[0]).trimmingCharacters(in: .whitespaces)
            
            if components.count > 1 {
                let categoryName = String(components[1]).trimmingCharacters(in: .whitespaces)
                newTask.category = categoryName
                if !categoryManager.categories.keys.contains(categoryName) {
                    categoryManager.addCategory(categoryName, color: categoryManager.nextPredefinedColor())
                }
            }
            
            newTask.createdAt = Date()
            newTask.isCompleted = false
            newTask.isInDailyFocus = false

            do {
                try viewContext.save()
                onAddTask(newTask)
                newTaskTitle = ""
                isInputFocused = true
                showCategorySuggestions = false
            } catch {
                let nsError = error as NSError
                ZenFocusLogger.shared.error("Unresolved error adding task: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}