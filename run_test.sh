# Test category-based pruning logic
python3 - << 'PY'
import re

rules_file = "tests_suricata.rules"
disable_out = "tests_disable.sids"
drop_out = "tests_drop.sids"
allowed_cats = {"web-application-attack"}

SID_RE  = re.compile(r'\bsid:(\d+)')
CLS_RE  = re.compile(r'\bclasstype:(\S+?)(?:;|$|\s)')

disable_sids = set()

with open(rules_file) as f:
    for line in f:
        raw = line.strip()
        if raw.startswith('#'):
            raw = raw.lstrip('#').lstrip()
        m_sid = SID_RE.search(raw)
        if not m_sid:
            continue
        sid = m_sid.group(1)
        m_cls = CLS_RE.search(raw)
        cls = m_cls.group(1).rstrip(';') if m_cls else ''
        if allowed_cats and cls not in allowed_cats:
            disable_sids.add(sid)

with open(disable_out, 'w') as f:
    for sid in sorted(disable_sids, key=int):
        f.write(sid + '\n')

open(drop_out, 'w').close()
PY

echo "Disabled SIDs:"
cat tests_disable.sids

# Test Patching Logic
awk -v dis_file="tests_disable.sids" '
    BEGIN { while ((getline < dis_file) > 0) sids[$0] = 1 }
    {
        line = $0
        if (line ~ /sid:[0-9]+;/) {
            match(line, /sid:[0-9]+;/)
            sid_str = substr(line, RSTART + 4, RLENGTH - 5)
            if (sid_str in sids) {
                print "# " line
                next
            }
        }
        print line
    }
' tests_suricata.rules > tests_suricata-optimized.rules

echo "Optimized Rules:"
cat tests_suricata-optimized.rules

# Verification check
echo "Verification results:"
grep "^# " tests_suricata-optimized.rules | grep -q "sid:1003" && echo "PASS: SID 1003 (Priority 3) is commented out." || echo "FAIL: SID 1003 is NOT commented out."
grep "^alert" tests_suricata-optimized.rules | grep -q "sid:1001" && echo "PASS: SID 1001 (Priority 1) remains active." || echo "FAIL: SID 1001 is unexpectedly commented out."
