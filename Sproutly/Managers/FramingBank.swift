//
//  FramingBank.swift
//  Sproutly
//

import Foundation

/// The opening line of an answer: what is ordinarily true in this area at this
/// age, before anything specific to this child.
///
/// These sentences are the one part of the previous engine worth keeping. What
/// changed is how they are chosen. They used to be picked with
/// `randomElement()`, which was the whole of the variety a reply had. Now they
/// open an answer whose specifics come from the retrieved milestone and the
/// parent's own saved progress.
enum FramingBank {

    static func framing(domain: MilestoneCategory, band: ActivityBank.Band) -> [String] {
        switch (domain, band) {

        case (.grossMotor, .infant):
            return [
                "Rolling, sitting, and pushing up all draw on the same core strength, and they tend to arrive in bursts rather than steadily.",
                "Babies usually work on one thing at a time. Some spend weeks watching before they start moving much.",
                "Most of the movement practice at this age happens on the floor, during ordinary play."
            ]
        case (.grossMotor, .toddler):
            return [
                "First steps usually land somewhere between 9 and 18 months. Cruising along furniture and standing without holding on come first.",
                "Balance, coordination, and confidence are all being learned at once, so progress often looks uneven week to week.",
                "Climbing onto cushions and pulling up on the sofa are practice too, even before any walking."
            ]
        case (.grossMotor, .preschool):
            return [
                "After the first couple of years, movement is mostly about control: stopping, turning, and climbing down as well as up.",
                "Children differ a lot here. Some are climbers, some are runners, and some watch for a while first.",
                "Running, jumping, and balancing keep getting steadier well into the school years."
            ]

        case (.fineMotor, _):
            return [
                "Hand skills build in order: whole-hand grabbing first, then thumb and finger, then the finer control that drawing and buttons need.",
                "Most of this gets practised during eating, playing, and making a mess, rather than in anything that looks like an exercise.",
                "Small hands tire quickly, so short attempts are normal and they still count."
            ]

        case (.language, .infant):
            return [
                "Understanding comes before speaking. Looking when you point, turning to their name, and reaching to be picked up are all communication.",
                "Babbling, gestures, and pointing are the groundwork for words, and they carry as much weight now as spoken words will later.",
                "Children vary a lot in when words start. Some work on movement first and words follow in a rush."
            ]
        case (.language, .toddler), (.language, .preschool):
            return [
                "Vocabulary grows at very different rates. Following an instruction and putting two words together are big steps, even with few spoken words.",
                "Clear speech takes years to settle. For now, the attempt to be understood matters more than the pronunciation.",
                "The back-and-forth is what builds language: you say something, they answer, you answer that."
            ]

        case (.cognitive, _):
            return [
                "Thinking is hard to see from the outside. Working out where a dropped toy went, or which lid fits which box, is the work happening.",
                "Children learn by testing. Dropping, banging, and hiding things are how the rules of the world get checked.",
                "Attention is short at this age by design. A few minutes of real focus is a lot."
            ]

        case (.socialEmotional, .infant), (.socialEmotional, .toddler):
            return [
                "Big feelings arrive before the words to explain them, which is why so much of it comes out as crying.",
                "Wariness of strangers, and not wanting you to leave the room, are signs of attachment. They usually peak in the first two years.",
                "Tantrums are usually communication rather than defiance. Something is wrong and there is no other way to say it yet."
            ]
        case (.socialEmotional, .preschool):
            return [
                "Sharing and taking turns take years. Playing alongside another child rather than with them is normal well into the third year.",
                "Empathy builds slowly and mostly by copying. What children see handled calmly, they start handling calmly.",
                "Testing limits is how rules get learned. It is exhausting, and it is also a sign of growing independence."
            ]
        }
    }

    static let unfocused: [String] = [
        "There is a wide range in when children do things, and most of that range is ordinary. What you notice day to day is the useful record.",
        "Growth is uneven by nature. Children often work hard on one area while another sits still for a while.",
        "You see your child more than anyone else does. Writing down what you notice gives you something specific to look back on."
    ]

    /// Shown when the question carried nothing to work with. Asking for a little
    /// more is more honest than answering confidently about nothing.
    static let needsMore =
        "Tell me a bit more and the answer can be more specific. What your child is doing, or not doing yet, is enough to go on."
}
