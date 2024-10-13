import SwiftUI
import AVFoundation
import CoreData

struct BreakTimerView: View {
    @Binding var breakTimeRemaining: Int
    @Binding var showBreakTimer: Bool
    let onStartNextTask: () -> Void
    let onDismissAll: () -> Void
    let viewContext: NSManagedObjectContext
    
    @State private var timer: Timer?
    @State private var showEndBreakAlert: Bool = false
    @State private var isBreakPaused: Bool = false
    @State private var isBreakCompleted: Bool = false
    
    @State private var initialBreakTime: Int
    @State private var progress: CGFloat = 0

    @Binding var dismissing: Bool

    @EnvironmentObject var windowManager: WindowManager
    
    @State private var errorMessage: String?
    @State private var audioPlayer: AVAudioPlayer?
    
    init(breakTimeRemaining: Binding<Int>, showBreakTimer: Binding<Bool>, onStartNextTask: @escaping () -> Void, onDismissAll: @escaping () -> Void, viewContext: NSManagedObjectContext, dismissing: Binding<Bool>) {
        self._breakTimeRemaining = breakTimeRemaining
        self._showBreakTimer = showBreakTimer
        self.onStartNextTask = onStartNextTask
        self.onDismissAll = onDismissAll
        self.viewContext = viewContext
        self._dismissing = dismissing
        self._initialBreakTime = State(initialValue: breakTimeRemaining.wrappedValue)
    }

    private let dos = [
        "Stretch your body",
        "Hydrate yourself",
        "Go out & take a walk",
        "Reflect on your progress",
        "Talk to someone you love"
    ]
    
    private let donts = [
        "Don't check social media",
        "Don't check mails",
        "Avoid Screen time",
        "Don't skip breaks",
        "Don't quit ZenFocus"
    ]

    private var nextTask: ZenFocusTask? {
        NextTaskManager.shared.getNextTask(context: viewContext)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(NSColor.windowBackgroundColor).opacity(0.95)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 30) {
                        if isBreakCompleted {
                            breakCompletionView
                        } else {
                            breakTimerView(geometry: geometry)
                        }
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .opacity(dismissing ? 0 : 1)
            .animation(.easeInOut(duration: 1.5), value: dismissing)
            .onAppear(perform: startBreakTimer)
            .alert(isPresented: $showEndBreakAlert) {
                if let errorMessage = errorMessage {
                    return Alert(
                        title: Text("Error"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK")) {
                            self.errorMessage = nil
                        }
                    )
                } else {
                    return Alert(
                        title: Text("End Break Early?"),
                        message: Text("Are you sure you want to end your break now?"),
                        primaryButton: .destructive(Text("Yes")) {
                            endBreak()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }
    
    private func breakTimerView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 30) {
            Text("Break Time")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(Color(NSColor.labelColor))
            
            Text(timeString(from: breakTimeRemaining))
                .font(.system(size: 96, weight: .semibold, design: .rounded))
                .foregroundColor(Color(NSColor.labelColor))
            
            // Updated progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.quaternaryLabelColor))
                    .frame(height: 20)
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.orange, Color(NSColor.systemRed)]), startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * 0.8 * progress, height: 20)
                    .animation(.linear(duration: 1), value: progress)
            }
            .frame(width: geometry.size.width * 0.8)
            
