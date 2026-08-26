//
//  SupportAssistantView.swift
//  Sproutly
//
//  Created by Jash Madhani on 19/02/26.
//

import SwiftUI
import SwiftData

// rule-based, no network calls
struct SupportAssistantView: View {
    let milestones: [Milestone]
    let correctedAge: Int
    let nightMode: Bool
    
    @State private var question: String = ""
    @State private var response: AssistantResponse? = nil
    @State private var responseOpacity: Double = 0
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            // Same header as the Settings feature cards, so the disc scales with
            // its glyph and the whole thing stacks at accessibility sizes rather
            // than squeezing the title into a two-word column.
            FeatureCardHeader(
                title: "Ask Sproutly",
                subtitle: "A few things to try, and when to ask",
                systemImage: "sparkles",
                nightMode: nightMode,
                diameter: 36,
                glyphSize: 16,
                subtitleFont: Theme.sproutlyMeta
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Ask Sproutly. A few things to try, and when to ask")
            
            // Input field
            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $question,
                    prompt: Text("What have you been wondering about?")
                        .foregroundColor(Theme.fieldPlaceholder(for: nightMode)),
                    axis: .vertical
                )
                    .lineLimit(1...4)
                    .font(Theme.sproutlyBody)
                    .foregroundStyle(Theme.textPrimary(for: nightMode))
                    .focused($isInputFocused)
                    .accessibilityLabel("Question input")
                    .accessibilityHint("Type a question about your child")
                
                if !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        generateResponse()
                        isInputFocused = false
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.accentBlueText(for: nightMode))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Send question")
                }
            }
            // Same rule as every other typed field in the app. This was the
            // last boxed one — a #E6E2DD slab whose placeholder measured 1.67:1
            // and which read as a component from another app.
            .underlineField(nightMode: nightMode, isFocused: isInputFocused)
            .animation(.easeInOut(duration: 0.25), value: question.isEmpty)
            
            // Response area
            if let resp = response {
                VStack(alignment: .leading, spacing: 12) {
                    // What is ordinarily true at this age
                    Text(resp.context)
                        .font(Theme.sproutlyBody)
                        .foregroundStyle(Theme.textPrimary(for: nightMode))
                        .fixedSize(horizontal: false, vertical: true)

                    // Activity suggestions
                    if !resp.activities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Things to try")
                                .font(Theme.sproutlyCardTitle)
                                .foregroundStyle(Theme.accentBlueText(for: nightMode))

                            ForEach(resp.activities, id: \.self) { activity in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(Theme.sproutlyBody)
                                        .foregroundStyle(Theme.growthGreenText(for: nightMode))
                                    Text(activity)
                                        .font(Theme.sproutlyBody)
                                        .foregroundStyle(Theme.textSecondary(for: nightMode))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // Pediatric note (when appropriate)
                    if let pediatric = resp.pediatricNote {
                        Text(pediatric)
                            .font(Theme.sproutlyBody)
                            .foregroundStyle(Theme.textSecondary(for: nightMode).opacity(0.9))
                            .padding(.top, 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.growthGreen(for: nightMode).opacity(nightMode ? 0.06 : 0.05))
                )
                .opacity(responseOpacity)
                .animation(.easeInOut(duration: 0.4), value: responseOpacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Answer from Sproutly")
            }
        }
        .warmCard(nightMode: nightMode)
    }
    
    // MARK: - Response Generation
    
    private func generateResponse() {
        let q = question.lowercased()
        let resp = AssistantEngine.generateResponse(
            question: q,
            correctedAge: correctedAge,
            milestones: milestones
        )
        
        responseOpacity = 0
        response = resp
        
        withAnimation(.easeInOut(duration: 0.4)) {
            responseOpacity = 1
        }
    }
}

// MARK: - Assistant Response Model

struct AssistantResponse {
    let context: String
    let activities: [String]
    let pediatricNote: String?
}

// MARK: - Concern Intensity


enum ConcernIntensity {
    case none        // No concern-modifiers observed
    case mild        // 1 concern-modifier
    case significant // 2+ concern-modifiers — always show pediatric note
}

// MARK: - Weighted Domain Scorer

// weighted keyword scoring to identify the relevant domain
struct WeightedDomainScorer {
    
