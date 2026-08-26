# Sproutly Voice Audit

Date: 27 August 2026
Scope: Full repository review of user-facing copy, accessibility copy, milestone language, assistant responses, paywall, onboarding, education, settings, and the parent-facing report.

## Executive summary

Sproutly has the right product instinct: a small, private, offline companion that helps a parent notice what their child is doing, save it, and look back later. The visual system already carries much of the playfulness. The copy should therefore be simpler and more specific, with warmth coming from recognition of real family life rather than decorative emotion.

The current voice is inconsistent in four places:

1. It sometimes sounds like a generic parenting app: “Every small moment matters,” “beautiful part of the process,” and “best possible start.”
2. The Assistant sometimes sounds like a reassurance generator: “beautiful pace,” “journey,” “unique timeline,” and repeated heart emoji.
3. The app mixes observation language with scorecard language: saved, completed, observed, past due, worth discussing, needs support, and progress all appear around the same experience.
4. Punctuation creates an AI signature: em dashes, arrow separators, and occasional typographic punctuation in otherwise plain UI copy.

The recommended direction is: personal, plainspoken, observant, calm, and practical. The parent should feel, “This understands what I noticed today,” not, “This is trying to make me feel something.”

## Non-negotiable product guardrails

- Keep the protected navigation and structural headers exactly as they are: `Growth Domains`, `Recent Moments`, `Milestones`, `Assistant`, and `Settings`. Do not rename them during the voice pass.
- Preserve all factual meaning, corrected-age behavior, screening guidance, medical disclaimers, privacy claims, and data behavior.
- Keep milestone categories technically intact: `Gross Motor`, `Fine Motor`, `Language`, `Cognitive`, and `Social-Emotional`. A friendlier explanation may sit beside them, but the category values must not change.
- Do not imply diagnosis, treatment, certainty, delay, failure, or a medical result.
- Do not change the rule-based Assistant into an LLM or add network calls.
- Use ASCII hyphens in UI copy. Avoid em dashes, en dashes, arrow chains, and decorative separators. Use a full stop, comma, colon, or two short sentences instead.

## Voice decision

### The voice is

Like a thoughtful parent friend who is good at noticing details. Clear enough to use one-handed. Reassuring without promising an outcome. Playful only where it helps the child-friendly character of the product. Specific about what the parent can do next.

### The voice is not

An inspirational welcome card, a medical dashboard, a developmental scorecard, a sales page, or a substitute clinician.

### Writing rules

1. Start with what the parent sees, does, or wants to remember.
2. Prefer concrete verbs: notice, save, try, see, ask, share, remember, look back.
3. Use the child’s name whenever the current screen already has it.
4. Keep one idea per sentence. Most helper copy should be one or two short sentences.
5. Let the UI be playful. Let the words be grounded.
6. Replace emotional padding with useful specificity.
7. Use “not saved yet” or “you have not seen this yet” only when it is genuinely an observation state, never “past due” or “failed.”
8. Use “saved” for a parent action, “noticed” for a parent observation, and “milestone” only when referring to the catalog or feature. Avoid switching between observed, achieved, completed, and checked off without a reason.
9. Accessibility labels and hints should be concise and functional, not warmer or more verbose than the visible copy.
10. Avoid repeated “your little one.” Use “your child” as the default and the child’s name when available. Keep “little one” for an occasional onboarding moment if it earns its place.

## Findings by feature

### Onboarding - medium priority

The structure is strong and the reassurance step is useful. The copy becomes generic when it stacks slogans and abstract phrases. `Every small moment matters` and `Notice it. Save it. Come back to it.` are polished, but they sound authored for a brand deck rather than for a parent holding a phone.

Recommended direction:

- `Every small moment matters` -> `Keep the things you notice about your child`
- `Keep track of the small things your child does, so you can look back on them later.` -> `Save what you notice now. It is useful to have when you look back or talk with your pediatrician.`
- `How Sproutly Works` may stay. Keep `Notice`, `Save`, and `Look back` as the interaction model.
- `The small things your child does each day` -> `Notice what your child is doing day to day`
- `One tap saves it. That's the whole thing.` -> `Tap once to save what you noticed.`
- `See how much has changed since last month.` -> `Look back at what you have saved over time.`
- `Notice it. Save it. Come back to it.` -> `Notice something. Save it. Find it again later.`
- `There is no perfect timeline` may stay because it is direct and parent-reassuring. Remove the duplicate “own time” sentiment around it if the screen feels repetitive.
- `About Your Little One` -> `About Your Child` if the header is not protected on the implementation branch.
- `Did your baby arrive early?` -> `Was your child born early?` so the wording still works for older children and matches the rest of the app.

### Dashboard - high priority

The dashboard is conceptually personal, but `You’re [age]!` is a little performative and the numeric `completed / total` treatment can pull the screen toward a scorecard. Keep the existing protected headers, but make supporting copy sound like a snapshot of this child.

