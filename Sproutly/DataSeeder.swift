//
//  DataSeeder.swift
//  Sproutly
//
//  Created by Jash Madhani on 03/02/26.
//

import SwiftData


struct DataSeeder {

    // MARK: - All Milestones (used by PreviewMocks)


    // Kept in age order. `reseedIfIncomplete` keys on (title, ageMonth), so a
    // title must stay unique across the whole catalog — a near-duplicate of an
    // existing band's wording reads to a parent as the same thing asked twice.
    //
    // Bands are paraphrased from the CDC's "Learn the Signs. Act Early."
    // checklists (2022 revision, a US federal work in the public domain), with
    // gross motor cross-checked against the WHO Motor Development Study so the
    // set is not purely US-normed. Both are paraphrased rather than quoted;
    // WHO material is not public domain. Neither organisation has reviewed or
    // endorsed Sproutly.
    static var allMilestones: [Milestone] {
        twoMonth + fourMonth + sixMonth + nineMonth + twelveMonth + fifteenMonth
            + eighteenMonth + twentyFourMonth + thirtyMonth + thirtySixMonth
            + fortyEightMonth + sixtyMonth
    }

    // MARK: - Entry Points

    // Gives one child their own copy of the standard milestone set. Each child is
    // seeded independently, so siblings never share progress.
    @MainActor
    static func seed(for child: Child, in modelContext: ModelContext) {
        for milestone in allMilestones {
            milestone.child = child
            modelContext.insert(milestone)
        }

        do {
            try modelContext.save()
        } catch {
            sproutlyLog("Failed to save seeded milestones — \(error.localizedDescription)")
        }
    }

    // Repairs a child whose standard milestones are missing some entries, leaving
    // existing progress and parent-authored ones untouched. This runs on every
    // Dashboard appearance, so it must only ever ADD what's missing — the previous
    // version deleted and recreated every standard milestone whenever the total
    // count didn't match allMilestones.count, which silently wiped every parent's
    // completion, notes, and photos each time a milestone was added or removed
    // from the catalog between builds (photo files were orphaned on disk since
    // only the database rows were deleted, never the file).
    @MainActor
    static func reseedIfIncomplete(for child: Child, in modelContext: ModelContext) {
        let standard = child.milestones.filter { !$0.isUserCreated }

        // Keyed on title *and* age. Title alone was ambiguous the moment the
        // catalog could hold the same wording in two bands; the pair is what
        // actually identifies a row.
        let existingKeys = Set(standard.map(identity))
        let missing = allMilestones.filter { !existingKeys.contains(identity($0)) }
        guard !missing.isEmpty else { return }

        // Work out what the child never had a chance at *before* inserting,
        // while their existing bands still describe the catalog they grew up on.
        let excluded = CatalogBaseline.bandsToExclude(
            inserting: missing,
            existingBands: Set(standard.map(\.ageMonth)),
            correctedAge: max(0, child.calculateCorrectedAge())
        )

        for milestone in missing {
            milestone.child = child
            modelContext.insert(milestone)
        }

        CatalogBaseline.record(excluded, for: child.id)

        do {
            try modelContext.save()
        } catch {
            sproutlyLog("Failed to repair seeded milestones — \(error.localizedDescription)")
        }
    }

    // Identity of a catalog row: the wording plus the band it belongs to.
    private static func identity(_ milestone: Milestone) -> String {
        "\(milestone.ageMonth)|\(milestone.title)"
    }

    // MARK: - 2 Months

