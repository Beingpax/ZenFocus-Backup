import SwiftUI

struct EditingCategory: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
}

struct CategoryManagementView: View {
    @ObservedObject var categoryManager: CategoryManager
    @State private var editingCategory: EditingCategory?
    @State private var isAddingNewCategory = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showingColorPicker = false
    @State private var selectedColor: Color = .blue
    
    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            categoriesGrid
            footerSection
        }
        .padding()
        .frame(width: 600, height: 450)
        .background(Color(.windowBackgroundColor))
        .sheet(item: $editingCategory) { category in
            CategoryEditView(
                categoryManager: categoryManager,
                categoryName: category.name,
                categoryColor: category.color
            ) {
                editingCategory = nil
            }
        }
        .sheet(isPresented: $isAddingNewCategory) {
            AddCategoryView(categoryManager: categoryManager, selectedColor: $selectedColor) {
                isAddingNewCategory = false
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Text("Manage Categories")
                .font(.headline)
            
            Spacer()
            
            Button(action: { isAddingNewCategory = true }) {
                Label("Add Category", systemImage: "plus")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var categoriesGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(categoryManager.categories.keys.sorted()), id: \.self) { category in
                    CategoryCard(category: category, color: categoryManager.categories[category] ?? .blue) {
                        editingCategory = EditingCategory(name: category, color: categoryManager.categories[category] ?? .blue)
                    } onDelete: {
                        categoryManager.deleteCategory(category)
                    }
                }
            }
        }
    }
    
    private var footerSection: some View {
        Text("Tip: Add categories to tasks by typing '@' followed by the category name.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top)
    }
}

struct AddCategoryView: View {
    @ObservedObject var categoryManager: CategoryManager
    @State private var newCategoryName = ""
    @Binding var selectedColor: Color
    @Environment(\.presentationMode) var presentationMode
    @State private var showingColorPicker = false
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Category")
                .font(.headline)
            
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category name", text: $newCategoryName)
                    
                    ColorPicker("Category Color", selection: $selectedColor)
                }
                
                Section(header: Text("Preset Colors")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 10) {
                        ForEach(CategoryManager.predefinedColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary, lineWidth: 2).opacity(selectedColor == color ? 1 : 0))
                                .onTapGesture { selectedColor = color }
                        }
                    }
                }
            }
            .formStyle(GroupedFormStyle())
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    if !newCategoryName.isEmpty {
                        categoryManager.addCategory(newCategoryName, color: selectedColor)
                        presentationMode.wrappedValue.dismiss()
                        onDismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCategoryName.isEmpty)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 350, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

struct ColorSelectionView: View {
    @Binding var selectedColor: Color
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 10) {
            ForEach(CategoryManager.predefinedColors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2).opacity(selectedColor == color ? 1 : 0))
                    .onTapGesture { selectedColor = color }
            }
        }
    }
}

struct CategoryCard: View {
    let category: String
    let color: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                Text(category)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            
            HStack {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline)
                        .foregroundColor(color)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
                
                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 4)
                
        )
        .padding(2)
    }
}

struct CategoryEditView: View {
    @ObservedObject var categoryManager: CategoryManager
    let categoryName: String
    @State private var newCategoryName: String
    @State private var categoryColor: Color
    @Environment(\.presentationMode) var presentationMode
    let onDismiss: () -> Void
    
    init(categoryManager: CategoryManager, categoryName: String, categoryColor: Color, onDismiss: @escaping () -> Void) {
        self.categoryManager = categoryManager
        self.categoryName = categoryName
        self._newCategoryName = State(initialValue: categoryName)
        self._categoryColor = State(initialValue: categoryColor)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Category")
                .font(.headline)
            
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category name", text: $newCategoryName)
                    
                    ColorPicker("Category Color", selection: $categoryColor)
                }
                
                Section(header: Text("Preset Colors")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 10) {
                        ForEach(CategoryManager.predefinedColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary, lineWidth: 2).opacity(categoryColor == color ? 1 : 0))
                                .onTapGesture { categoryColor = color }
                        }
                    }
                }
            }
            .formStyle(GroupedFormStyle())
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    if !newCategoryName.isEmpty {
                        updateCategory(categoryName, newName: newCategoryName, color: categoryColor)
                        presentationMode.wrappedValue.dismiss()
                        onDismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCategoryName.isEmpty)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 350, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }

    private func updateCategory(_ oldName: String, newName: String, color: Color) {
        categoryManager.updateCategory(oldName, newName: newName, color: color)
    }
}


