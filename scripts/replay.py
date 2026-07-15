#!/usr/bin/env python3
"""
Baha Mar demo — replay all code/data into a fresh org.
Usage: SF_DOMAIN=xxx.my.salesforce.com SF_CLIENT_ID=... SF_CLIENT_SECRET=... python3 replay.py [--skip-tests]
Deploys: objects+permset, apex(+tests), flow+queue, genAiFunctions+genAiPlugins, seed data, CORS/CSP.
Never deploys Bot/Planner (wizard-born only — see docs/new-org-runbook.md).
"""
import os, sys, json, time, re, zipfile, io, urllib.request, urllib.parse

DOMAIN = os.environ["SF_DOMAIN"].replace("https://", "").rstrip("/")
BASE = f"https://{DOMAIN}/services/data/v62.0"
META = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "salesforce-metadata")
META = os.path.abspath(META)

def get_token():
    data = urllib.parse.urlencode({"grant_type": "client_credentials",
        "client_id": os.environ["SF_CLIENT_ID"], "client_secret": os.environ["SF_CLIENT_SECRET"]}).encode()
    r = json.load(urllib.request.urlopen(urllib.request.Request(f"https://{DOMAIN}/services/oauth2/token", data=data)))
    return r["access_token"]

TOK = get_token()
print(f"[auth] token OK for {DOMAIN}")

def call(path, method="GET", data=None):
    req = urllib.request.Request(BASE + path, method=method,
        headers={"Authorization": "Bearer " + TOK, "Content-Type": "application/json"},
        data=json.dumps(data).encode() if data is not None else None)
    try:
        r = urllib.request.urlopen(req); b = r.read().decode()
        return json.loads(b) if b else {"http": r.status}
    except urllib.error.HTTPError as e:
        return {"ERR": e.code, "body": e.read().decode()[:400]}

def q(soql):
    return call("/query?q=" + urllib.parse.quote(soql))

