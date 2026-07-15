# Fresh Org Runbook — Baha Mar Demo

*Root cause confirmed (Tue): aquiva org cannot create new EinsteinServiceAgent users — "All Data Cloud permission set licenses are in use" (GenieDataPlatformStarterPsl: 0/Disabled). Stella predates the expiry and is grandfathered. No new agent can ever route there. Migration ≈ half a day.*

**Golden rule learned last week: wizard-born beats API-born for anything Agentforce-runtime (agent, channel, deployment). Do wizard steps FIRST, while the new org's licenses are pristine. My scripted deploys are for code/data only.**

## Phase 0 — Jonny: get the org (~15 min)

1. Sign up for a fresh **Agentforce trial org** (same signup used for the Stella org).
2. Log in, note the **My Domain URL** → paste it to me in chat.
3. Keep this org clean: no experiments before the runbook is done.

## Phase 1 — Jonny: wizard steps, in this exact order (~30 min)

1. **New Agent wizard**: Setup → Agentforce Agents → New Agent → Agentforce Service Agent → name **Baha Mar Concierge** → skip/deselect all sample topics → finish. (This is the step that failed in the old org — if it succeeds, we're home.) **Activate later, after topics attach.**
2. **Enhanced Chat channel + deployment wizard**: Messaging Settings → New Channel → **Enhanced Chat** → name **Baha Mar Web Chat** → Deployment Type Web → Domain: `bahamardemo.netlify.app` → finish (auto-creates the paired Embedded Service deployment).
3. **External Client App** (same recipe as last week): Callback `https://login.salesforce.com/services/oauth2/callback` · scopes **api, chatbot_api, sfap_api, refresh_token** (no `full`) · **Enable Client Credentials Flow** (no JWT) · after save: Policies → Client Credentials **Run As** = your admin user · send me Consumer Key + Secret (txt upload, same as before).

## Phase 2 — Me: scripted replay from the repo (~45 min, all API)

In order, all from `salesforce-metadata/` in the repo:

1. Org snapshot (rule-zero habit, even in a fresh org)
2. Deploy custom objects + `BahaMar_Demo` permset (4 objects, 31 components)
3. Deploy Apex actions + tests (RunSpecifiedTests — 6/6 must pass)
4. Deploy `BahaMar_Chat_Escalation` flow
5. Deploy the 6 **GenAiFunctions** (no schema.json!) and 5 **GenAiPlugins** — but **NOT** the Bot/Planner (the wizard made those)
6. Seed data: Jason (BM-4271) + Amy (BM-5883) contacts/reservations, 8 verified experiences
7. CORS + CSP entries for `bahamardemo.netlify.app`
8. Assign `BahaMar_Demo` permset to the wizard-created bot user + Run-As user

## Phase 3 — Jonny + me: assemble (~30 min)

1. Jonny in Builder: attach the five **BahaMar_** topics to the wizard agent → Connections → Messaging → channel **Baha Mar Web Chat**, escalation flow **BahaMar Chat Escalation** → Save → **Activate**
2. Jonny: confirm channel Omni-Channel Routing = Agentforce Service Agent → Baha Mar Concierge (wizard may have set it)
3. Jonny: **Publish** the Embedded Service deployment → send me the Code Snippet (or just the site URL — I can derive the rest)
4. Me: update landing page init (new orgId + site URL + config name) → push → Netlify auto-deploys
5. **Smoke test on bahamardemo.netlify.app** — the message that never got answered: "What is there for kids at the resort?"

## Phase 4 — same day, once chat is live

- Known-user pre-chat (J2/J5), full 5-beat web test per demo script
- **Data Library** (fresh org = working Data Cloud!): upload the 3 knowledge docs, add Answer Questions with Knowledge to the Q&A topic — the grounding story we wanted, 30-min timebox
- RFI form → Netlify Function → `BahaMar_RFI__c`
- Presenter cheat sheet + backup video (Wed), dry run Thu

## Out of scope for the new org

The old aquiva org keeps Stella untouched — we never broke anything there (rule zero held; every change was additive and prefixed). Our BahaMar_* metadata can stay dormant or be cleaned up post-demo.
