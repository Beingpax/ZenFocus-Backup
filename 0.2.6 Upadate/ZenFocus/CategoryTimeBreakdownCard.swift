import SwiftUI

struct CategoryTimeBreakdownCard: View {
    let categoryTimes: [(String, TimeInterval)]
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var categoryManager: CategoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.2))
                    .clipShape(Circle())
                
                Text("Time Breakdown by Category")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                ForEach(categoryTimes.prefix(6), id: \.0) { category, time in
                    CategoryCircle(category: category, time: time, totalTime: totalTime, color: categoryManager.colorForCategory(category))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var totalTime: TimeInterval {
        categoryTimes.reduce(0) { $0 + $1.1 }
    }
}

struct CategoryCircle: View {
    let category: String
    let time: TimeInterval
    let totalTime: TimeInterval
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: CGFloat(time / totalTime))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text(String(format: "%.1f%%", (time / totalTime) * 100))
                        .font(.system(size: 16, weight: .bold))
                    Text(formatDuration(time))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(category)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 40)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}