def deploy_zip(zbytes, opts, label):
    boundary = "----bmdBoundary"
    jpart = json.dumps({"deployOptions": opts})
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"json\"\r\nContent-Type: application/json\r\n\r\n{jpart}\r\n"
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"deploy.zip\"\r\nContent-Type: application/zip\r\n\r\n").encode() + zbytes + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(BASE + "/metadata/deployRequest", data=body,
        headers={"Authorization": "Bearer " + TOK, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    did = json.load(urllib.request.urlopen(req))["id"]
    print(f"[deploy:{label}] id {did}", end=" ", flush=True)
    for _ in range(40):
        time.sleep(5)
        d = call(f"/metadata/deployRequest/{did}?includeDetails=true")["deployResult"]
        if d["status"] in ("Succeeded", "Failed", "Canceled"):
            print("->", d["status"])
            if d["status"] != "Succeeded":
                for f in (d.get("details", {}).get("componentFailures") or [])[:10]:
                    print("   FAIL:", f.get("fileName"), "-", f.get("problem", "")[:200])
                rt = d.get("details", {}).get("runTestResult") or {}
                for f in (rt.get("failures") or [])[:10]:
                    print("   TEST FAIL:", f["name"] + "." + f["methodName"], "-", f["message"][:150])
                sys.exit(1)
            return
        print(".", end="", flush=True)
    sys.exit(f"deploy {label} timed out")

def build_zip(entries, pkg_types):
    """entries: list of (zip_path, source_file_or_content_bytes)"""
    types_xml = "".join(
        "    <types>\n" + "".join(f"        <members>{m}</members>\n" for m in members) + f"        <name>{name}</name>\n    </types>\n"
        for name, members in pkg_types)
    pkg = f'<?xml version="1.0" encoding="UTF-8"?>\n<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n{types_xml}    <version>62.0</version>\n</Package>\n'
    buf = io.BytesIO()
    z = zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED)
    z.writestr("package.xml", pkg)
    for zpath, src in entries:
        z.writestr(zpath, open(src, "rb").read() if isinstance(src, str) else src)
    z.close()
    return buf.getvalue()

# ---------- Phase A: snapshot ----------
snap = {"domain": DOMAIN, "when": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
snap["agents"] = [r["DeveloperName"] for r in q("SELECT DeveloperName FROM BotDefinition").get("records", [])]
snap["org"] = q("SELECT Name, OrganizationType, TrialExpirationDate FROM Organization")["records"][0]
snap["org"].pop("attributes", None)
print("[snapshot]", json.dumps(snap))

# ---------- Phase B: objects + permset (agentAccesses stripped for initial deploy) ----------
objs = ["BahaMar_Reservation__c", "BahaMar_Experience__c", "BahaMar_Experience_Booking__c", "BahaMar_RFI__c"]
permset = open(f"{META}/permissionsets/BahaMar_Demo.permissionset").read()
permset_initial = re.sub(r"    <agentAccesses>.*?</agentAccesses>\n", "", permset, flags=re.S)
zb = build_zip(
    [(f"objects/{o}.object", f"{META}/objects/{o}.object") for o in objs] +
    [("permissionsets/BahaMar_Demo.permissionset", permset_initial.encode())],
    [("CustomObject", objs), ("PermissionSet", ["BahaMar_Demo"])])
deploy_zip(zb, {"singlePackage": True, "rollbackOnError": True, "testLevel": "NoTestRun"}, "objects+permset")

# ---------- Phase C: apex + tests ----------
classes = ["BahaMarVerifyGuest", "BahaMarSearchExperiences", "BahaMarBookExperience",
           "BahaMarUpdateReservationDates", "BahaMarCreateReservation", "BahaMarSaveRFI", "BahaMarActionsTest"]
entries = []
for c in classes:
    entries.append((f"classes/{c}.cls", f"{META}/classes/{c}.cls"))
    entries.append((f"classes/{c}.cls-meta.xml", f"{META}/classes/{c}.cls-meta.xml"))
opts = {"singlePackage": True, "rollbackOnError": True}
if "--skip-tests" in sys.argv:
    opts["testLevel"] = "NoTestRun"
else:
    opts["testLevel"] = "RunSpecifiedTests"; opts["runTests"] = ["BahaMarActionsTest"]
deploy_zip(build_zip(entries, [("ApexClass", classes)]), opts, "apex")

# ---------- Phase D: queue + flow ----------
zb = build_zip(
    [("queues/BahaMar_Fallback.queue", f"{META}/queues/BahaMar_Fallback.queue"),
     ("flows/BahaMar_Chat_Escalation.flow", f"{META}/flows/BahaMar_Chat_Escalation.flow")],
    [("Queue", ["BahaMar_Fallback"]), ("Flow", ["BahaMar_Chat_Escalation"])])
deploy_zip(zb, {"singlePackage": True, "rollbackOnError": True, "testLevel": "NoTestRun"}, "queue+flow")

# ---------- Phase E: genAiFunctions + genAiPlugins (NO bot/planner) ----------
funcs = ["BahaMar_Verify_Guest", "BahaMar_Search_Experiences", "BahaMar_Book_Experience",
         "BahaMar_Update_Reservation_Dates", "BahaMar_Create_Reservation", "BahaMar_Save_RFI"]
plugins = ["BahaMar_Guest_Verification", "BahaMar_Resort_Activities_QA", "BahaMar_Experience_Booking",
           "BahaMar_Reservation_Management", "BahaMar_Events_Group_Inquiries"]
entries = [(f"genAiFunctions/{f}/{f}.genAiFunction-meta.xml", f"{META}/genAiFunctions/{f}/{f}.genAiFunction-meta.xml") for f in funcs]
entries += [(f"genAiPlugins/{p}.genAiPlugin", f"{META}/genAiPlugins/{p}.genAiPlugin") for p in plugins]
deploy_zip(build_zip(entries, [("GenAiFunction", funcs), ("GenAiPlugin", plugins)]),
           {"singlePackage": True, "rollbackOnError": True, "testLevel": "NoTestRun"}, "agent-topics")

# ---------- Phase F: seed data ----------
def upsert_contact(first, last, email, desc):
    ex = q(f"SELECT Id FROM Contact WHERE Email='{email}'")["records"]
    if ex: return ex[0]["Id"]
    r = call("/sobjects/Contact", "POST", {"FirstName": first, "LastName": last, "Email": email, "Description": desc})
    assert r.get("success"), r
    return r["id"]

jason = upsert_contact("Jason", "Mitchell", "jason.mitchell@bahamar-demo.example",
    "DEMO: 42, fintech CMO, family of 4 (kids Ethan 11, Maya 8), golf, multigenerational luxury. Grand Hyatt profile.")
amy = upsert_contact("Amy", "Rodriguez", "amy.rodriguez@bahamar-demo.example",
    "DEMO: turns 30, account manager, 12-friend birthday group, premium lifestyle & party. SLS profile.")

for name, cid, ci, co, gc, rt, hotel in [
        ("BM-4271", jason, "2026-08-14", "2026-08-21", 4, "Grand Suite", "Grand Hyatt"),
        ("BM-5883", amy, "2026-09-11", "2026-09-14", 12, "Party Suite + 5 rooms", "SLS")]:
    if not q(f"SELECT Id FROM BahaMar_Reservation__c WHERE Name='{name}'")["records"]:
        r = call("/sobjects/BahaMar_Reservation__c", "POST", {"Name": name, "Contact__c": cid, "CheckIn__c": ci,
            "CheckOut__c": co, "GuestCount__c": gc, "RoomType__c": rt, "Hotel__c": hotel, "Status__c": "Booked"})
        assert r.get("success"), r
print("[seed] contacts + reservations OK")

EXPS = [
 ("Turtle Tales","A 20-minute hands-on encounter with our resident green sea turtles at The Sanctuary - touch, feed, and learn from our conservation team. Ages 8-12 must be accompanied by a paying adult; no guests under 8.",8,89,"Thursday-Monday, sessions at 11:00 AM and 2:30 PM",10),
 ("Flamingo Encounter","Meet Baha Mar's iconic Caribbean flamingo flock up close at Flamingo Cay with the keepers. Don't miss the free flamingo parade daily at 9:30 AM.",5,45,"Daily at 10:00 AM, 1:15 PM, and 4:15 PM - limited capacity",12),
 ("Royal Blue Golf Round","The Bahamas' only Jack Nicklaus Signature course - dunes on the front nine, limestone moonscapes and an island green on the back. All-in package includes premium rental clubs, ProV1s, and an engraved bag tag.",12,325,"Tee times daily from 7:00 AM",4),
 ("Explorers Club Session","Supervised kids club for ages 3-12 (potty-trained) with themed programming - cooking, crafts, wildlife visits, and movie time. Three-hour sessions.",3,65,"Daily sessions 9:00 AM-12:00 PM and 1:00 PM-4:00 PM",20),
 ("ESPA Signature Treatment","A restorative 80-minute signature treatment at the Caribbean's first ESPA - 30,000 square feet of spa inspired by the beauty of The Bahamas.",18,295,"Daily 9:00 AM-7:00 PM",1),
 ("Privilege Pool Daybed","Reserved daybed at SLS's adults-only pool club - DJs every Friday and Saturday. Minimum spend applies, seats two.",18,500,"Thursday-Sunday 11:00 AM-6:00 PM; DJs Fri-Sat",2),
 ("Bond VIP Table","VIP table with bottle service at Bond, the 10,000 sq ft nightclub inside SLS. Smart dress code - collared shirts, no beachwear. 18+.",18,1500,"Friday & Saturday 11:00 PM-4:00 AM",10),
 ("Baha Bay Luxury Cabana","Private cabana at Baha Bay, our luxury beachfront waterpark - park entry is already included for all resort guests; the cabana adds shade, service, and a dedicated host.",0,650,"Daily 10:00 AM-6:00 PM",8),
]
for name, desc, minage, price, sched, cap in EXPS:
    if not q(f"SELECT Id FROM BahaMar_Experience__c WHERE Name='{name}'")["records"]:
        r = call("/sobjects/BahaMar_Experience__c", "POST", {"Name": name, "Description__c": desc,
            "MinAge__c": minage, "Price__c": price, "Schedule__c": sched, "Capacity__c": cap})
        assert r.get("success"), r
print("[seed] experiences OK:", q("SELECT COUNT() FROM BahaMar_Experience__c")["totalSize"])

# ---------- Phase G: CORS + CSP ----------
if not any("bahamardemo" in (r.get("UrlPattern") or "") for r in q("SELECT UrlPattern FROM CorsWhitelistEntry").get("records", [])):
    print("[cors]", call("/sobjects/CorsWhitelistEntry", "POST", {"UrlPattern": "https://bahamardemo.netlify.app"}))
r = call("/tooling/sobjects/CspTrustedSite", "POST", {"DeveloperName": "BahaMarDemoSite", "MasterLabel": "BahaMar Demo Site",
    "EndpointUrl": "https://bahamardemo.netlify.app", "IsActive": True, "Context": "All",
    "IsApplicableToConnectSrc": True, "IsApplicableToFrameSrc": True, "IsApplicableToImgSrc": True,
    "IsApplicableToStyleSrc": True, "IsApplicableToFontSrc": True, "IsApplicableToMediaSrc": True})
print("[csp]", "OK" if r.get("success") or "DUPLICATE" in str(r) else r)

# ---------- Phase H: run-as user permset ----------
me = json.load(urllib.request.urlopen(urllib.request.Request(f"https://{DOMAIN}/services/oauth2/userinfo",
    headers={"Authorization": "Bearer " + TOK})))
ps = q("SELECT Id FROM PermissionSet WHERE Name='BahaMar_Demo'")["records"][0]["Id"]
if not q(f"SELECT Id FROM PermissionSetAssignment WHERE PermissionSetId='{ps}' AND AssigneeId='{me['user_id']}'")["records"]:
    print("[permset->run-as]", call("/sobjects/PermissionSetAssignment", "POST", {"PermissionSetId": ps, "AssigneeId": me["user_id"]}))

print("""
[DONE] Replay complete. Manual steps remaining (see docs/new-org-runbook.md):
  1. Builder: attach the 5 BahaMar topics to the wizard-created agent; Messaging connection; Activate
  2. Assign BahaMar_Demo permset to the wizard-created BOT USER (rerun this note once you know its username)
  3. Publish the Embedded Service deployment; send site URL for the landing-page re-point
""")
