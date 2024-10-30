import SwiftUI
import CoreData

struct CompletedTasksHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ZenFocusTask.completedAt, ascending: false)],
        predicate: NSPredicate(format: "isCompleted == YES"),
        animation: .default)
    private var completedTasks: FetchedResults<ZenFocusTask>
    
    @State private var selectedTask: ZenFocusTask?
    @State private var groupedTasks: [(key: Date, value: [Date: [ZenFocusTask]])] = []
    @State private var visibleMonths: Set<Date> = []
    
    var body: some View {
           ZStack {
               Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)
               
               VStack(spacing: 0) {
                   todayTasksHeader
                   
                   ScrollViewReader { proxy in
                       List {
                           ForEach(groupedTasks, id: \.key) { month, dateGroups in
                               Section(header: monthHeader(for: month)) {
                                   ForEach(dateGroups.keys.sorted(by: >), id: \.self) { date in
                                       DateSection(date: date, tasks: dateGroups[date] ?? [], selectedTask: $selectedTask, onDelete: deleteTask)
                                   }
                               }
                               .id(month)
                           }
                       }
                       .listStyle(PlainListStyle())
                       .background(Color.clear)
                       .scrollContentBackground(.hidden)
                       .onAppear {
                           groupTasks()
                       }
                       .onChange(of: completedTasks.count) { _ in
                           groupTasks()
                       }
                   }
               }
               .background(Color(NSColor.controlBackgroundColor))
               .cornerRadius(12)
               .padding(20)
               .overlay(
                   Group {
                       if let task = selectedTask {
                           TaskDetailView(task: task, isPresented: Binding(
                               get: { selectedTask != nil },
                               set: { if !$0 { selectedTask = nil } }
                           ), onDelete: {
                               deleteTask(task)
                               selectedTask = nil
                           })
                       }
                   }
               )
               
           }
           
       }
       
       
        
        private var todayTasksHeader: some View {
            HStack {
                CardHeaderView(title: "Completed Tasks", icon: "checkmark.circle", color: .green)

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(NSColor.separatorColor)),
                alignment: .bottom
            )
        }
    
    private func monthHeader(for date: Date) -> some View {
        Text(date, formatter: monthFormatter)
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
    }
    
    private func groupTasks() {
        let calendar = Calendar.current
        let groupedByDate = Dictionary(grouping: completedTasks) { task in
            calendar.startOfDay(for: task.completedAt ?? Date())
        }
        
        let groupedByMonth = Dictionary(grouping: groupedByDate.keys) { date in
            calendar.startOfMonth(for: date)
        }.mapValues { dates in
            Dictionary(uniqueKeysWithValues: dates.map { date in (date, groupedByDate[date]!) })
        }
        
        groupedTasks = groupedByMonth.sorted { $0.key > $1.key }
    }
    
    private func deleteTask(_ task: ZenFocusTask) {
        viewContext.delete(task)
        do {
            try viewContext.save()
        } catch {
            ZenFocusLogger.shared.error("Error deleting task: \(error)")
        }
    }
}

struct DateSection: View {
    let date: Date
    let tasks: [ZenFocusTask]
    @Binding var selectedTask: ZenFocusTask?
    let onDelete: (ZenFocusTask) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                TimelineNode(color: .accentColor, size: 16, lineWidth: 4)
                    .frame(width: 30)
                Text(date, style: .date)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding(.vertical, 12)
            
            ForEach(tasks.sorted(by: { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) })) { task in
                HStack(spacing: 0) {
                    TimelineConnector()
                        .frame(width: 30)
                    CompletedTaskRow(task: task, isSelected: Binding(
                        get: { selectedTask == task },
                        set: { if $0 { selectedTask = task } else if selectedTask == task { selectedTask = nil } }
                    ))
                }
            }
            
            if tasks.isEmpty {
                TimelineConnector(isEmpty: true)
                    .frame(width: 30)
            }
        }
    }
}

struct TimelineNode: View {
    var color: Color
    var size: CGFloat
    var lineWidth: CGFloat
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: lineWidth)
                    .frame(width: size + lineWidth, height: size + lineWidth)
            )
    }
}

struct TimelineConnector: View {
    var isEmpty: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 2)
                .frame(height: isEmpty ? 40 : 20)
            
            if !isEmpty {
                TimelineNode(color: .accentColor.opacity(0.5), size: 8, lineWidth: 2)
                
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 2)
                    .frame(height: 20)
            }
        }
    }
}

struct CompletedTaskRow: View {
    let task: ZenFocusTask
    @Binding var isSelected: Bool
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title ?? "")
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                    Text(formatDuration(task.focusedDuration))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                if let category = task.category {
                    CategoryPill(category: category)
                }
                
                Spacer()
                
                Text((task.completedAt ?? Date()).formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color.gray.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.gray.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onTapGesture {
            isSelected.toggle()
        }
        .onHover { hovering in
            isHovered = hovering
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

struct CategoryPill: View {
    let category: String
    
    var body: some View {
        Text(category)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.2))
            .foregroundColor(.blue)
            .cornerRadius(8)
    }
}

