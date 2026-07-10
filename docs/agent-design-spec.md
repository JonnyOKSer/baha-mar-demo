# Baha Mar Concierge — Agent Design Spec

New Agentforce Service Agent in the Stella trial org (existing Stella agent untouched). One agent serves all six Aquiva scenes across two channels.

## Identity & session handling per scene

| Scene | Channel | Identity state | Mechanism |
|---|---|---|---|
| J1 | Web chat | Anonymous | MIAW unverified session, no pre-chat fields |
| J2 | Web chat | Known (Jason) | Deep link from MCN email → pre-chat/hidden fields set ContactId |
| J5 | Web chat | Authenticated | Same as J2 + reservation context loaded on session start |
| A1 | Web chat + RFI form | Anonymous → semi-known | Concierge collects name/email conversationally; incremental RFI save |
| A2 | Web chat | Known (Amy) | Deep link from sales follow-up email → identified session |
| A3 | WhatsApp simulator | Verified in-conversation | Name + confirmation number → `Verify Guest` action |

Context variables: `Verified_Contact_Id`, `Verified_Reservation_Id`, `Channel`. Web identity comes in via MIAW hidden pre-chat fields; WhatsApp identity is established only through the Guest Verification topic.

## Topics

### 1. Guest Verification
- **Scope:** establish who the guest is before any reservation-touching action on unverified channels.
- **Instructions (draft):** "If the guest asks to view or change a reservation and is not verified, ask for full name and confirmation number, then call Verify Guest. Never reveal reservation details before verification succeeds. After two failed attempts, offer the phone line."
- **Action `Verify Guest` (Flow):** in: Name, ConfirmationNumber → matches `Reservation__c` (+ Contact) → out: ReservationId, ContactId, summary (dates, guests, room). Sets context variables.

### 2. Resort & Activities Q&A
- **Scope:** general questions about the resort, restaurants, pools, kids' programs, golf, spa. Grounded on Data Library only.
- **Instructions (draft):** "Answer only from retrieved knowledge. If asked about something not covered, say so and offer the concierge phone line. Tailor tone: families (J) vs. celebrations (A). Never invent prices or schedules."
- **No custom actions** — Answer Questions with Knowledge standard action.

### 3. Experience Booking
- **Scope:** find and book experiences (turtle swim, flamingo sanctuary, golf, cabanas...).
- **Instructions (draft):** "Use Search Experiences before recommending. Respect MinAge — Jason's kids are 8 and 11. Confirm experience, date, and party size back to the guest before calling Book Experience. Requires a verified/identified guest."
- **Action `Search Experiences` (Flow):** in: keyword?, date?, minAge?, partySize? → out: list (name, description, price, schedule, remaining capacity).
- **Action `Book Experience` (Flow):** in: ExperienceId, ReservationId, Date, PartySize → creates `Experience_Booking__c` (Status=Confirmed) → out: confirmation summary.

### 4. Reservation Management
- **Scope:** change policies (knowledge) + date changes (action). A3's topic. Also A2's booking creation.
- **Instructions (draft):** "Answer policy questions from knowledge first. For a date change: guest must be verified; restate current dates, proposed dates, and guest count; get an explicit yes before calling Update Reservation Dates. No cancellations — redirect to phone."
- **Action `Update Reservation Dates` (Flow):** in: ReservationId, NewCheckIn, NewCheckOut → validates verified context matches → updates `Reservation__c` → out: old vs. new summary.
- **Action `Create Reservation` (Flow, A2):** in: ContactId, CheckIn, CheckOut, GuestCount, RoomType → creates `Reservation__c` (generates confirmation number) → out: confirmation. Used when Amy books her group stay from the follow-up email.

### 5. Events & Group Inquiries
- **Scope:** celebrations, group events, meetings — Amy's A1 entry.
- **Instructions (draft):** "For group/event interest, answer venue and package questions from knowledge, then collect: event type, approximate date, headcount, name, email, phone — conversationally, one or two at a time. Call Save RFI after EACH new detail (upsert), so nothing is lost if the guest leaves. When all fields are gathered, mark the RFI Submitted and confirm a sales manager will follow up."
- **Action `Save RFI` (Flow, upsert):** in: RfiId?, EventType?, EventDate?, Headcount?, Name?, Email?, Phone? → upserts `RFI__c`, Status = `In Progress` until complete, then `Submitted` → out: RfiId.
- **Abandonment design (decided):** because the save is incremental, Amy disconnecting mid-flow leaves an `RFI__c` with Status=`In Progress` and her contact details — the record Salesforce's MCN follow-up (A2 email) triggers on. Demo beat: show this partial record in the org after she drops.

## Guardrails (agent-level)

No payments or card details; no cancellations (phone redirect); resort topics only; never expose other guests' data; reservation actions require verified context; escalation phrase → concierge phone line.

## Data model

**`Reservation__c`:** ConfirmationNumber (unique, e.g. BM-4271), Contact__c, CheckIn, CheckOut, GuestCount, RoomType, Status.
Seed: Jason — BM-4271, family of 4, booked. Amy — created live in A2 (12 guests); a pre-seeded fallback record exists in case A2 is skipped on demo day.

**`Experience__c`:** Name, Description, MinAge, Price, Schedule, Capacity.
Seed (~8, from bahamar.com): Swim with Turtles (min 6), Flamingo Sanctuary, Royal Blue Golf, Explorers Kids Club, ESPA Spa, Cabana Day, Sunset Cruise, Mixology Class.

**`Experience_Booking__c`:** Reservation__c, Experience__c, Date, PartySize, Status.

**`RFI__c`:** EventType, EventDate, Headcount, ContactName, Email, Phone, Status (In Progress / Submitted), Source (Concierge).

**Contacts:** Jason (preferences: golf, kids 8 & 11), Amy (30th birthday, party/lifestyle) — created when identified, or pre-seeded.

**Data Library files (3):** Resort & Family Activities overview · Reservation Change & Cancellation Policy · Groups, Events & Celebrations guide. All curated from bahamar.com — no live scraping.

## Channels & front ends

**Web (J1/J2/J5, A1/A2):** one mock Baha Mar landing page, MIAW embedded chat. Query param switches persona state: `?guest=anon` (J1/A1) vs `?guest=jason` / `?guest=amy` (sets hidden pre-chat fields — simulates the email deep link). RFI form lives on the same page (Meetings & Events section) for the A1 steer.

**WhatsApp simulator (A3):** phone-framed web page with WhatsApp chrome (Baha Mar business profile header, green/white bubbles, ticks, typing indicator), backed by the Agentforce Agent API (create session → send/receive). Same agent, same topics. Production story: identical agent attaches to real WhatsApp via Digital Engagement.

## Scene-to-design traceability

| Outline scene | Topics exercised | Actions fired | Proof-in-org moment |
|---|---|---|---|
| J1 | 2 | — | (none — anonymous) |
| J2 | 2, 4 | Create Reservation* | Jason's `Reservation__c` |
| J5 | 2, 3 | Search + Book Experience | `Experience_Booking__c` ×2 |
| A1 | 5 | Save RFI (incremental) | Partial `RFI__c`, Status=In Progress |
| A2 | 2, 4 | Create Reservation | Amy's 12-guest `Reservation__c` |
| A3 | 1, 4 | Verify Guest, Update Reservation Dates | Updated dates on `Reservation__c` |

*J2's booking beat can alternatively be shown as completing on the website (non-agent) if Salesforce prefers the email to land on the booking engine — confirm at the joint run-through.
