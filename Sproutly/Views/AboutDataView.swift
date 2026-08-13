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
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.text)
                    
                    VStack(spacing: 16) {
                        Text("Developmental milestones in Sproutly are based on publicly available guidance from the CDC's 'Learn the Signs. Act Early.' program and well-visit screening age guidance published by the American Academy of Pediatrics.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                            .lineSpacing(4)
                        
                        Text("Sproutly is an independent educational tool and is not affiliated with, sponsored by, or endorsed by the CDC or the American Academy of Pediatrics.")
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

#Preview {
    AboutDataView()
        .environment(ThemeManager())
}