struct TaskDetailView: View {
    let task: ZenFocusTask
    @Binding var isPresented: Bool
    let onDelete: () -> Void
    @Environment(\.managedObjectContext) private var viewContext
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 20
    @State private var showingDeleteConfirmation = false
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedCategory: String = ""
    @State private var editedCompletedAt: Date = Date()
    @State private var editedCreatedAt: Date = Date()
    @State private var editedScheduledDate: Date?
    @State private var editedFocusedDurationMinutes: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 20) {
                    if isEditing {
                        editableContent
                    } else {
                        header
                        content
                    }
                    Spacer()
                    
                    HStack {
                        deleteButton
                        Spacer()
                        editButton
                    }
                }
                .frame(width: min(350, geometry.size.width * 0.9))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .offset(x: isPresented ? 0 : geometry.size.width)
                
                closeButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .opacity(opacity)
        .onAppear(perform: startAnimation)
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete Task"),
                message: Text("Are you sure you want to delete this task? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var editableContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Task Title", text: $editedTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Category", text: $editedCategory)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            DatePicker("Completed At", selection: $editedCompletedAt, displayedComponents: [.date, .hourAndMinute])
            
            DatePicker("Created At", selection: $editedCreatedAt, displayedComponents: [.date, .hourAndMinute])
            
            DatePicker("Scheduled Date", selection: Binding(
                get: { self.editedScheduledDate ?? Date() },
                set: { self.editedScheduledDate = $0 }
            ), displayedComponents: [.date])
            
            Toggle("Has Scheduled Date", isOn: Binding(
                get: { self.editedScheduledDate != nil },
                set: { if !$0 { self.editedScheduledDate = nil } }
            ))
            
            HStack {
                Text("Focus Duration:")
                TextField("Duration", value: $editedFocusedDurationMinutes, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("minutes")
            }
            
            Button(action: saveChanges) {
                Text("Save Changes")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var deleteButton: some View {
        Button(action: {
            showingDeleteConfirmation = true
        }) {
            Text("Delete")
                .fontWeight(.medium)
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var editButton: some View {
        Button(action: {
            isEditing.toggle()
            if !isEditing {
                initializeEditableFields()
            }
        }) {
            Text(isEditing ? "Cancel" : "Edit")
                .fontWeight(.medium)
                .foregroundColor(isEditing ? .secondary : .accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isEditing ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func initializeEditableFields() {
        editedTitle = task.title ?? ""
        editedCategory = task.category ?? ""
        editedCompletedAt = task.completedAt ?? Date()
        editedCreatedAt = task.createdAt ?? Date()
        editedScheduledDate = task.scheduledDate
        editedFocusedDurationMinutes = task.focusedDuration / 60
    }
    
    private func saveChanges() {
        task.title = editedTitle
        task.category = editedCategory
        task.completedAt = editedCompletedAt
        task.createdAt = editedCreatedAt
        task.scheduledDate = editedScheduledDate
        task.focusedDuration = editedFocusedDurationMinutes * 60
        
        do {
            try viewContext.save()
            isEditing = false
        } catch {
            ZenFocusLogger.shared.error("Error saving edited task: \(error)")
        }
    }
    
    private var header: some View {
        HStack {
            Text(task.title ?? "")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(2)
            Spacer()
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(icon: "checkmark.circle.fill", title: "Completed", value: (task.completedAt ?? Date()).formatted(date: .long, time: .shortened))
            detailRow(icon: "clock.fill", title: "Focus Duration", value: formatDuration(task.focusedDuration))
            if let category = task.category {
                detailRow(icon: "tag.fill", title: "Category", value: category)
            }
            detailRow(icon: "calendar", title: "Created", value: (task.createdAt ?? Date()).formatted(date: .long, time: .shortened))
            if let scheduledDate = task.scheduledDate {
                detailRow(icon: "calendar.badge.clock", title: "Scheduled", value: scheduledDate.formatted(date: .long, time: .omitted))
            }
        }
    }
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
        }
    }
    
    private var closeButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                opacity = 0
                offset = 20
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPresented = false
            }
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(8)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return String(format: "%d hours %d minutes", hours, minutes)
        } else {
            return String(format: "%d minutes", minutes)
        }
    }
    
    private func startAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            opacity = 1
            offset = 0
        }
        initializeEditableFields()
    }
}

private let monthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
}()

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}


// Preview
struct CompletedTasksHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        // Create some sample completed tasks
        for i in 0..<20 {
            let task = ZenFocusTask(context: context)
            task.title = "Completed Task \(i + 1)"
            task.isCompleted = true
            task.completedAt = Date().addingTimeInterval(TimeInterval(-i * 86400)) // Completed over the last 20 days
            task.category = ["Work", "Personal", "Study"][i % 3]
            task.focusedDuration = Double((i + 1) * 600) // 10 minutes * (i + 1)
        }
        
        return CompletedTasksHistoryView()
            .environment(\.managedObjectContext, context)
            .previewLayout(.sizeThatFits)
            .padding()
            .frame(height: 600)
    }
}