    // Nine rather than ten. Fine motor at eight weeks is genuinely one
    // observation — hands opening out of the newborn fist — and a second would
    // have had to be invented. Every line here is written for a parent who is
    // eight weeks postpartum and exhausted: these are things to enjoy noticing,
    // and not one of them is phrased as something to check for.
    private static var twoMonth: [Milestone] { [
        Milestone(title: "Lifts head briefly during tummy time", category: "Gross Motor", ageMonth: 2,
                  tips: "A few seconds is plenty at this age. Short and often works better than long stretches."),
        Milestone(title: "Moves both arms and both legs", category: "Gross Motor", ageMonth: 2,
                  tips: "All that kicking and waving is how they're finding out where their body ends."),
        Milestone(title: "Opens and closes their hands", category: "Fine Motor", ageMonth: 2,
                  tips: "Those tight newborn fists are starting to unfurl. Let them grip your finger."),
        Milestone(title: "Makes sounds other than crying", category: "Language", ageMonth: 2,
                  tips: "Little gurgles and sighs are their first go at talking. Answer them and they'll carry on."),
        Milestone(title: "Reacts to loud sounds", category: "Language", ageMonth: 2,
                  tips: "A startle, a blink, a pause mid-feed: all of it counts as hearing you."),
        Milestone(title: "Watches you as you move", category: "Cognitive", ageMonth: 2,
                  tips: "Your face is still their favourite thing in the room. Move slowly and let them follow."),
        Milestone(title: "Looks at a toy for several seconds", category: "Cognitive", ageMonth: 2,
                  tips: "High contrast holds their attention best right now: black, white, and bold shapes."),
        Milestone(title: "Smiles when you talk or smile at them", category: "Social-Emotional", ageMonth: 2,
                  tips: "The first real smile back is one of the great moments. It's worth writing down."),
        Milestone(title: "Calms when comforted or picked up", category: "Social-Emotional", ageMonth: 2,
                  tips: "Settling in your arms is them learning that you come when they need you."),
    ] }

    // MARK: - 4 Months

    private static var fourMonth: [Milestone] { [
        Milestone(title: "Holds head steady without support", category: "Gross Motor", ageMonth: 4,
                  tips: "Steadier every week. Carrying them upright gives them a much better view."),
        Milestone(title: "Pushes up on elbows during tummy time", category: "Gross Motor", ageMonth: 4,
                  tips: "Propping up on their forearms is the groundwork for rolling and sitting later on."),
        Milestone(title: "Holds a toy placed in their hand", category: "Fine Motor", ageMonth: 4,
                  tips: "Light rattles are easiest to hang on to. Expect it to end up in their mouth."),
        Milestone(title: "Brings hands to mouth", category: "Fine Motor", ageMonth: 4,
                  tips: "Hands to mouth is how they self-soothe and explore at the same time."),
        Milestone(title: "Makes cooing sounds", category: "Language", ageMonth: 4,
                  tips: "Long soft vowels, ooh and aah. Coo back and you'll often get a reply."),
        Milestone(title: "Turns toward the sound of your voice", category: "Language", ageMonth: 4,
                  tips: "They know your voice from across the room. Talking as you move around is enough."),
        Milestone(title: "Looks at their own hands with interest", category: "Cognitive", ageMonth: 4,
                  tips: "Discovering their hands belong to them is a genuinely big idea."),
        Milestone(title: "Opens mouth for the bottle or breast when hungry", category: "Cognitive", ageMonth: 4,
                  tips: "Recognising what's coming before it arrives shows they're joining the dots."),
        Milestone(title: "Smiles on their own to get your attention", category: "Social-Emotional", ageMonth: 4,
                  tips: "A smile aimed at you, on purpose, to start something. That's a conversation."),
        Milestone(title: "Chuckles when you try to make them laugh", category: "Social-Emotional", ageMonth: 4,
                  tips: "Not a full belly laugh yet. Find the thing that works and you'll be doing it all week."),
    ] }

    // MARK: - 6 Months

