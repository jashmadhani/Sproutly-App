//
//  DataSeeder.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftData


struct DataSeeder {

    // MARK: - All Milestones (used by PreviewMocks)


    static var allMilestones: [Milestone] {
        sixMonth + nineMonth + twelveMonth + eighteenMonth
            + twentyFourMonth + thirtySixMonth + fortyEightMonth + sixtyMonth
    }

    // MARK: - Entry Points

    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Milestone>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        guard existingCount < 80 else { return }

        // Delete any partial data first
        if let existing = try? modelContext.fetch(descriptor) {
            for m in existing { modelContext.delete(m) }
        }

        for m in allMilestones { modelContext.insert(m) }

        do {
            try modelContext.save()
        } catch {
            print("⚠️ Sproutly: Failed to save seeded milestones — \(error.localizedDescription)")
        }
    }

    @MainActor
    static func loadSampleData(modelContext: ModelContext) {
        seedIfNeeded(modelContext: modelContext)
    }

    // MARK: - 6 Months

    private static var sixMonth: [Milestone] { [
        Milestone(title: "Sits with support", category: "Gross Motor", ageMonth: 6,
                  tips: "Sitting up opens a whole new world for them. Surround with soft cushions and let them explore."),
        Milestone(title: "Rolls over in both directions", category: "Gross Motor", ageMonth: 6,
                  tips: "A safe floor space gives them room to practice. Each roll is a small triumph."),
        Milestone(title: "Rakes small objects toward self", category: "Fine Motor", ageMonth: 6,
                  tips: "Their little hands are learning to grab — offer safe objects and watch them practice."),
        Milestone(title: "Transfers objects between hands", category: "Fine Motor", ageMonth: 6,
                  tips: "Passing a toy from one hand to the other shows growing coordination. Simply wonderful."),
        Milestone(title: "Babbles chains of consonants", category: "Language", ageMonth: 6,
                  tips: "When you talk back to their babbles, you're teaching the rhythm of conversation."),
        Milestone(title: "Responds to own name", category: "Language", ageMonth: 6,
                  tips: "When they turn at their name, it means they know they belong to you."),
        Milestone(title: "Explores objects by mouthing", category: "Cognitive", ageMonth: 6,
                  tips: "Mouthing is how they explore right now. Safe objects only."),
        Milestone(title: "Looks at things nearby, reaches for objects", category: "Cognitive", ageMonth: 6,
                  tips: "Reaching shows intention and desire. Their curiosity is blossoming."),
        Milestone(title: "Recognizes familiar faces", category: "Social-Emotional", ageMonth: 6,
                  tips: "If they seem wary of strangers, that's actually healthy attachment."),
        Milestone(title: "Enjoys looking at self in mirror", category: "Social-Emotional", ageMonth: 6,
                  tips: "Mirror play builds self-awareness. Smile at their reflection together."),
    ] }

    // MARK: - 9 Months

    private static var nineMonth: [Milestone] { [
        Milestone(title: "Pulls to standing position", category: "Gross Motor", ageMonth: 9,
                  tips: "The world looks different standing up. Make sure furniture is stable for those early pulls."),
        Milestone(title: "Crawls or moves across the floor", category: "Gross Motor", ageMonth: 9,
                  tips: "Crawling builds strength that supports walking later. Every style of crawling counts."),
        Milestone(title: "Uses pincer grasp (thumb and finger)", category: "Fine Motor", ageMonth: 9,
                  tips: "Picking up tiny things shows incredible fine motor growth. Supervise and celebrate."),
        Milestone(title: "Bangs two objects together", category: "Fine Motor", ageMonth: 9,
                  tips: "Loud and repetitive, yes. But they're figuring out cause and effect."),
        Milestone(title: "Understands 'no' and simple words", category: "Language", ageMonth: 9,
                  tips: "They get more than they let on. This one often flies under the radar."),
        Milestone(title: "Makes different sounds like 'mamamama'", category: "Language", ageMonth: 9,
                  tips: "Those repeated syllables are building blocks of words. They're getting closer every day."),
        Milestone(title: "Watches the path of something as it falls", category: "Cognitive", ageMonth: 9,
                  tips: "Tracking falling objects shows early physics intuition."),
        Milestone(title: "Looks for things they see you hide", category: "Cognitive", ageMonth: 9,
                  tips: "Try hiding a toy under a blanket. Watching them find it is genuinely fun."),
        Milestone(title: "Shows stranger anxiety", category: "Social-Emotional", ageMonth: 9,
                  tips: "Clinging to you around strangers is a good sign, not a problem."),
        Milestone(title: "Has favorite toys", category: "Social-Emotional", ageMonth: 9,
                  tips: "Watch what they always reach for. You'll start to see their personality."),
    ] }

    // MARK: - 12 Months

    private static var twelveMonth: [Milestone] { [
        Milestone(title: "Walks holding onto furniture (cruising)", category: "Gross Motor", ageMonth: 12,
                  tips: "Cruising along furniture is a confident step toward independence."),
        Milestone(title: "May take a few steps independently", category: "Gross Motor", ageMonth: 12,
                  tips: "Anywhere between 9 and 15 months is normal. Try not to compare."),
        Milestone(title: "Puts objects into a container", category: "Fine Motor", ageMonth: 12,
                  tips: "In-and-out play teaches spatial relationships. Simple cups and blocks are perfect."),
        Milestone(title: "Releases objects voluntarily", category: "Fine Motor", ageMonth: 12,
                  tips: "Dropping things on purpose. Harder than it sounds, actually."),
        Milestone(title: "Says 1-2 simple words like 'mama' or 'dada'", category: "Language", ageMonth: 12,
                  tips: "First words are unforgettable. Keep talking, reading, and singing."),
        Milestone(title: "Uses gestures like waving or pointing", category: "Language", ageMonth: 12,
                  tips: "A wave or point is early communication. They're telling you what matters."),
        Milestone(title: "Explores how things work (shaking, throwing)", category: "Cognitive", ageMonth: 12,
                  tips: "Every shake and throw is an experiment. They're learning cause and effect."),
        Milestone(title: "Finds hidden things easily", category: "Cognitive", ageMonth: 12,
                  tips: "Their memory is growing stronger. Play simple hiding games together."),
        Milestone(title: "Shows affection to familiar people", category: "Social-Emotional", ageMonth: 12,
                  tips: "Hugs and cuddles are their way of saying 'I love you' before they have words."),
        Milestone(title: "May cry when parent leaves", category: "Social-Emotional", ageMonth: 12,
                  tips: "Separation distress means a strong bond. Brief, calm goodbyes help."),
    ] }

    // MARK: - 18 Months

    private static var eighteenMonth: [Milestone] { [
        Milestone(title: "Walks independently", category: "Gross Motor", ageMonth: 18,
                  tips: "Independent walking is a landmark moment. Each child reaches it in their own time."),
        Milestone(title: "Begins to run (stiff-legged)", category: "Gross Motor", ageMonth: 18,
                  tips: "That adorable toddle-run means their confidence is growing alongside their muscles."),
        Milestone(title: "Stacks two or more blocks", category: "Fine Motor", ageMonth: 18,
                  tips: "Stacking blocks shows hand-eye coordination developing beautifully."),
        Milestone(title: "Scribbles with a crayon", category: "Fine Motor", ageMonth: 18,
                  tips: "Those first scribbles are creative expression. Every mark matters."),
        Milestone(title: "Says 10-25 words", category: "Language", ageMonth: 18,
                  tips: "Vocabulary is building. Even words only you understand count — you are their interpreter."),
        Milestone(title: "Points to show things to others", category: "Language", ageMonth: 18,
                  tips: "When they point to show you something, they want to share it with you. That matters."),
        Milestone(title: "Knows what ordinary things are for (phone, brush)", category: "Cognitive", ageMonth: 18,
                  tips: "Using objects for their purpose shows real-world understanding. Wonderful progress."),
        Milestone(title: "Engages in simple pretend play", category: "Cognitive", ageMonth: 18,
                  tips: "Pretend play starts small. A toy phone is enough."),
        Milestone(title: "Shows emerging autonomy ('me do it')", category: "Social-Emotional", ageMonth: 18,
                  tips: "Let them try even when it takes three times as long. Worth it."),
        Milestone(title: "May have temper tantrums", category: "Social-Emotional", ageMonth: 18,
                  tips: "Tantrums are communication, not manipulation. They don't have words for it yet."),
    ] }

    // MARK: - 24 Months (2 Years)

    private static var twentyFourMonth: [Milestone] { [
        Milestone(title: "Runs well", category: "Gross Motor", ageMonth: 24,
                  tips: "Give them room to move. Crashing into things is part of learning."),
        Milestone(title: "Kicks a ball forward", category: "Gross Motor", ageMonth: 24,
                  tips: "Kicking requires balance, coordination, and intention. A complex skill made to look simple."),
        Milestone(title: "Stacks 4-6 blocks", category: "Fine Motor", ageMonth: 24,
                  tips: "Taller towers mean steadier hands. Building and tumbling are equally important."),
        Milestone(title: "Turns pages one at a time", category: "Fine Motor", ageMonth: 24,
                  tips: "Page-turning shows fine motor control and a growing love of stories."),
        Milestone(title: "Puts 2 words together ('more milk')", category: "Language", ageMonth: 24,
                  tips: "Two-word combinations are the beginning of real sentences. A wonderful leap."),
        Milestone(title: "Points to things in a book when asked", category: "Language", ageMonth: 24,
                  tips: "Connecting words to pictures shows language comprehension blossoming."),
        Milestone(title: "Sorts shapes and colors", category: "Cognitive", ageMonth: 24,
                  tips: "Sorting things is actually abstract thinking. A shape sorter works fine."),
        Milestone(title: "Follows simple two-step instructions", category: "Cognitive", ageMonth: 24,
                  tips: "Understanding sequences shows memory and processing are both developing."),
        Milestone(title: "Plays alongside other children (parallel play)", category: "Social-Emotional", ageMonth: 24,
                  tips: "Parallel play looks like they're ignoring each other. They're not."),
        Milestone(title: "Copies others, especially adults", category: "Social-Emotional", ageMonth: 24,
                  tips: "Imitation is how they learn social behavior. You are their most important model."),
    ] }

    // MARK: - 36 Months (3 Years)

    private static var thirtySixMonth: [Milestone] { [
        Milestone(title: "Climbs well", category: "Gross Motor", ageMonth: 36,
                  tips: "Let them climb. Falling a little is fine. Stopping them constantly isn't."),
        Milestone(title: "Pedals a tricycle", category: "Gross Motor", ageMonth: 36,
                  tips: "Pedaling is a complex coordinated movement. Every wobbly ride builds confidence."),
        Milestone(title: "Draws a circle when shown how", category: "Fine Motor", ageMonth: 36,
                  tips: "Drawing shapes shows the hand learning to follow the mind's intention."),
        Milestone(title: "Turns door handles, screws lids", category: "Fine Motor", ageMonth: 36,
                  tips: "Rotating motions show advanced fine motor control. They're more capable every day."),
        Milestone(title: "Uses 3-word sentences", category: "Language", ageMonth: 36,
                  tips: "Longer sentences mean complex thinking is emerging. Keep conversations flowing."),
        Milestone(title: "Can name familiar things", category: "Language", ageMonth: 36,
                  tips: "Naming the world around them gives them power over their environment."),
        Milestone(title: "Understands the concept of 'two'", category: "Cognitive", ageMonth: 36,
                  tips: "Number concepts are emerging. Count together during everyday moments."),
        Milestone(title: "Does 3-4 piece puzzles", category: "Cognitive", ageMonth: 36,
                  tips: "3-4 piece puzzles are harder than they look for little hands."),
        Milestone(title: "Takes turns in games", category: "Social-Emotional", ageMonth: 36,
                  tips: "Turn-taking requires empathy and self-control. It's a big social milestone."),
        Milestone(title: "Shows concern for a crying friend", category: "Social-Emotional", ageMonth: 36,
                  tips: "Empathy is blooming. Their heart is growing alongside their mind."),
    ] }

    // MARK: - 48 Months (4 Years)

    private static var fortyEightMonth: [Milestone] { [
        Milestone(title: "Hops on one foot", category: "Gross Motor", ageMonth: 48,
                  tips: "Hopping requires balance, strength, and body control — impressive coordination."),
        Milestone(title: "Catches a bounced ball most of the time", category: "Gross Motor", ageMonth: 48,
                  tips: "Catching requires tracking, timing, and hand-eye coordination all at once."),
        Milestone(title: "Uses scissors to cut paper", category: "Fine Motor", ageMonth: 48,
                  tips: "Scissor skills show bilateral coordination. Supervised cutting practice helps."),
        Milestone(title: "Draws a person with 2-4 body parts", category: "Fine Motor", ageMonth: 48,
                  tips: "Drawing people shows both fine motor skill and how they see the world."),
        Milestone(title: "Tells stories and sings songs", category: "Language", ageMonth: 48,
                  tips: "When they tell you a story — even a nonsense one — listen to the whole thing."),
        Milestone(title: "Uses sentences of 5+ words", category: "Language", ageMonth: 48,
                  tips: "Longer sentences mean more complex thoughts. Ask open-ended questions to encourage this."),
        Milestone(title: "Counts to 4 or higher", category: "Cognitive", ageMonth: 48,
                  tips: "Number concepts are strengthening. Count steps, snacks, toys — everything becomes math."),
        Milestone(title: "Understands time concepts (morning, night)", category: "Cognitive", ageMonth: 48,
                  tips: "Morning and night before clock time. Routine helps this click."),
        Milestone(title: "Cooperative play with other children", category: "Social-Emotional", ageMonth: 48,
                  tips: "Playing together (not just beside) shows growing social skills and empathy."),
        Milestone(title: "Increasingly inventive in fantasy play", category: "Social-Emotional", ageMonth: 48,
                  tips: "Rich pretend play shows emotional processing and social learning at work."),
    ] }

    // MARK: - 60 Months (5 Years)

    private static var sixtyMonth: [Milestone] { [
        Milestone(title: "Skips and stands on one foot 10+ seconds", category: "Gross Motor", ageMonth: 60,
                  tips: "Complex movement shows the body and brain working in harmony."),
        Milestone(title: "Can do a somersault", category: "Gross Motor", ageMonth: 60,
                  tips: "Somersaults require body awareness, courage, and coordination. Amazing achievement."),
        Milestone(title: "Writes some letters and numbers", category: "Fine Motor", ageMonth: 60,
                  tips: "Early writing is a bridge between thinking and doing. Every letter is a milestone."),
        Milestone(title: "Uses fork and spoon well", category: "Fine Motor", ageMonth: 60,
                  tips: "Independent eating shows fine motor maturity. Messy learning is still learning."),
        Milestone(title: "Speaks in complex sentences, tells longer stories", category: "Language", ageMonth: 60,
                  tips: "Complex language means complex thinking. Their inner world is rich and growing."),
        Milestone(title: "Uses future tense ('I will go')", category: "Language", ageMonth: 60,
                  tips: "Future tense shows they can think ahead — a cognitive and language milestone combined."),
        Milestone(title: "Counts 10 or more things", category: "Cognitive", ageMonth: 60,
                  tips: "Counting with meaning (not just reciting) shows true number understanding."),
        Milestone(title: "Can name at least 4 colors", category: "Cognitive", ageMonth: 60,
                  tips: "Color naming shows categorization and language working together."),
        Milestone(title: "Understands rules and wants to follow them", category: "Social-Emotional", ageMonth: 60,
                  tips: "Understanding rules shows social maturity. They want to belong and participate."),
        Milestone(title: "Distinguishes fantasy from reality", category: "Social-Emotional", ageMonth: 60,
                  tips: "The line between real and pretend is still fuzzy. That's fine at this age."),
    ] }
}
