import SwiftUI
import AppKit

struct DiscordInviteView: View {
    @Binding var isPresented: Bool
    @State private var isAnimating = false
    @State private var isHoveringMaybeLater = false
    @EnvironmentObject private var analyticsService: AnalyticsService
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(isAnimating ? 10 : -10))
                .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
            
            Text("Join ZenFocus Community!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Connect with other ZenFocus users, send bugs, feature requests, and shape the future of the app.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                openDiscordInvite()
                analyticsService.trackDiscordInviteJoin()
            }) {
                Text("Join Discord")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(spacing: 5) {
                Button("Maybe Later") {
                    withAnimation {
                        isPresented = false
                        analyticsService.trackDiscordInviteMaybeLater()
                    }
                }
                .foregroundColor(.secondary)
                .onHover { hovering in
                    isHoveringMaybeLater = hovering
                }
                
                Text("Available in About view")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(isHoveringMaybeLater ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isHoveringMaybeLater)
            }
            .frame(height: 40) // Fixed height to prevent layout shifts
        }
        .padding(30)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(14)
        .shadow(radius: 10)
        .onAppear {
            isAnimating = true
        }
    }
    
    private func openDiscordInvite() {
        if let url = URL(string: "https://discord.gg/dRfRPREVhW") {
            NSWorkspace.shared.open(url)
        }
        withAnimation {
            isPresented = false
        }
    }
}

// MARK: - Preview
struct DiscordInviteView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            DiscordInviteView(isPresented: .constant(true))
                .frame(width: 300, height: 400)
                .preferredColorScheme(.light)
            
            // Dark mode preview
            DiscordInviteView(isPresented: .constant(true))
                .frame(width: 400, height: 500)
                .preferredColorScheme(.dark)
        }
    }
}
