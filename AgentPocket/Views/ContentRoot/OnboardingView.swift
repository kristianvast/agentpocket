import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            TabView {
                VStack(spacing: Theme.spacingLG) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 80))
                        .foregroundStyle(Theme.cyanAccent)
                        .padding(.bottom, Theme.spacingMD)
                    
                    Text("AgentPocket")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    
                    Text("Your AI agents, everywhere")
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                VStack(spacing: Theme.spacingXL) {
                    Text("Connect to any server")
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.textPrimary)
                    
                    VStack(spacing: Theme.spacingMD) {
                        ServerCard(
                            title: "OpenCode",
                            icon: "chevron.left.forwardslash.chevron.right",
                            color: Theme.cyanAccent
                        )
                        
                        ServerCard(
                            title: "OpenClaw",
                            icon: "hand.raised.fingers.spread",
                            color: Theme.emerald
                        )
                        
                        ServerCard(
                            title: "Hermes",
                            icon: "brain.head.profile",
                            color: Theme.orange
                        )
                    }
                    .padding(.horizontal, Theme.spacingLG)
                }
                .padding()
                
                VStack(spacing: Theme.spacingXL) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.cyanAccent)
                    
                    Text("Ready to begin?")
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.textPrimary)
                    
                    Button(action: {
                        appState.serverManager.completeOnboarding()
                    }) {
                        Text("Get Started")
                            .font(Theme.headlineFont)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.cyanAccent)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLG))
                    }
                    .padding(.horizontal, Theme.spacingXL)
                    .padding(.top, Theme.spacingLG)
                }
                .padding()
            }
            .tabViewStyle(.page)
            .onAppear {
                UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Theme.cyanAccent)
                UIPageControl.appearance().pageIndicatorTintColor = UIColor(Theme.textMuted)
            }
        }
    }
}

private struct ServerCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: Theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 40)
            
            Text(title)
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)
            
            Spacer()
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }
}
