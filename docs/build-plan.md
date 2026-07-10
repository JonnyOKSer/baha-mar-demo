# Baha Mar Agentforce Demo — Build Plan

**Target:** demo week of Jul 20 (dry-run Jul 16–17) · **Org:** existing Stella Agentforce trial org, **new agent** alongside Stella's (piggyback the framework/setup, don't touch the existing agent) · **Owner:** Aquiva

## Scope

Split confirmed (Jul 10): **all MCN email/SMS scenes are Salesforce; every AI Concierge / Agentforce touchpoint is Aquiva.**

In scope (Aquiva):

- **Scene J1 — Jason, web AI Concierge (unknown user).** Anonymous visitor asks about family vacations; no identity, no reservation context.
- **Scene J2 (concierge half) — Jason, second website visit (known user).** Returns via MCN abandonment email; chat now recognizes him (pre-chat/session identity) and helps him complete the booking. The abandonment email itself is Salesforce.
- **Scene J5 — Jason, web AI Concierge (authenticated).** Family activities Q&A; books tours/classes for his kids (swim with turtles, flamingo sanctuary).
- **Scene A1 — Amy, web AI Concierge + Meetings & Events RFI form.** Concierge steers her to a group-celebration RFI; **decided: form abandoned mid-fill** — partial capture (concierge-collected details saved as a Lead/RFI record even though the form is never submitted) is what MCN's follow-up hangs off.
- **Scene A2 (Agentforce half) — Amy books after follow-up (decided).** The sales-manager follow-up email is Salesforce; the booking she completes off the back of it ("she books") runs through our concierge, same known-user pattern as J2 — creates the 12-person `Reservation__c` that A3 later modifies.
- **Scene A3 — Amy, WhatsApp AI Concierge.** Authenticates with name + confirmation number, asks about date-change policies, agent updates her 12-person reservation dates.

Out of scope (Salesforce): all MCN sends — booking-abandonment email (J2), sales-manager follow-up email (A2), pre-stay and in-stay email + SMS (J3/J4, A4/A5).

Rule of thumb from Jonny: wherever the outline says "(Aquiva)", take it literally — that component is ours.

## WhatsApp approach (decided)

**Simulated WhatsApp UI**: a web page styled as a phone running WhatsApp, wired to the agent via the **Agentforce Agent API** (REST, session-based). No Meta business verification, no WhatsApp Business Account, no Digital Engagement licensing — none of which a trial org realistically supports in 1–2 weeks (Meta verification alone is 2–10 business days, plus a dedicated number).

Positioning in the demo: "the channel is interchangeable — this same agent attaches to a real WhatsApp number via Digital Engagement in production." That statement is accurate; enhanced WhatsApp is a standard Messaging channel routed to the same agent via Omni-Flow.

Optional upgrade if time allows (not on critical path): Twilio WhatsApp Sandbox bridged to the Agent API with ~100 lines of middleware — real messages on a real phone, but the recipient must first send `join <code>`, which is awkward live. Keep as stretch goal only.

## Step 0 — Org audit (Day 1, blocks everything)

Verify in the Stella trial org before building:

| Check | Where | Why |
|---|---|---|
| Agentforce enabled + agent activatable | Setup → Agentforce Agents | Base requirement |
| Einstein request limits remaining on trial | Setup → Usage | Trials have capped LLM requests; a demo dry-run burns them |
| Trial expiry date | Company Information | Must outlive the demo date + buffer |
| Data Library / file upload for grounding | Agentforce Data Library | Needed for activities & policy Q&A |
| MIAW (Messaging for In-App and Web) deployable | Setup → Messaging Settings | Jason's web chat scene |
| Connected app + client-credentials OAuth possible | Setup → App Manager | Agent API for the WhatsApp simulator |
| Flow + Apex allowed | — | Custom agent actions |

If MIAW isn't available in the trial, Jason's scene falls back to the same Agent API approach with a web-styled chat widget — same build as the WhatsApp simulator, different skin.

## Data setup

Keep it minimal — only what the two scenes touch.

**Contacts:** Jason (family of 4, preferences: golf, kids 8 & 11) and Amy (birthday group, party/lifestyle preferences).

**Custom objects:**

- `Reservation__c` — ConfirmationNumber, Contact, CheckIn, CheckOut, GuestCount, RoomType, Status. One record each: Jason (booked, family of 4) and Amy (booked, 12 guests, dates that need moving).
- `Experience__c` — Name, Description, MinAge, Price, Schedule, Capacity. Seed ~8 records from bahamar.com content: Swim with Turtles, Flamingo Sanctuary visit, Royal Blue golf, kids club, spa, cabana/pool party, etc.
- `Experience_Booking__c` — Reservation, Experience, Date, PartySize, Status.

**Knowledge grounding:** Data Library with 2–3 curated files built from bahamar.com — resort/activities overview (Jason Q&A), reservation change & cancellation policy (Amy Q&A), group booking info. Curated files beat scraping: predictable answers on demo day.

## Agent design

One agent: **"Baha Mar Concierge"** — created new in the Stella org, reusing the org's Agentforce setup (Data Library, connected app, Einstein config) without touching Stella's existing agent. Five topics:

