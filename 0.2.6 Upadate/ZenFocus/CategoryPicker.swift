import SwiftUI
import CoreData

struct CategoryPicker: View {
    @Binding var input: String
    let onSelect: (String) -> Void
    let onAddNew: (String) -> Void
    @ObservedObject var categoryManager: CategoryManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filteredCategories, id: \.self) { category in
                    Text(category)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryManager.colorForCategory(category).opacity(0.2))
                        .foregroundColor(categoryManager.colorForCategory(category))
                        .cornerRadius(4)
                        .onTapGesture {
                            onSelect(category)
                        }
                }
                
                if !input.isEmpty && !filteredCategories.contains(input) {
                    Text(input)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                        .onTapGesture {
                            onAddNew(input)
                        }
                }
            }
        }
        .frame(height: 30)
    }
    
    private var filteredCategories: [String] {
        if input.isEmpty {
            return Array(categoryManager.categories.keys)
        } else {
            return categoryManager.categories.keys.filter { $0.lowercased().contains(input.lowercased()) }
        }
    }
}