    private static var sixMonth: [Milestone] { [
        Milestone(title: "Sits with support", category: "Gross Motor", ageMonth: 6,
                  tips: "Sitting up opens a whole new world for them. Surround with soft cushions and let them explore."),
        Milestone(title: "Rolls over in both directions", category: "Gross Motor", ageMonth: 6,
                  tips: "A safe floor space gives them room to practice. Each roll is a small triumph."),
        Milestone(title: "Rakes small objects toward self", category: "Fine Motor", ageMonth: 6,
                  tips: "Their hands are learning to grab. Offer safe objects and watch them practice."),
        Milestone(title: "Transfers objects between hands", category: "Fine Motor", ageMonth: 6,
                  tips: "Passing a toy from one hand to the other takes real coordination."),
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
                  tips: "Picking up tiny things takes fine control. Worth supervising while they practice."),
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

    // MARK: - 15 Months

    // The CDC's own fifteen-month list overlaps heavily with bands Sproutly
    // already ships — its walking, stacking and "uses things the right way"
    // entries are already covered at twelve and eighteen months. Repeating them
    // here would ask a parent the same question twice in two places. The items
    // below are the CDC ones that do not collide, filled out with standard
    // fifteen-month observations from general pediatric practice (stooping and
    // recovering, walking backward, drinking from an open cup, pointing to a
    // body part, lids on and off). Nothing here comes from a proprietary
    // developmental framework.
    private static var fifteenMonth: [Milestone] { [
        Milestone(title: "Stoops down and stands back up", category: "Gross Motor", ageMonth: 15,
                  tips: "Squatting to pick something up and getting back up unaided takes real balance."),
        Milestone(title: "Walks backward a few steps", category: "Gross Motor", ageMonth: 15,
                  tips: "Often discovered by accident while pulling a toy along behind them."),
        Milestone(title: "Uses fingers to feed themselves", category: "Fine Motor", ageMonth: 15,
                  tips: "Messy is the point. Soft pieces they can pick up one at a time work best."),
        Milestone(title: "Drinks from an open cup with help", category: "Fine Motor", ageMonth: 15,
                  tips: "A small cup and a little water. Expect spills for a good while yet."),
        Milestone(title: "Tries a word or two beyond 'mama' and 'dada'", category: "Language", ageMonth: 15,
                  tips: "Their version counts. 'Ba' for ball is a word if they mean it."),
        Milestone(title: "Points to ask for something or for help", category: "Language", ageMonth: 15,
                  tips: "Pointing to get something is different from pointing to show you. Both matter."),
        Milestone(title: "Points to one body part when you ask", category: "Cognitive", ageMonth: 15,
                  tips: "Noses and tummies are usually first. It works best as a game, not a quiz."),
        Milestone(title: "Puts a lid on and takes it off again", category: "Cognitive", ageMonth: 15,
                  tips: "Containers and lids will hold their attention longer than most toys."),
        Milestone(title: "Claps when excited", category: "Social-Emotional", ageMonth: 15,
                  tips: "Clapping at their own achievements means they've noticed them too."),
        Milestone(title: "Shows you an object they like", category: "Social-Emotional", ageMonth: 15,
                  tips: "Bringing something over just to share it with you is real back-and-forth."),
    ] }

    // MARK: - 18 Months

    private static var eighteenMonth: [Milestone] { [
        Milestone(title: "Walks independently", category: "Gross Motor", ageMonth: 18,
                  tips: "Independent walking is a landmark moment. Each child reaches it in their own time."),
        Milestone(title: "Begins to run (stiff-legged)", category: "Gross Motor", ageMonth: 18,
                  tips: "That adorable toddle-run means their confidence is growing alongside their muscles."),
        Milestone(title: "Stacks two or more blocks", category: "Fine Motor", ageMonth: 18,
                  tips: "Stacking blocks is hand-eye coordination coming together."),
        Milestone(title: "Scribbles with a crayon", category: "Fine Motor", ageMonth: 18,
                  tips: "Those first scribbles are creative expression. Every mark matters."),
        Milestone(title: "Says 10-25 words", category: "Language", ageMonth: 18,
                  tips: "Vocabulary is building. Even words only you understand count, because you are their interpreter."),
        Milestone(title: "Points to show things to others", category: "Language", ageMonth: 18,
                  tips: "When they point to show you something, they want to share it with you. That matters."),
        Milestone(title: "Knows what ordinary things are for (phone, brush)", category: "Cognitive", ageMonth: 18,
                  tips: "Using an object for what it is actually for shows they have worked out what it does."),
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
                  tips: "Two words together are the start of real sentences."),
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

    // MARK: - 30 Months

    // Same overlap problem as fifteen months: the CDC's thirty-month list
    // repeats two-word phrases, book pointing, two-step instructions, parallel
    // play and pretend play, all of which Sproutly already asks about at
    // eighteen or twenty-four months. What is left is the genuinely new
    // thirty-month material, plus a stairs item and a spoon item that no
    // existing band covers.
    private static var thirtyMonth: [Milestone] { [
        Milestone(title: "Jumps with both feet off the ground", category: "Gross Motor", ageMonth: 30,
                  tips: "Both feet leaving at once is harder than it looks. Off a low step is a good start."),
        Milestone(title: "Walks up stairs with both feet on each step", category: "Gross Motor", ageMonth: 30,
                  tips: "One hand on the rail, both feet meeting on each step. Alternating comes later."),
        Milestone(title: "Takes some clothes off by themselves", category: "Fine Motor", ageMonth: 30,
                  tips: "Socks and hats go first. Getting them off is much easier than getting them on."),
        Milestone(title: "Uses a spoon with little spilling", category: "Fine Motor", ageMonth: 30,
                  tips: "Thicker foods stay on the spoon better while they're getting the hang of it."),
        Milestone(title: "Says about 50 words", category: "Language", ageMonth: 30,
                  tips: "Nobody counts exactly. If new words keep turning up, that's the thing to notice."),
        Milestone(title: "Uses words like 'I', 'me' and 'we'", category: "Language", ageMonth: 30,
                  tips: "Working out that they are 'I' and you are 'you' is a surprisingly big leap."),
        Milestone(title: "Knows at least one colour", category: "Cognitive", ageMonth: 30,
                  tips: "Usually one favourite first, applied to everything. Naming colours as you go along helps."),
        Milestone(title: "Works out simple problems on their own", category: "Cognitive", ageMonth: 30,
                  tips: "Standing on something to reach higher counts. Give it a moment before stepping in."),
        Milestone(title: "Shows you what they can do: 'look at me!'", category: "Social-Emotional", ageMonth: 30,
                  tips: "Wanting an audience for something they've managed is new, and worth giving them."),
        Milestone(title: "Follows simple routines when told", category: "Social-Emotional", ageMonth: 30,
                  tips: "Helping tidy up or coming for a bath when asked. It won't be every time."),
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
                  tips: "Noticing how someone else feels is empathy starting to show."),
    ] }

    // MARK: - 48 Months (4 Years)

    private static var fortyEightMonth: [Milestone] { [
        Milestone(title: "Hops on one foot", category: "Gross Motor", ageMonth: 48,
                  tips: "Hopping needs balance, strength, and body control all at once."),
        Milestone(title: "Catches a bounced ball most of the time", category: "Gross Motor", ageMonth: 48,
                  tips: "Catching requires tracking, timing, and hand-eye coordination all at once."),
        Milestone(title: "Uses scissors to cut paper", category: "Fine Motor", ageMonth: 48,
                  tips: "Scissor skills show bilateral coordination. Supervised cutting practice helps."),
        Milestone(title: "Draws a person with 2-4 body parts", category: "Fine Motor", ageMonth: 48,
                  tips: "Drawing people shows both fine motor skill and how they see the world."),
        Milestone(title: "Tells stories and sings songs", category: "Language", ageMonth: 48,
                  tips: "When they tell you a story, even a nonsense one, listen to the whole thing."),
        Milestone(title: "Uses sentences of 5+ words", category: "Language", ageMonth: 48,
                  tips: "Longer sentences mean more complex thoughts. Ask open-ended questions to encourage this."),
        Milestone(title: "Counts to 4 or higher", category: "Cognitive", ageMonth: 48,
                  tips: "Numbers are starting to make sense. Count steps, snacks, toys: everything becomes math."),
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
                  tips: "Talking about later shows they can think ahead, which is language and thinking at once."),
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