    static let keywords: [(String, MilestoneCategory, Int)] = [
        // Gross Motor
        ("walk",    .grossMotor, 2), ("crawl",   .grossMotor, 2),
        ("stand",   .grossMotor, 2), ("run",     .grossMotor, 2),
        ("sit",     .grossMotor, 2), ("roll",    .grossMotor, 2),
        ("step",    .grossMotor, 2), ("climb",   .grossMotor, 2),
        ("jump",    .grossMotor, 2), ("move",    .grossMotor, 2),
        ("motor",   .grossMotor, 2), ("balance", .grossMotor, 2),
        
        // Fine Motor
        ("grab",    .fineMotor, 2), ("pinch",   .fineMotor, 2),
        ("stack",   .fineMotor, 2), ("draw",    .fineMotor, 2),
        ("write",   .fineMotor, 2), ("scissor", .fineMotor, 2),
        ("hand",    .fineMotor, 2), ("finger",  .fineMotor, 2),
        ("hold",    .fineMotor, 2), ("spoon",   .fineMotor, 2),
        ("fork",    .fineMotor, 2), ("grasp",   .fineMotor, 2),
        
        // Language
        ("talk",     .language, 2), ("speak",    .language, 2),
        ("word",     .language, 2), ("babbl",    .language, 2),
        ("speech",   .language, 2), ("language", .language, 2),
        ("say",      .language, 2), ("sound",    .language, 2),
        ("sentence", .language, 2), ("point",    .language, 2),
        ("quiet",    .language, 2), ("verbal",   .language, 2),
        
        // Cognitive
        ("think",      .cognitive, 2), ("learn",      .cognitive, 2),
        ("puzzle",     .cognitive, 2), ("count",      .cognitive, 2),
        ("color",      .cognitive, 2), ("shape",      .cognitive, 2),
        ("pretend",    .cognitive, 2), ("play",       .cognitive, 2),
        ("understand", .cognitive, 2), ("know",       .cognitive, 2),
        ("memory",     .cognitive, 2), ("attention",  .cognitive, 2),
        
        // Social-Emotional
        ("social",     .socialEmotional, 2), ("friend",     .socialEmotional, 2),
        ("emotion",    .socialEmotional, 2), ("cry",        .socialEmotional, 2),
        ("tantrum",    .socialEmotional, 2), ("share",      .socialEmotional, 2),
        ("anxious",    .socialEmotional, 2), ("scared",     .socialEmotional, 2),
        ("behav",      .socialEmotional, 2), ("aggressive", .socialEmotional, 2),
        ("hit",        .socialEmotional, 2), ("shy",        .socialEmotional, 2),
        ("angry",      .socialEmotional, 2), ("bite",       .socialEmotional, 2),
    ]
    

    static let negativeModifiers: Set<String> = [
        "not", "isn't", "hasn't", "never", "still", "worried",
        "concerned", "delayed", "behind", "struggling", "can't",
        "doesn't", "won't", "unable", "slow", "late", "lacking"
    ]
    

    struct Result {
        let domain: MilestoneCategory?
        let intensity: ConcernIntensity
    }
    

    static func score(question: String) -> Result {
        // Tokenize: split on non-alphanumeric, lowercased
        let tokens = question.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        var scores: [MilestoneCategory: Int] = [:]
        var concernModifierCount = 0
        
        for (index, token) in tokens.enumerated() {
            // Check if this token is a negative modifier
            if negativeModifiers.contains(token) {
                concernModifierCount += 1
            }
            
            // Check against domain keywords
            for (keyword, category, baseWeight) in keywords {
                if token.contains(keyword) {
                    // Look back up to 3 tokens for negative modifiers
                    let windowStart = max(0, index - 3)
                    let precedingTokens = tokens[windowStart..<index]
                    let hasNegativeContext = precedingTokens.contains { negativeModifiers.contains($0) }
                    
                    let weight = hasNegativeContext ? baseWeight + 1 : baseWeight
                    scores[category, default: 0] += weight
                }
            }
        }
        
        let topDomain = scores.max(by: { $0.value < $1.value })?.key
        
        let intensity: ConcernIntensity
        switch concernModifierCount {
        case 0:     intensity = .none
        case 1:     intensity = .mild
        default:    intensity = .significant
        }
        
        return Result(domain: topDomain, intensity: intensity)
    }
}

// MARK: - Rule-Based Response Engine


enum AssistantEngine {
    
