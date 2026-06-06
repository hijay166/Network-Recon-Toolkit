#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  Network Recon Toolkit
#  Author : Tobi Bolaji (@hijay166)
#  GitHub : https://github.com/hijay166
#  Purpose: Automated network reconnaissance for pentest engagements
#  Usage  : sudo ./recon.sh <target_ip_or_range> [output_dir]
#  WARNING: Authorised testing ONLY
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
BOLD='\033[1m'

banner() {
cat << 'EOF'
 ____                      _____           _   _    _ _
|  _ \ ___  ___ ___  _ __ |_   _|__   ___ | | | | _(_) |_
| |_) / _ \/ __/ _ \| '_ \  | |/ _ \ / _ \| | | |/ / | __|
|  _ <  __/ (_| (_) | | | | | | (_) | (_) | | |   <| | |_
|_| \_\___|\___\___/|_| |_| |_|\___/ \___/|_| |_|\_\_|\__|

   Network Recon Toolkit — Tobi Bolaji (@hijay166)
   For authorised penetration testing only.
EOF
}

# ── Helpers ───────────────────────────────────────────────────
log()  { echo -e "${BLUE}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[-]${NC} $1"; }
vuln() { echo -e "${RED}[!]${NC} ${BOLD}$1${NC}"; }
sep()  { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        warn "Tool not found: $1 — install with: sudo apt install $1"
        return 1
    fi
    return 0
}

# ── Arguments ─────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <target> [output_dir]"
    echo "  target     : IP, hostname, or CIDR range (e.g. 10.10.10.0/24)"
    echo "  output_dir : Where to save results (default: ./recon_<target>_<date>)"
    exit 1
fi

TARGET="$1"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SAFE_TARGET=$(echo "$TARGET" | tr '/' '_' | tr '.' '_')
OUTDIR="${2:-./recon_${SAFE_TARGET}_${TIMESTAMP}}"
REPORT="$OUTDIR/report.md"

mkdir -p "$OUTDIR"

# ── Start ─────────────────────────────────────────────────────
clear
banner
sep

log "Target    : $TARGET"
log "Output    : $OUTDIR"
log "Started   : $(date)"
sep

# Initialise report
cat > "$REPORT" << MDEOF
# Recon Report — $TARGET

