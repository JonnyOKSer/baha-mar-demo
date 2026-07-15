# Baha Mar Demo — Fix & Finish Plan (Tue → Thu dry run)

*Written Monday Jul 13. Dry run: Thursday Jul 16. One blocker (web routing), then use-case completion.*

## The blocker, restated

Agent answers perfectly in Builder preview; web chat says "Agent not available." Sessions reach Salesforce but no AgentWork is ever created. Eliminated so far: domain allowlist (fixed), channel provenance (wizard-made channel same result), escalation config, bot user permissions (even Stella's grandfathered user). Stella works end-to-end. Last standing difference: **her Bot was created via the New Agent wizard; ours via Metadata API** — same wizard-does-hidden-registration pattern we already proved for channels and deployments. Also on the table: the org's Data Cloud PSL is 0/Disabled, which may hobble metadata-born service agents specifically.

## Tuesday AM — fix attempts, in order

**Attempt 1 (~30 min, highest confidence): wizard-born agent.**

1. Jonny: Setup → Agentforce Agents → **New Agent** → Agentforce Service Agent → name **Baha Mar Concierge v2** → complete the wizard (accept defaults; skip sample topics if offered).
2. Jonny in Builder: delete/disable its sample topics; **attach our five existing topics** (BahaMar Guest Verification, Resort & Activities Q&A, Experience Booking, Reservation Management, Events & Group Inquiries) — they're already in the org with actions wired.
3. Jonny: Connections → Messaging → channel **Baha Mar Web Chat**, escalation flow **BahaMar Chat Escalation** + message → Save → **Activate**.
4. Me: verify what the wizard auto-created that our API agent lacks (per-agent permset, presence/routing registrations) — this confirms or kills the theory for the writeup.
5. Update channel routing to point at v2, republish deployment if prompted. Test live. **I verify AgentWork + bot logs in the org within minutes.**

**Attempt 2 (if #1 fails, ~1 hr): forensic diff + escalate.**
Deep-compare every auto-artifact of the working wizard agent vs ours; check routing error logs. In parallel, Jonny pings the Salesforce trial contact about the **disabled Data Cloud PSL** — if service-agent routing requires it org-side, only they can fix it, and Tuesday is the last sane day to ask.

**Attempt 3 (decision gate Tuesday noon): pick the Thursday posture.**

- **Plan B (zero risk, already built):** dry run on `?mode=scripted` — the landing page plays all scripted scenes flawlessly — plus a live Builder-preview segment ("here's the real agent reasoning") plus showing real org records. Honest framing for Salesforce folks: web channel wiring pending an org licensing fix on their side.
- **Plan C (heavier, ~half day):** fresh Agentforce trial org. Everything we built is scripted and repeatable from the repo (objects, Apex, agent metadata, seed data ≈ 1 hour to replay); the wizard steps (channel/deployment/agent) are documented from this week. Only if the aquiva org is confirmed hobbled AND Salesforce can't fix it by Wednesday.

## Tuesday PM — web use cases (assuming fix lands)

- **J1 anonymous**: live already once routing works — test script beats.
- **J2/J5 known-user**: add hidden pre-chat fields to the deployment (Jonny: enable Pre-Chat "behind the scenes" fields; me: set them from the page per `?guest=jason`) so the agent greets Jason by name and Verify Guest is skipped on authenticated web.
- **A1 RFI capture**: test the conversational capture → partial `BahaMar_RFI__c` (already built agent-side).
- Full pass through the five web beats against the demo script; tune topic instructions where answers are thin.

## Wednesday — remaining pieces + rehearsal

- **RFI form wiring** (the page's Meetings & Events form): Netlify Function using the ECA creds creates `BahaMar_RFI__c` on submit (Netlify's servers have no sandbox restrictions). ~1 hr, me.
- **Amy A3 WhatsApp**: default = polished scripted simulator (already live at /whatsapp). Stretch if Tuesday went smoothly: back the simulator with the live channel's messaging REST API. Decision Wednesday 10am — no new risk taken after noon.
- **Presenter cheat sheet**: exact prompts per scene, expected responses, org tabs to have open (Reservation, Experience Booking, RFI records), fallback toggle instructions.
- **Record full run-through video** — demo-day insurance.
- Confirm with Salesforce team: A2 interpretation + handoff cues (J1→J2 email, A1→A2 email).

## Thursday — dry run

Run the runbook. Capture every rough edge in a punch list; Friday = polish day before demo week.

## Owner summary

| Who | Tuesday | Wednesday |
|---|---|---|
| Jonny | New Agent wizard + Builder topic attach + activate (AM); Salesforce ping re Data Cloud PSL | Salesforce team sync; rehearse presenter script |
| Me | Org verification, channel/deployment re-pointing, forensic diff, pre-chat identity, script-beat testing | RFI function, cheat sheet, runbook, backup video, (stretch) live WhatsApp |
