import SwiftUI
import CoreData

struct BetterTaskRow: View {
    @ObservedObject var task: ZenFocusTask
    @ObservedObject var categoryManager: CategoryManager
    @EnvironmentObject var windowManager: WindowManager
    var onDelete: (() -> Void)?  // Optional closure for delete action
   
    
    @State private var isPaused: Bool = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            
            Button(action: toggleCompletion) {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? Color.green : Color.secondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 18, height: 18)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 18, height: 18)
                    }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: task.isCompleted)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(task.isCompleted ? "Mark as incomplete" : "Mark as complete")
            
            
            Text(task.title ?? "")
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            if task.focusedDuration > 0 {
                Text(formatDuration(task.focusedDuration))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isPaused ? .secondary : .primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isPaused ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            
            if let category = task.category {
                categoryPill(category)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Color.clear)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle()) // This makes the entire row tappable
        .contextMenu {
            if let onDelete = onDelete {  // Only show delete button if onDelete is provided
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Text("Delete")
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete Task"),
                message: Text("Are you sure you want to delete this task?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete?()
                },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskPauseStateChanged)) { notification in
            if let taskID = notification.userInfo?["taskID"] as? NSManagedObjectID,
               let pauseState = notification.userInfo?["isPaused"] as? Bool,
               taskID == task.objectID {
                isPaused = pauseState
            }
        }
    }
    
    private func categoryPill(_ category: String) -> some View {
        Text(category)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(categoryManager.colorForCategory(category))
            .foregroundColor(CategoryManager.textColor)
            .cornerRadius(6)
    }
    
    private func toggleCompletion() {
        withAnimation {
            task.isCompleted.toggle()
            if task.isCompleted {
                task.completedAt = Date()
                NotificationCenter.default.post(name: .taskCompleted, object: nil)
            } else {
                task.completedAt = nil
            }
            try? task.managedObjectContext?.save()
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}


