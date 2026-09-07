//
//  ActivityBank.swift
//  Sproutly
//

import Foundation

/// Things a parent can actually do, by area and rough age.
///
/// Every pool holds more entries than any single reply shows. The previous
/// version stored exactly three activities for gross motor and fine motor and
/// then called `shuffled().prefix(3)`, which returns all three in a new order,
/// so those two domains could never say anything new however the question was
/// worded.
enum ActivityBank {

    enum Band {
        case infant      // under 12 months
        case toddler     // 12 to 23 months
        case preschool   // 24 months and up
    }

    static func activities(domain: MilestoneCategory, band: Band) -> [String] {
        switch (domain, band) {

        case (.grossMotor, .infant):
            return [
                "Tummy time, a few minutes at a stretch, several times a day",
                "Put a favourite toy just out of reach so there is a reason to stretch for it",
                "Sit them propped with cushions so they can practise holding steady",
                "Lay them on their back and let them kick at a cushion you hold",
                "Roll a soft ball past them so they turn their head and follow it"
            ]
        case (.grossMotor, .toddler):
            return [
                "Clear some floor and let them cruise between the sofa and a chair",
                "Hold a toy out so they have a reason to let go with one hand",
                "A sturdy push toy or a weighted box gives support without doing the work",
                "Walk along a line of cushions so each step needs a bit of balance",
                "Let them climb on and off a low step while you stay within reach"
            ]
        case (.grossMotor, .preschool):
            return [
                "A playground trip covers climbing, sliding, and balance in one go",
                "Play stop-and-go games to practise starting and stopping on cue",
                "Kick a ball back and forth, which needs a moment of balance on one leg",
                "Hop over a stick laid on the ground, then move it slightly higher",
                "Carry something light up the stairs so both hands are busy"
            ]

        case (.fineMotor, .infant):
            return [
                "Offer finger foods so they practise picking up small pieces",
                "Let them bang blocks together or stack cups",
                "Hold out a rattle so they have to open a hand to take it",
                "Give them fabric with different textures to pull at",
                "Let them squash and poke soft food on the tray"
            ]
        case (.fineMotor, .toddler):
            return [
                "Poke holes in playdough with a finger",
                "Post coins or lids through a slot cut in a box",
                "Scribble with chunky crayons, no picture required",
                "Let them try the spoon themselves, mess included",
                "Stack three or four blocks and let them knock the tower down"
            ]
        case (.fineMotor, .preschool):
            return [
                "Thread large beads or dry pasta onto a string",
                "Use tongs to move cotton balls from one bowl to another",
                "Tear paper into strips and glue them onto a sheet",
                "Practise the big buttons on a coat before the small ones",
                "Snip paper with safety scissors while you hold the sheet steady"
            ]

        case (.language, .infant):
            return [
                "Say what you are doing as you do it: washing the apple, now drying the apple",
                "Answer their babble as though it were a sentence, then wait",
                "Read books with rhyme and repetition so the same sounds come round again",
                "Sing songs with hand actions, like Itsy Bitsy Spider",
                "Name what they are looking at before they can ask about it"
            ]
        case (.language, .toddler):
            return [
                "Ask something, then wait longer than feels natural for an answer",
                "Say the whole word back rather than correcting: yes, that's a dog",
                "Give a choice out loud so there is a reason to answer: apple or banana",
                "Read the same favourite book and pause before the line they know",
                "Add one word to whatever they said: they say ball, you say big ball"
            ]
        case (.language, .preschool):
            return [
                "Ask what happens next in a story they already know",
                "Talk through the day at bedtime and let them fill in the parts",
                "Play games that need words to win, like I Spy",
                "Let them tell someone else about their day while you stay quiet",
                "Ask why questions and take the answer seriously, whatever it is"
            ]

        case (.cognitive, .infant):
            return [
                "Play peek-a-boo, then hide a toy under a blanket for them to find",
                "Drop a toy where they can see it land and let them look for it",
                "Give them containers with lids and let them work out which fits",
                "Show them a mirror and name who they are looking at",
                "Let them bang two things together and hear the difference"
            ]
        case (.cognitive, .toddler):
            return [
                "Sort things by colour or shape while tidying up",
                "Hide a toy under one of two cups and let them choose",
                "Read a simple story and ask what happens next",
                "Nest cups or boxes inside each other and take them apart again",
                "Let them press the buttons and see what each one does"
            ]
        case (.cognitive, .preschool):
            return [
                "Count real things out loud: three spoons, two shoes",
                "Do a jigsaw together and leave the last piece to them",
                "Play a simple matching or memory card game",
                "Ask them to fetch two things at once and see if both arrive",
                "Cook something together and let them follow the steps in order"
            ]

        case (.socialEmotional, .infant):
            return [
                "Name the feeling out loud: you look upset that the blocks fell",
                "Copy their expression back to them and see if they copy yours",
                "Keep goodbyes brief and calm, even when they protest",
                "Let them watch you greet other people",
                "Respond to the cry before working out the reason"
            ]
        case (.socialEmotional, .toddler):
            return [
                "Take turns rolling a ball back and forth",
                "Read books about feelings and talk about the pictures",
                "Say what will happen next so a change is less of a surprise",
                "Play out an everyday scene with dolls or toy animals",
                "Let them help with a small real job, like carrying the bread"
            ]
        case (.socialEmotional, .preschool):
            return [
                "Name your own feeling out loud so they hear it done",
                "Practise taking turns in a game with a clear end",
                "Talk through what happened after a meltdown, once it has passed",
                "Arrange time with one other child rather than a group",
                "Give a warning before leaving somewhere they are enjoying"
            ]
        }
    }

    static let general: [String] = [
        "Ten minutes on the floor, following whatever they are already interested in",
        "Go for a walk and name what you both see",
        "Read a favourite book again, even for the hundredth time",
        "Sing through the transitions, like bath time and cleaning up",
        "Let them lead the play for a while and see where it goes"
    ]
}
