import SwiftUI
import CoreData
import AppKit

/// Manages categories for tasks in the ZenFocus app.
class CategoryManager: ObservableObject {
    /// The Core Data managed object context.
    let viewContext: NSManagedObjectContext
    
    /// A dictionary of categories and their associated colors.
    @Published var categories: [String: Color] = [:]
    
    static let predefinedColors: [Color] = [
        Color(red: 0.65, green: 0.95, blue: 0.75),  // Mint Green
        Color(red: 0.65, green: 0.75, blue: 0.95),  // Ocean Blue
        Color(red: 0.95, green: 0.95, blue: 0.65),  // Sunshine Yellow
        Color(red: 0.75, green: 0.65, blue: 0.95),  // Lavender Purple
        Color(red: 0.65, green: 0.95, blue: 0.95),  // Aqua Cyan
        Color(red: 0.95, green: 0.75, blue: 0.65),  // Peach Orange
        Color(red: 0.75, green: 0.95, blue: 0.65),  // Lime Green
        Color(red: 0.65, green: 0.85, blue: 0.95),  // Sky Blue
        Color(red: 0.95, green: 0.65, blue: 0.75),  // Rose Pink
        Color(red: 0.85, green: 0.70, blue: 0.50),  // Terracotta
        Color(red: 0.50, green: 0.85, blue: 0.70),  // Teal Green
        Color(red: 0.70, green: 0.50, blue: 0.85),  // Amethyst Purple
        Color(red: 0.85, green: 0.85, blue: 0.50),  // Pale Gold
        Color(red: 0.50, green: 0.85, blue: 0.85),  // Turquoise
        Color(red: 0.85, green: 0.50, blue: 0.50),  // Coral Red
        Color(red: 0.50, green: 0.70, blue: 0.85),  // Slate Blue
        Color(red: 0.85, green: 0.65, blue: 0.50),  // Amber
        Color(red: 0.70, green: 0.85, blue: 0.50),  // Olive Green
        Color(red: 0.85, green: 0.50, blue: 0.70),  // Magenta
    ]

    static let textColor = Color.black  // Black text for better contrast

    private var colorIndex = 0

    /// Initializes a new CategoryManager with the given managed object context.
    /// - Parameter viewContext: The Core Data managed object context to use.
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadCategories()
    }
    
    func loadCategories() {
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "category != nil")
        
        do {
            let tasks = try viewContext.fetch(request)
            let uniqueCategories = Set(tasks.compactMap { $0.category })
            categories = [:]
            for category in uniqueCategories {
                if let colorComponents = UserDefaults.standard.array(forKey: "category_color_\(category)") as? [CGFloat],
                   colorComponents.count == 4 {
                    categories[category] = Color(red: colorComponents[0], green: colorComponents[1], blue: colorComponents[2], opacity: colorComponents[3])
                } else {
                    categories[category] = nextPredefinedColor()
                }
            }
        } catch {
            print("Error loading categories: \(error)")
        }
    }
    
    func addCategory(_ name: String, color: Color? = nil) {
        if !categories.keys.contains(name) {
            let newColor = color ?? nextPredefinedColor()
            categories[name] = newColor
            saveColorForCategory(name, color: newColor)
            objectWillChange.send()
        }
    }
    
    func updateCategory(_ name: String, newName: String, color: Color) {
        categories.removeValue(forKey: name)
        categories[newName] = color
        saveColorForCategory(newName, color: color)
        
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", name)
        
        do {
            let tasks = try viewContext.fetch(request)
            for task in tasks {
                task.category = newName
            }
            try viewContext.save()
            objectWillChange.send()
        } catch {
            print("Error updating category: \(error)")
        }
    }
    
    func deleteCategory(_ name: String) {
        categories.removeValue(forKey: name)
        UserDefaults.standard.removeObject(forKey: "category_color_\(name)")
        
        let request: NSFetchRequest<ZenFocusTask> = ZenFocusTask.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", name)
        
        do {
            let tasks = try viewContext.fetch(request)
            for task in tasks {
                task.category = nil
            }
            try viewContext.save()
            objectWillChange.send()
        } catch {
            print("Error deleting category: \(error)")
        }
    }
    
    func colorForCategory(_ name: String) -> Color {
        if let color = categories[name] {
            return color
        } else {
            let newColor = nextPredefinedColor()
            categories[name] = newColor
            saveColorForCategory(name, color: newColor)
            return newColor
        }
    }
    
    private func saveColorForCategory(_ name: String, color: Color) {
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        UserDefaults.standard.set(components, forKey: "category_color_\(name)")
    }
    
    public func nextPredefinedColor() -> Color {
        let color = Self.predefinedColors[colorIndex]
        colorIndex = (colorIndex + 1) % Self.predefinedColors.count
        return color
    }
}