    static func generateResponse(
        question: String,
        correctedAge: Int,
        milestones: [Milestone]
    ) -> AssistantResponse {
        
        // 1. Score question with weighted analysis
        let scoreResult = WeightedDomainScorer.score(question: question)
        let domain = scoreResult.domain
        let intensity = scoreResult.intensity
        
        // 2. Check completions for that domain
        let domainMilestones = milestones.filter {
            $0.category == (domain?.rawValue ?? "") && $0.ageMonth <= correctedAge + 2
        }
        let total = domainMilestones.count
        let completed = domainMilestones.filter(\.isCompleted).count
        
        // 3. Determine concern level from milestones
        let isConcern = total > 0 && (Double(completed) / Double(total) < 0.5)
        
        // 4. Significant intensity always triggers pediatric note
        let forcePediatric = intensity == .significant
        
        // 5. Generate response
        switch domain {
        case .grossMotor:
            return grossMotorResponse(age: correctedAge, isConcern: isConcern || forcePediatric)
        case .fineMotor:
            return fineMotorResponse(age: correctedAge, isConcern: isConcern || forcePediatric)
        case .language:
            return languageResponse(age: correctedAge, isConcern: isConcern || forcePediatric)
        case .cognitive:
            return cognitiveResponse(age: correctedAge, isConcern: isConcern || forcePediatric)
        case .socialEmotional:
            return socialEmotionalResponse(age: correctedAge, isConcern: isConcern || forcePediatric)
        case .none:
            return generalResponse(age: correctedAge)
        }
    }
    
    // MARK: - Domain Responses
    //
    // One shape for every response: what is ordinarily true at this age, two or
    // three things a parent can actually do, and, when the question or the saved
    // milestones suggest it, a plain reason to raise it at a visit. No response
    // predicts the child, because the app has no basis for predicting.

    private static func grossMotorResponse(age: Int, isConcern: Bool) -> AssistantResponse {
        var contexts: [String] = []
        var activities: [String] = []

        if age < 12 {
            contexts = [
                "Rolling, sitting, and pushing up all draw on the same core strength, and they tend to arrive in bursts rather than steadily.",
                "Babies usually work on one thing at a time. Some spend weeks watching before they start moving much.",
                "Most of the movement practice at this age happens on the floor, during ordinary play."
            ]
            activities = [
                "Tummy time, a few minutes at a stretch, several times a day",
                "Put a favorite toy just out of reach so there is a reason to stretch for it",
                "Sit them propped with cushions so they can practice holding steady"
            ]
        } else if age < 24 {
            contexts = [
                "First steps usually land somewhere between 9 and 18 months. Cruising along furniture and standing without holding on come first.",
                "Balance, coordination, and confidence are all being learned at once, so progress often looks uneven week to week.",
                "Climbing onto cushions and pulling up on the sofa are practice too, even before any walking."
            ]
            activities = [
                "Clear some floor and let them cruise between the sofa and a chair",
                "Hold a toy out so they have a reason to let go with one hand",
                "A sturdy push toy or a weighted box gives support without doing the work for them"
            ]
        } else {
            contexts = [
                "After the first couple of years, movement is mostly about control: stopping, turning, and climbing down as well as up.",
                "Children differ a lot here. Some are climbers, some are runners, and some watch for a while first.",
                "Running, jumping, and balancing keep getting steadier well into the school years."
            ]
            activities = [
                "A playground trip covers climbing, sliding, and balance in one go",
                "Play stop-and-go games to practice starting and stopping on cue",
                "Kick a ball back and forth, which needs a moment of balance on one leg"
            ]
        }

        return AssistantResponse(
            context: contexts.randomElement()!,
            activities: activities.shuffled().prefix(3).map { $0 },
            pediatricNote: isConcern
                ? "If how your child moves is on your mind, bring it to your pediatrician. Describing what you have seen at home is the useful part."
                : nil
        )
    }

    private static func fineMotorResponse(age: Int, isConcern: Bool) -> AssistantResponse {
        let contexts = [
            "Hand skills build in order: whole-hand grabbing first, then thumb and finger, then the finer control that drawing and buttons need.",
            "Most of this gets practiced during eating, playing, and making a mess, rather than in anything that looks like an exercise.",
            "Small hands tire quickly, so short attempts are normal and they still count."
        ]

        var activities: [String] = []
        if age < 18 {
            activities = [
                "Offer finger foods so they practice picking up small pieces",
                "Let them bang blocks together or stack cups",
                "Poke holes in playdough with a finger"
            ]
        } else {
            activities = [
                "Thread large beads or dry pasta onto a string",
                "Use tongs to move cotton balls from one bowl to another",
                "Scribble with chunky crayons, no picture required"
            ]
        }

        return AssistantResponse(
            context: contexts.randomElement()!,
            activities: activities.shuffled().prefix(3).map { $0 },
            pediatricNote: isConcern
                ? "If hand skills are on your mind, mention it at your next visit. Your pediatrician can suggest things to try, or refer you if that would help."
                : nil
        )
    }