Recommended direction:

- `You're [age]!` -> `You have been getting to know [name] for [age].` If that is too long for the layout, use `At [age], here is what you have saved.`
- `[age]-month milestones` -> `Things to look for around [age] months` where the string is explanatory rather than a catalog label.
- `Five areas of growth` may stay as supporting copy. Do not rename the protected `Growth Domains` header.
- `What you've noticed` is on-brand and should be the standard section label for parent-saved moments.
- `What you save will show up here` -> `The things you save will show up here.`
- Avoid presenting “completed” as a child outcome in accessible text. Use `saved` or `marked as noticed` where the control is describing the parent’s action.

### Milestones - high priority

This is the core trust surface. `Saved` and `Your moment` are good. `Remove Milestone?`, `Delete Moment`, and `What made it special?` create a mixed vocabulary, and the standard catalog still risks feeling like a checklist when paired with progress counts.

Recommended direction:

- Keep `Milestones` as the navigation header.
- `Add moment` is a strong, personal CTA. Keep it.
- `What happened?` is clear. Keep it.
- `This is just for grouping - your own moments never affect how Sproutly reads your child's development.` -> `This only helps keep things organized. Your own moments are not used in the growth summary.`
- `Already happened` -> `I have noticed this` or `I have seen this` depending on the action label length.
- `Saves it straight away` -> `Saves it right away.`
- `A note, if you'd like` -> `Add a note, if you want to remember more.`
- `What made it special? (optional)` -> `Anything you want to remember? (optional)`
- `Your moment` -> `Saved by you` when the badge needs to distinguish parent-created entries from the catalog.
- `Remove Milestone?` -> `Remove this from your saved moments?` This keeps the destructive action tied to the parent’s saved record.
- `This will delete your saved memory, including any photo.` -> `This removes the saved moment and any photo attached to it.`
- `Delete Moment` -> `Delete saved moment` for accessibility and destructive action clarity.
- `Nothing here yet.` -> `Nothing saved here yet.`

Do not globally replace `completed`. Inspect each use. In a filter control it may be a stable product label, but in explanatory text it should usually become `saved` or `noticed`.

### Growth education - medium priority

`Things worth knowing` is one of the strongest labels in the app. The body is useful, but the long em-dash sentences and the phrase `Developmental screening` can make the page feel like a clinical explainer. Keep the facts; make the explanation more conversational.

Recommended direction:

- In the five-area explanation, use short sentences and colons instead of em dashes.
- `Watching how your child grows day to day...` -> `You already notice how your child is growing day to day. Sproutly helps you keep those observations in one place.`
- Keep the distinction between what a parent notices and what a doctor checks. That distinction builds trust.
- `Why noticing early helps` can stay, but replace `best possible start` with a concrete explanation about asking questions early.
- `Trust your instincts. You know your child best.` is warm but familiar. Use once, not as a repeated pattern across the Assistant and Insights.
- Keep screening ages aligned with the product decision recorded in `CLAUDE.md`. Do not silently add or remove a checkpoint during a copy pass.

### Development Focus - high risk

This is the most sensitive voice area. `Development Focus` is protected and can stay, but `from earlier ages`, `not saved yet`, `Worth discussing`, and `Early support can make a meaningful difference` need careful handling so the parent does not read a verdict about the child.

Recommended direction:

- `X milestones from earlier ages` -> `X things from earlier ages you have not saved yet`.
- `X not saved yet` -> `Not saved yet: X` or `You have not saved X here yet`, depending on layout.
- `Worth discussing` in a clinician-facing report is understandable, but pair it with `A good topic to bring to your pediatrician` in parent-facing UI if the label is exposed there.
- `Several milestones for this age haven’t been logged yet.` -> `There are a few things for this age that you have not saved yet. That does not tell us whether your child can do them.`
- `Your child’s doctor is a good person to talk this through with - and to suggest ways you can help.` -> `If you are wondering about any of these, bring your notes to your child’s doctor. They can help you decide what to do next.`
- `Early support can make a meaningful difference.` -> `If you have questions, asking early can help you find the right support.`
- Avoid “delay,” “overdue,” “needs support,” or “concern” in parent-facing copy unless the factual safety context requires it and the sentence clearly says the app is not making a finding.

The code currently contains hardcoded theme values in this view despite the project guidance saying views must use `Theme` roles. That is outside this voice audit, but Claude should not combine a copy pass with unrelated visual changes unless explicitly requested.

### Assistant - highest priority

The Assistant is where the AI-generated feeling is strongest even though the implementation is rule-based. It uses interchangeable reassurance templates and repeated emotional markers. The response should sound like a calm, informed parent guide, not a motivational coach.

Patterns to remove:

