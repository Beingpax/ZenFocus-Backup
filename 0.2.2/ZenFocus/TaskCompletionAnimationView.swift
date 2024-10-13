import SwiftUI
import CoreData

struct TaskCompletionAnimationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var windowManager: WindowManager
    @ObservedObject var dailyFocusManager: DailyFocusManager
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5
    @State private var containerRotation: Double = 0
    @State private var trophyRotation: Double = 0
    @State private var showMessage: Bool = false
    @State private var messageOpacity: Double = 0
    @State private var showNextTaskInfo: Bool = false
    let completedTask: ZenFocusTask
    let onStartNextTask: (ZenFocusTask) -> Void
    let onDismiss: () -> Void
    
    @AppStorage("userName") private var userName = "Pax"
    
    let hypeMessages = [
        "You're crushing it today!",
        "You're a task-slaying machine!",
        "High five for getting it done!",
        "You're making it happen!",
        "You're being unstoppable!",
        "You're on fire today!",
        "You're smashing goals like a boss!",
        "You're in the zone!",
        "You're a productivity powerhouse!",
        "You're moving closer to your goal!",
        "You're making magic happen!",
        "You're knocking tasks out of the park!",
        "You're a to-do list terminator!",
        "You're blazing through your tasks!",
        "You're a task-tackling titan!",
        "You're crushing goals left and right!",
        "You're in beast mode!",
        "You're a to-do list conqueror!",
        "You're making it look easy!",
    ]
    
    @State private var currentHypeMessage: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RadialGradient(gradient: Gradient(colors: [Color.purple.opacity(0.5), Color.black]), center: .center, startRadius: 100, endRadius: 300)
                    .edgesIgnoringSafeArea(.all)
                    .opacity(opacity)
                
                VStack(spacing: 30) {
                    if !showNextTaskInfo {
                        completionAnimation
                    } else {
                        nextTaskInfo
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .opacity(opacity)
        .onAppear {
            currentHypeMessage = hypeMessages.randomElement() ?? "Great job!"
            animateCompletion()
        }
    }
    
    private var completionAnimation: some View {
        VStack(spacing: 30) {
            Text("Great job, \(userName)!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .opacity(opacity)
            
            Text(currentHypeMessage)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(opacity)
            
            ZStack {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(Double(i) * 60))
                        .opacity(0.8)
                }
                
                Image(systemName: "trophy.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.yellow)
                    .rotationEffect(.degrees(trophyRotation))
            }
            .rotationEffect(.degrees(containerRotation))
            .scaleEffect(scale)
            
            if showMessage {
                Text(completedTask.title ?? "")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(messageOpacity)
                
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.green)
                    .opacity(messageOpacity)
            }
        }
    }
    
    private var nextTaskInfo: some View {
        VStack(spacing: 30) {
            Text("Task Completed!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            completedTaskInfo
            
            if let nextTask = getNextTask() {
                nextTaskView(for: nextTask)
            } else {
                Text("All tasks completed for today. Great job!")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    windowManager.showMainWindowWithAnimation()
                    onDismiss()
                }) {
                    Text("Return to Main View")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                if let nextTask = getNextTask() {
                    Button(action: { onStartNextTask(nextTask) }) {
                        Text("Start Next Task")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top)
        }
        .padding()
    }
    
    private var completedTaskInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Completed Task:")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            
            Text(completedTask.title ?? "")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if let category = completedTask.category {
                Text("Category: \(category)")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("Time Spent: \(formatDuration(completedTask.focusedDuration))")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func nextTaskView(for task: ZenFocusTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next Task:")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            
            Text(task.title ?? "")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if let category = task.category {
                Text("Category: \(category)")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func animateCompletion() {
        withAnimation(.easeIn(duration: 0.3)) {
            opacity = 1
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0.6)) {
            scale = 1
        }
        
        withAnimation(.easeInOut(duration: 2)) {
            containerRotation = 360
            trophyRotation = 360
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 2.0)) {
                containerRotation = 720
                trophyRotation = 720
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                showMessage = true
                messageOpacity = 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeInOut(duration: 0.7)) {
                showNextTaskInfo = true
            }
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private func getNextTask() -> ZenFocusTask? {
        return dailyFocusManager.dailyFocusTasks.first { !$0.isCompleted && $0.objectID != completedTask.objectID }
    }
}