            HStack(spacing: 20) {
                Button(action: {
                    breakTimeRemaining = max(breakTimeRemaining - 60, 60)
                    updateProgress()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(NSColor.systemBlue))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    isBreakPaused.toggle()
                    if isBreakPaused {
                        timer?.invalidate()
                    } else {
                        startBreakTimer()
                    }
                }) {
                    Image(systemName: isBreakPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(NSColor.systemBlue))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    breakTimeRemaining = min(breakTimeRemaining + 60, 3600)
                    initialBreakTime = max(initialBreakTime, breakTimeRemaining)
                    updateProgress()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(NSColor.systemBlue))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text("Use this break time to recharge and refresh your mind.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 50) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Do's")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(NSColor.systemGreen))
                    ForEach(dos, id: \.self) { item in
                        Text("• \(item)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color(NSColor.labelColor))
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(" Don'ts")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(NSColor.systemRed))
                    ForEach(donts, id: \.self) { item in
                        Text("• \(item)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color(NSColor.labelColor))
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(16)
            .frame(maxWidth: geometry.size.width * 0.8)
            .padding(.horizontal)
            
            if let nextTask = nextTask {
                VStack(alignment: .center, spacing: 8) {
                    Text("Up Next")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                    
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(Color.orange)
                            .font(.system(size: 20))
                        
                        Text(nextTask.title ?? "")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(Color(NSColor.labelColor))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .frame(maxWidth: geometry.size.width * 0.8)
            }
            
            Button(action: {
                showEndBreakAlert = true
            }) {
                Text("End Break Early")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color(NSColor.systemRed))
                    .cornerRadius(15)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var breakCompletionView: some View {
        VStack(spacing: 30) {
            Text("Break Complete!")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(Color(NSColor.labelColor))
            
            Text("Great job taking time to recharge. Are you fueled up for the next task?")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .multilineTextAlignment(.center)
                .padding()
            
            if let nextTask = nextTask {
                VStack(alignment: .center, spacing: 8) {
                    Text("Up Next")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                    
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(Color.orange)
                            .font(.system(size: 20))
                        
                        Text(nextTask.title ?? "")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(Color(NSColor.labelColor))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
            }
            
            HStack(spacing: 20) {
                compactButton(title: "Stop ZenFocus", color: Color(NSColor.systemRed)) {
                    dismissAnimationView {
                        onDismissAll()
                    }
                }
                
                if nextTask != nil {
                    compactButton(title: "Start Next Task", color: Color(NSColor.systemGreen)) {
                        dismissAnimationView {
                            onStartNextTask()
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func compactButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func startBreakTimer() {
        ZenFocusLogger.shared.info("Starting break timer with \(breakTimeRemaining) seconds remaining")
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if breakTimeRemaining > 0 {
                breakTimeRemaining -= 1
                updateProgress()
            } else {
                endBreak()
            }
        }
    }
    
    private func updateProgress() {
        do {
            guard initialBreakTime > 0 else {
                throw BreakTimerError.invalidInitialTime
            }
            progress = CGFloat(initialBreakTime - breakTimeRemaining) / CGFloat(initialBreakTime)
            ZenFocusLogger.shared.debug("Updated progress: \(progress)")
        } catch {
            handleError(error)
        }
    }
    
    private func endBreak() {
        ZenFocusLogger.shared.info("Ending break")
        timer?.invalidate()
        isBreakCompleted = true
        playBreakCompletionSound()
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func dismissAnimationView(completion: @escaping () -> Void) {
        ZenFocusLogger.shared.info("Dismissing animation view")
        dismissing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            do {
                try windowManager.closeTaskCompletionAnimationWindow()
                completion()
            } catch {
                handleError(error)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        let errorMessage = "An error occurred: \(error.localizedDescription)"
        ZenFocusLogger.shared.error(errorMessage, error: error)
        self.errorMessage = errorMessage
        self.showEndBreakAlert = true
    }
    
    private func playBreakCompletionSound() {
        guard let soundURL = Bundle.main.url(forResource: "break_complete", withExtension: "mp3") else {
            ZenFocusLogger.shared.warning("Break completion sound file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
            ZenFocusLogger.shared.info("Break completion sound played successfully")
        } catch {
            ZenFocusLogger.shared.error("Error playing break completion sound", error: error)
        }
    }
}

enum BreakTimerError: Error {
    case invalidInitialTime
}

#if DEBUG
struct BreakTimerView_Previews: PreviewProvider {
    static var previews: some View {
        BreakTimerView(
            breakTimeRemaining: .constant(600),
            showBreakTimer: .constant(true),
            onStartNextTask: {},
            onDismissAll: {},
            viewContext: PersistenceController.preview.container.viewContext,
            dismissing: .constant(false)
        )
        .environmentObject(WindowManager())
        .frame(width: 800, height: 600)
        .previewLayout(.sizeThatFits)
    }
}

extension ZenFocusTask {
    static var example: ZenFocusTask {
        let task = ZenFocusTask(context: PersistenceController.preview.container.viewContext)
        task.title = "Complete project presentation"
        task.category = "Work"
        task.isCompleted = false
        return task
    }
}#endif