- `beautiful`, `journey`, `unique timeline`, `best possible start`, and repeated `You are doing a great job`.
- Heart emoji in pediatric guidance. The visual design already supplies warmth, and emoji can make safety guidance feel unserious or templated.
- Claims such as `your child is likely building the confidence they need` when the app does not have enough evidence to know that.
- `huge window of 'normal'` because the quotation marks and phrasing feel like generated reassurance.

Recommended response shape:

1. Acknowledge what the parent asked about.
2. State the ordinary, observable context without predicting the child.
3. Offer two or three everyday things to try.
4. Say when a pediatrician conversation is reasonable, without implying the app has diagnosed anything.

Example rewrite:

`Walking typically emerges between 9 and 18 months - a wide range. You can watch for how your child moves through the day and make room for safe floor play. If you are unsure or have noticed a change, bring that observation to your pediatrician.`

Use the child’s name in the response only when it improves clarity. Do not force personalization into every answer.

### Paywall and Pro - medium priority

The paywall is relatively good because it names the feature the parent just tapped. The weak phrase is `Unlock everything`, which is generic and sales-like, plus `One payment, yours forever`, which is familiar marketing copy.

Recommended direction:

- `Unlock everything` -> `Get Sproutly Pro`.
- `One payment, yours forever. No subscription.` -> `One payment. No subscription.`
- `Shareable moments` -> `Share cards` if the feature is specifically a card.
- `Cards for family and friends` -> `Make a simple card to send to family.`
- `Five looks, including one for siblings` -> `Choose from five app icons, including a sibling-friendly option.`
- Keep feature-specific headlines, but remove `their own story` if space is tight. It is abstract compared with `their own milestones`.

### Settings and account actions - medium priority

Settings is clear, but `Adjust your experience` is generic. Destructive actions are factual, which is good, but the accessibility hints can be more direct.

Recommended direction:

- `Adjust your experience` -> `Make Sproutly work the way you like.`
- `Reduce brightness for quiet evenings` -> `Makes the app darker for evening use.`
- `Adds another child with their own milestones` -> `Adds another child with a separate milestone list.`
- `Clears everything saved for this child, keeps their profile` -> `Removes saved progress for this child but keeps their profile.`
- `Removes all data and returns to welcome screen` -> `Deletes all children and saved moments, then returns to the welcome screen.`

### Report and share card - medium priority

The report must stay factual and clinician-friendly, but it should clearly say that it is a parent record, not a result. `Developmental Milestone Summary` is appropriate as a document title. `Family-recorded moments` is good.

Recommended direction:

- `X of Y milestones observed for this age.` -> `You have saved X of Y milestones listed for this age.`
- `Not yet observed, and typically expected some time ago:` -> `Not saved yet. These are commonly looked for earlier.`
- Keep the disclaimer intact. It is a trust asset, not a copy problem.
- Replace centered dots in compact metadata with commas or separate lines if the layout allows. This makes the document feel less templated.

## Terminology system

| Use this | When | Avoid as the default |
| --- | --- | --- |
| notice / noticed | Parent sees a behavior | observe / observational, unless needed for clinical precision |
| save / saved | Parent action or stored record | log, record, complete |
| moment | Parent-created entry | memory when the feature is not sentimental |
| milestone | Catalog item or feature name | skill, achievement |
| growth | Parent-facing general concept | development when it is not a factual or medical phrase |
| child | Default reference | little one repeated across screens |
| bring this to your pediatrician | Suggested next step | needs support, past due, delayed |

## Punctuation pass

Run a deliberate copy-only punctuation sweep after the wording pass:

- Replace em dash and en dash constructions in UI strings with periods, commas, or colons.
- Replace `Notice → Save → Look back` and `Settings → Pro Features` with plain text such as `Notice, save, and look back` or `Find it again in Settings under Pro Features.`
- Keep hyphens that are part of a real term such as `Social-Emotional` and `well-child`.
- Do not alter developer comments solely because they contain dashes. The user-facing audit should target strings.

## Acceptance checklist for Claude

- [ ] Search all `.swift` files for user-facing strings and accessibility strings before editing.
- [ ] Preserve protected headers and technical category values.
- [ ] Remove AI-signature punctuation from user-facing copy.
- [ ] Remove repeated decorative emotional language.
- [ ] Normalize parent action language around `notice`, `save`, and `look back`.
- [ ] Review Assistant responses as a complete set, not one string at a time.
- [ ] Preserve disclaimer and screening facts exactly in meaning.
- [ ] Search again for old phrases after editing.
- [ ] Check interpolation, Dynamic Type wrapping, buttons, alerts, and accessibility labels for clipping or awkward length.
- [ ] Build in Xcode and report any strings that were intentionally left unchanged for safety or factual reasons.

## Overall rating

Current voice: 6.5 / 10.

The foundation is thoughtful and more parent-aware than a typical generated app. The remaining gap is not a total rewrite. It is a consistency pass: fewer slogans, fewer emotional templates, more concrete observations, cleaner punctuation, and safer language around progress and medical context.