    private static func languageResponse(age: Int, isConcern: Bool) -> AssistantResponse {
        var contexts: [String] = []
        var pediatric: String? = nil

        if age < 18 {
            contexts = [
                "Understanding comes before speaking. Looking when you point, turning to their name, and reaching to be picked up are all communication.",
                "Babbling, gestures, and pointing are the groundwork for words, and they carry as much weight now as spoken words will later.",
                "Children vary a lot in when words start. Some work on movement first and words follow in a rush."
            ]
            if isConcern {
                pediatric = "If sounds and gestures are what you are wondering about, bring it to your pediatrician. A hearing check is a routine first step and easy to arrange."
            }
        } else {
            contexts = [
                "Vocabulary grows at very different rates. Following an instruction and putting two words together are big steps, even with few spoken words.",
                "Clear speech takes years to settle. For now, the attempt to be understood matters more than the pronunciation.",
                "The back-and-forth is what builds language: you say something, they answer, you answer that."
            ]
            if isConcern {
                pediatric = "If speech is on your mind, bring it to your pediatrician. Speech and hearing checks are routine, and you do not have to wait for a visit that is already booked."
            }
        }

        let activities = [
            "Say what you are doing as you do it: washing the apple, now drying the apple",
            "Read books with rhyme and repetition so the same sounds come round again",
            "Ask something, then wait longer than feels natural for an answer",
            "Sing songs with hand actions, like Itsy Bitsy Spider"
        ]

        return AssistantResponse(
            context: contexts.randomElement()!,
            activities: activities.shuffled().prefix(3).map { $0 },
            pediatricNote: pediatric
        )
    }

    private static func cognitiveResponse(age: Int, isConcern: Bool) -> AssistantResponse {
        let contexts = [
            "Thinking is hard to see from the outside. Working out where a dropped toy went, or which lid fits which box, is the work happening.",
            "Children learn by testing. Dropping, banging, and hiding things are how the rules of the world get checked.",
            "Attention is short at this age by design. A few minutes of real focus is a lot."
        ]

        let activities = [
            "Play peek-a-boo, then hide a toy under a blanket for them to find",
            "Sort things by color or shape while tidying up",
            "Read a simple story and ask what happens next",
            "Give them containers with lids and let them work out which fits"
        ]

        return AssistantResponse(
            context: contexts.randomElement()!,
            activities: activities.shuffled().prefix(3).map { $0 },
            pediatricNote: isConcern
                ? "If how your child is working things out is on your mind, bring it to your pediatrician. Well-child visits are a good place for it, and you can ask sooner."
                : nil
        )
    }

    private static func socialEmotionalResponse(age: Int, isConcern: Bool) -> AssistantResponse {
        var contexts: [String] = []

        if age < 24 {
            contexts = [
                "Big feelings arrive before the words to explain them, which is why so much of it comes out as crying.",
                "Wariness of strangers, and not wanting you to leave the room, are signs of attachment. They usually peak in the first two years.",
                "Tantrums are usually communication rather than defiance. Something is wrong and there is no other way to say it yet."
            ]
        } else {
            contexts = [
                "Sharing and taking turns take years. Playing alongside another child rather than with them is normal well into the third year.",
                "Empathy builds slowly and mostly by copying. What children see handled calmly, they start handling calmly.",
                "Testing limits is how rules get learned. It is exhausting, and it is also a sign of growing independence."
            ]
        }

        let activities = [
            "Name the feeling out loud: you look upset that the blocks fell",
            "Take turns rolling a ball back and forth",
            "Read books about feelings and talk about the pictures",
            "Play out an everyday scene with dolls or toy animals"
        ]

        return AssistantResponse(
            context: contexts.randomElement()!,
            activities: activities.shuffled().prefix(3).map { $0 },
            pediatricNote: isConcern
                ? "If a behavior is worrying you or happening often, describe it to your pediatrician: what happens, how often, and what usually comes before it. That detail is what helps."
                : nil
        )
    }

    private static func generalResponse(age: Int) -> AssistantResponse {
        let contexts = [
            "There is a wide range in when children do things, and most of that range is ordinary. What you notice day to day is the useful record.",
            "Growth is uneven by nature. Children often work hard on one area while another sits still for a while.",
            "You see your child more than anyone else does. Writing down what you notice gives you something specific to look back on."
        ]

        let activities = [
            "Ten minutes on the floor, following whatever they are already interested in",
            "Go for a walk and name what you both see",
            "Read a favorite book again, even for the hundredth time",
            "Sing through the transitions, like bath time and cleaning up"
        ]

        return AssistantResponse(
            context: contexts.randomElement()!,
            activities: activities.shuffled().prefix(3).map { $0 },
            pediatricNote: "If anything is on your mind, your pediatrician is the right person to ask. Well-child visits are a good time for it, and you do not have to wait for one."
        )
    }
}
