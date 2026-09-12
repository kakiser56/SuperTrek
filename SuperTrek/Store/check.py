import re, sys
text = open("Store/AppStoreListing.md").read()
def section(name):
    m = re.search(r"^## " + re.escape(name) + r".*?\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    return m.group(1).strip()
limits = {"Name (30)": 30, "Subtitle (30)": 30, "Promotional text (170)": 170, "Description (4000)": 4000, "Keywords (100, comma separated)": 100}
ok = True
for name, limit in limits.items():
    n = len(section(name))
    flag = "OK " if n <= limit else "OVER"
    if n > limit: ok = False
    print(f"{flag} {name}: {n}/{limit}")
sys.exit(0 if ok else 1)
