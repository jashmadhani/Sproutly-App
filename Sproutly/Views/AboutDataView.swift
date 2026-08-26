//
//  AboutDataView.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/08/26.
//

import SwiftUI

struct AboutDataView: View {
    @Environment(ThemeManager.self) private var theme
    
    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    
                    ZStack {
                        Circle()
                            .fill(theme.blue.opacity(0.12))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 55))
                            .foregroundStyle(theme.blue)
                    }
                    
                    Text("About the Data")
                        .font(.sproutlyDisplay(28))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.text)
                    
                    VStack(spacing: 16) {
                        // The real range the catalog covers. Claiming "from
                        // birth" would be the kind of mismatch that earns a
                        // one-star "doesn't work for newborns" review.
                        Text("Sproutly covers 2 months to 5 years.")
                            .font(Theme.sproutlyCardTitle)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.text)

                        Text("If your baby is younger than two months, your pediatrician and the newborn visits are the place to look.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                            .lineSpacing(4)

                        Text("Milestones in Sproutly are paraphrased from publicly available guidance: the CDC's 'Learn the Signs. Act Early.' program, the World Health Organization's Motor Development Study, and well-visit screening ages published by the American Academy of Pediatrics.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                            .lineSpacing(4)

                        Text("Sproutly is an independent educational tool. It is not affiliated with, sponsored by, endorsed by, or reviewed by the CDC, the World Health Organization, or the American Academy of Pediatrics.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                            .lineSpacing(4)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("About the Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    AboutDataView()
        .environment(ThemeManager())
}
#endif