1. **Guest Verification** — collects name + confirmation number, Flow action matches `Reservation__c`, stores verified reservation in context. Amy's entry point; Jason's web scene can pass identity via pre-chat/session variables instead ("authenticated").
2. **Resort & Activities Q&A** — grounded on the Data Library. Answers family-activity and facility questions for both personas.
3. **Experience Booking** — Flow/Apex actions: `Search Experiences` (filter by age, date) and `Book Experience` (creates `Experience_Booking__c`, confirms back with details). Jason's scene: books turtle swim + flamingo sanctuary for the kids.
4. **Reservation Management** — answers change-policy questions from knowledge, then `Update Reservation Dates` Flow action (verified reservation only, confirms new dates + guest count = 12 before committing).
5. **Events & Group Inquiries** — Amy's E1 path: answers celebration/group questions from knowledge, then `Capture RFI` Flow action (creates Lead or `RFI__c` with event type, date, headcount, contact info). **Abandoned-mid-fill design:** the concierge collects details conversationally and saves the RFI record incrementally, so when Amy disconnects before "submitting," a partial record with her contact info already exists — that record is MCN's follow-up trigger.

The unknown-vs-known distinction (J1 vs J2/J5) is the same MIAW deployment: anonymous session for J1, pre-chat/hidden identity fields for the known-user scenes. No separate build — just two entry points on the mock page.

Guardrails: no payment handling, no cancellations (redirect to phone), stay on resort topics.

## Channels

**Jason (web):** MIAW embedded chat on a single mock Baha Mar landing page (hero image + "Chat with our Concierge"). Pre-chat/hidden fields identify him as a known guest.

**Amy (WhatsApp simulator):** single-page web app, WhatsApp visual chrome (header with Baha Mar profile, green bubbles, ticks, typing indicator), phone-frame wrapper for projection. Backend: Agent API — create session → exchange messages → same agent, same topics. Host as static page (or Experience Cloud page in the org).

## Build sequence

**Week 1**

- Day 1: org audit; confirm/park fallbacks. Create data model + seed records.
- Day 2–3: agent topics, instructions, Flow actions (incl. `Capture RFI`); Data Library content. Test in Agent Builder preview.
- Day 4: MIAW deployment + mock landing page with anonymous and known-user entry points, plus the Meetings & Events RFI form (Jason J1/J2/J5 and Amy A1 end-to-end).
- Day 5: Agent API connected app + WhatsApp simulator page (Amy scene end-to-end).

**Week 2**

- Dry-run both scenes against the demo script; tune topic instructions where the agent picks the wrong action or answers thinly.
- Polish: WhatsApp simulator visuals, landing page branding, scripted conversation cheat-sheet for the presenter.
- Record a full run-through video as demo-day insurance.

## Demo script beats

**Jason J1 (anonymous):** opens bahamar.com mock page → chat: "Planning a family trip with two kids — what's Baha Mar like for families?" → agent gives grounded overview, no personal context. (Handoff beat: he leaves; Salesforce shows the MCN abandonment email.)

**Jason J2 (known user):** returns from the email → chat greets him by name → helps him pick a room/package and complete the booking.

**Jason J5 (web, authenticated):** chat: "What is there for kids at the resort?" → agent lists grounded activities → "Book the swim with turtles for my two kids on Tuesday" → agent confirms booking with details → show `Experience_Booking__c` record in the org (the "and it's real CRM data" moment).

**Amy A1 (web + RFI):** chat: "I want to celebrate my 30th with a big group" → agent answers, steers to the Meetings & Events RFI form → she starts filling it and disconnects → show the partial Lead/RFI record MCN will follow up on. (Handoff beat to Salesforce's A2 email.)

**Amy A2 (booking after follow-up):** returns from the sales-manager email → known-user chat → confirms party package and books for the group → `Reservation__c` created (12 guests — the record A3 later modifies).

**Amy A3 (WhatsApp):** WhatsApp message: "Hi, I need to change my reservation" → agent asks name + confirmation number → verifies → "What's your date change policy?" → grounded policy answer → "Move us to the following weekend, we're 12 people" → agent confirms old vs. new dates, updates → show updated `Reservation__c`.

## Risks

- **Trial org limits** (Einstein requests, expiry): audit Day 1; if tight, request a fresh trial immediately — data/agent setup is scripted and repeatable.
- **Agent API not available in trial**: fall back to MIAW behind the WhatsApp skin (MIAW has a REST API too), or worst case run the simulator against scripted responses.
- **Non-deterministic agent answers live**: mitigate with tight topic instructions, curated knowledge, rehearsed prompts, and the recorded backup video.
- **"Is that really WhatsApp?" question from the room**: answer honestly — simulator for the demo, identical agent attaches to the real WhatsApp channel via Digital Engagement in production. Have the one-slide architecture ready.

## Repos & references

- **Demo repo (new):** https://github.com/aquivalabs/baha-mar-demo — all demo code (sfdx project, landing page, WhatsApp simulator) lives here.
- **Stella repo (piggyback source):** https://github.com/aquivalabs/aquiva-agentic-tth-loyalty — reference for org setup, agent metadata patterns, and anything reusable (connected app config, deploy scripts).
- **Stella frontend:** https://app.netlify.com/projects/aquiva-agentic-loyalty/overview — Netlify hosting pattern to reuse for the demo's landing page + simulator.

## Open items

- Access: sf CLI / login to the Stella trial org for whoever builds (I can do the audit + build with credentials).
- Agree handoff cues with Salesforce: where our concierge scenes end and their MCN sends pick up (J1→J2 abandonment email, A1→A2 follow-up email), so the joint run-through is seamless. Includes confirming the A2 interpretation (booking-via-concierge) with their team.

**Decided (Jul 10):** demo week of Jul 20 · A1 RFI abandoned mid-fill with incremental capture · A2 Aquiva piece = booking via concierge · new agent in the Stella org, existing agent untouched.
