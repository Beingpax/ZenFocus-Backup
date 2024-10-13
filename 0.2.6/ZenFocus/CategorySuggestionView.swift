import SwiftUI

struct CategorySuggestionView: View {
    @Binding var input: String
    let onSelect: (String) -> Void
    let onAddNew: (String) -> Void
    @ObservedObject var categoryManager: CategoryManager
    let suggestions: [String]
    @Binding var selectedIndex: Int  
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(suggestions.enumerated()), id: \.element) { index, category in
                    Button(action: { onSelect(category) }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(categoryManager.colorForCategory(category))
                                .frame(width: 12, height: 12)
                            Text(category)
                                .foregroundColor(.primary)
                                .font(.system(size: 16))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if !input.isEmpty && !suggestions.contains(input) {
                    Button(action: { onAddNew(input) }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add: \(input)")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 50)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
    }
}