**Date:** $(date)
**Tester:** Tobi Bolaji (@hijay166)
**Target:** \`$TARGET\`

---

MDEOF

append() { echo -e "$1" >> "$REPORT"; }


# ── Phase 1: Host Discovery ───────────────────────────────────
sep
log "Phase 1: Host Discovery"
append "## Phase 1: Host Discovery"

if check_tool netdiscover; then
    log "Running netdiscover (ARP scan)..."
    timeout 30 netdiscover -r "$TARGET" -P -N 2>/dev/null \
        | tee "$OUTDIR/netdiscover.txt" || true
    append "\`\`\`"
    cat "$OUTDIR/netdiscover.txt" >> "$REPORT" 2>/dev/null || true
    append "\`\`\`\n"
fi

if check_tool nmap; then
    log "Running Nmap ping sweep..."
    nmap -sn "$TARGET" -oN "$OUTDIR/ping_sweep.txt" 2>/dev/null
    ok "Hosts up:"
    grep "Nmap scan report" "$OUTDIR/ping_sweep.txt" | awk '{print $NF}' | tee "$OUTDIR/live_hosts.txt"
    append "### Live Hosts\n\`\`\`"
    cat "$OUTDIR/live_hosts.txt" >> "$REPORT"
    append "\`\`\`\n"
else
    warn "nmap not found — skipping host discovery"
fi


# ── Phase 2: Port Scanning ────────────────────────────────────
sep
log "Phase 2: Port Scanning"
append "## Phase 2: Port Scanning"

if check_tool nmap; then
    log "Quick scan — top 1000 ports..."
    nmap -sV --open -T4 "$TARGET" -oN "$OUTDIR/nmap_quick.txt" 2>/dev/null
    ok "Quick scan complete"

    log "Full port scan (all 65535)..."
    nmap -p- --open -T4 "$TARGET" -oN "$OUTDIR/nmap_full.txt" 2>/dev/null &
    NMAP_FULL_PID=$!

    log "Vuln script scan on common ports..."
    nmap -sV -sC --script=vuln -p 21,22,23,25,53,80,110,111,135,139,143,443,445,993,995,1723,3306,3389,5900,8080,8443 \
        "$TARGET" -oN "$OUTDIR/nmap_vuln.txt" 2>/dev/null
    ok "Vuln scan complete"

    wait $NMAP_FULL_PID 2>/dev/null || true
    ok "Full port scan complete"

    append "### Quick Scan Results\n\`\`\`"
    cat "$OUTDIR/nmap_quick.txt" >> "$REPORT"
    append "\`\`\`\n"
fi


# ── Phase 3: Service Enumeration ──────────────────────────────
sep
log "Phase 3: Service Enumeration"
append "## Phase 3: Service Enumeration"

# SMB
if check_tool enum4linux; then
    log "SMB/Samba enumeration with enum4linux..."
    enum4linux -a "$TARGET" 2>/dev/null | tee "$OUTDIR/enum4linux.txt" || true
    append "### SMB Enumeration (enum4linux)\n\`\`\`"
    head -80 "$OUTDIR/enum4linux.txt" >> "$REPORT" 2>/dev/null || true
    append "...\n\`\`\`\n"
fi

# SMB signing check
if check_tool nmap; then
    log "Checking SMB signing..."
    SMB_OUT=$(nmap --script smb-security-mode,smb2-security-mode -p 445 "$TARGET" 2>/dev/null)
    echo "$SMB_OUT" | tee "$OUTDIR/smb_signing.txt"
    if echo "$SMB_OUT" | grep -qi "message_signing: disabled"; then
        vuln "SMB Signing DISABLED on $TARGET — vulnerable to relay attacks!"
        append "### ⚠️ SMB Signing DISABLED — Relay attack possible!\n"
    fi
fi

# HTTP/HTTPS
log "HTTP enumeration..."
for PORT in 80 443 8080 8443 8000; do
    PROTO="http"; [[ $PORT == 443 || $PORT == 8443 ]] && PROTO="https"
    URL="${PROTO}://${TARGET}:${PORT}"
    RESP=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "$URL" 2>/dev/null || echo "000")
    if [[ "$RESP" != "000" ]]; then
        ok "HTTP service found: $URL (HTTP $RESP)"
        append "### HTTP Service: $URL (Status: $RESP)\n"

        if check_tool nikto; then
            log "Running Nikto on $URL..."
            nikto -h "$URL" -o "$OUTDIR/nikto_${PORT}.txt" -Format txt 2>/dev/null &
        fi
    fi
done

# FTP anonymous
log "Checking FTP anonymous access..."
FTP_RESP=$(curl -sk --max-time 5 "ftp://$TARGET" --user "anonymous:anon@test.com" 2>/dev/null || echo "")
if [[ -n "$FTP_RESP" ]]; then
    vuln "Anonymous FTP access enabled on $TARGET!"
    append "### ⚠️ Anonymous FTP access enabled!\n"
fi

# SSH version
if check_tool nmap; then
    log "Grabbing SSH banner..."
    nmap -p 22 --script=ssh-hostkey,ssh2-enum-algos "$TARGET" \
        -oN "$OUTDIR/ssh_enum.txt" 2>/dev/null
fi


# ── Phase 4: Vulnerability Flags ─────────────────────────────
sep
log "Phase 4: Quick Vulnerability Checks"
append "## Phase 4: Vulnerability Flags"

if check_tool nmap; then
    log "Checking for EternalBlue (MS17-010)..."
    MS17=$(nmap -p 445 --script=smb-vuln-ms17-010 "$TARGET" 2>/dev/null)
    echo "$MS17" | tee "$OUTDIR/ms17010.txt"
    if echo "$MS17" | grep -qi "VULNERABLE"; then
        vuln "MS17-010 (EternalBlue) DETECTED on $TARGET!"
        append "### 🔴 CRITICAL: MS17-010 (EternalBlue) VULNERABLE\n"
    fi

    log "Checking for BlueKeep (CVE-2019-0708)..."
    BK=$(nmap -p 3389 --script=rdp-vuln-ms12-020 "$TARGET" 2>/dev/null)
    if echo "$BK" | grep -qi "VULNERABLE"; then
        vuln "BlueKeep / RDP vulnerability DETECTED!"
        append "### 🔴 CRITICAL: RDP Vulnerability DETECTED\n"
    fi
fi


# ── Phase 5: Wait for background jobs ────────────────────────
sep
log "Phase 5: Waiting for background scans..."
wait 2>/dev/null || true
ok "All scans complete"


# ── Final Report ─────────────────────────────────────────────
sep
append "---"
append "## Summary"
append "| Phase | Tool | Output File |"
append "|-------|------|-------------|"
append "| Host Discovery | nmap / netdiscover | \`live_hosts.txt\` |"
append "| Port Scan | nmap | \`nmap_quick.txt\`, \`nmap_full.txt\` |"
append "| Vuln Scan | nmap --script=vuln | \`nmap_vuln.txt\` |"
append "| SMB Enum | enum4linux | \`enum4linux.txt\` |"
append "| Web Enum | nikto | \`nikto_*.txt\` |"
append ""
append "*Report generated by Network Recon Toolkit — Tobi Bolaji (@hijay166)*"

ok "Report saved to: $REPORT"
log "All output files in: $OUTDIR/"
echo ""
echo -e "${GREEN}${BOLD}Recon complete!${NC}"
echo -e "  Report : $REPORT"
echo -e "  Files  : $OUTDIR/"
sep
