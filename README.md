# Baha Mar Demo — Aquiva + Salesforce

Aquiva's Agentforce side of the joint Baha Mar demo: AI Concierge (web + WhatsApp simulator).

- `docs/build-plan.md` — build plan, scope split, schedule (demo week of Jul 20, 2026)
- `docs/agent-design-spec.md` — agent topics, actions, data model, scene traceability
- `web/index.html` — mock Baha Mar landing page with concierge chat (persona switch: `?guest=anon|jason|amy`)
- `web/whatsapp.html` — WhatsApp simulator, Scene A3 (Amy's date change)

Prototypes are currently scripted (design stage); MIAW / Agent API wiring replaces the scripts during build. sfdx project for the agent metadata lands in `force-app/` next.
