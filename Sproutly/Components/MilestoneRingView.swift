//
//  MilestoneRingView.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftUI


struct MilestoneRingView: View {
    var progress: Double
    var completedCount: Int
    var totalCount: Int
    var nightMode: Bool = false

    @State private var animatedProgress: Double = 0

    private var ringBlue: Color { Theme.accentBlue(for: nightMode) }
    private var ringGreen: Color { Theme.growthGreen(for: nightMode) }

    var body: some View {
        ZStack {

            Circle()
                .stroke(
                    ringBlue.opacity(nightMode ? 0.25 : 0.30),
                    lineWidth: 12
                )


            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            ringBlue,
                            Color(red: 0.2, green: 0.7, blue: 0.75), // teal midpoint
                            ringGreen
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: ringBlue.opacity(0.35),
                    radius: 8,
                    x: 0,
                    y: 0
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Milestone progress ring")
        .accessibilityValue("\(completedCount) of \(totalCount) milestones completed")
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.25)) {
                animatedProgress = newValue
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: 0xFAF8F4).ignoresSafeArea()
        MilestoneRingView(progress: 0.65, completedCount: 4, totalCount: 6)
    }
}
