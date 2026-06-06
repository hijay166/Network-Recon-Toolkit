# Network-Recon-Toolkit
Network Recon Toolkit for Network Scanning 

# 🌐 Network Recon Toolkit

> Automated bash-based network reconnaissance toolkit for penetration testing engagements. Combines Nmap, Netdiscover, Enum4linux, and Nikto into a single script that produces a structured Markdown report.

**Author:** Tobi Bolaji | [@hijay166](https://github.com/hijay166)
**Certifications:** CompTIA Security+ | CompTIA Network+

---

## ⚠️ Legal Disclaimer

For **authorised penetration testing only**. Never scan networks or systems without explicit written permission. Unauthorised scanning is illegal under the Computer Misuse Act 1990 (UK) and equivalent laws globally.

---

## Features

- **Phase 1 — Host Discovery:** ARP scan (netdiscover) + Nmap ping sweep
- **Phase 2 — Port Scanning:** Quick top-1000, full 65535, and vuln script scans (parallel)
- **Phase 3 — Service Enumeration:** SMB (enum4linux), HTTP/HTTPS (Nikto), FTP, SSH banners
- **Phase 4 — Vuln Flags:** Auto-detects MS17-010 (EternalBlue), SMB signing disabled, anonymous FTP
- **Structured Markdown Report** auto-generated for every scan
- Colour-coded terminal output — highlights critical findings in red

---

## Installation

```bash
git clone https://github.com/hijay166/Network-Recon-Toolkit.git
cd Network-Recon-Toolkit
chmod +x recon.sh

# Install dependencies (Kali Linux / Debian)
sudo apt install -y nmap netdiscover enum4linux nikto curl
```

---

## Usage

```bash
# Single host
sudo ./recon.sh 10.10.10.1

# CIDR range
sudo ./recon.sh 10.10.10.0/24

# Custom output directory
sudo ./recon.sh 10.10.10.1 ./results/target1
```

---

## Output Structure

```
recon_10_10_10_1_20250101_120000/
├── report.md           ← Main structured report
├── live_hosts.txt      ← Discovered live hosts
├── ping_sweep.txt      ← Nmap ping sweep raw
├── nmap_quick.txt      ← Top 1000 port scan
├── nmap_full.txt       ← Full 65535 port scan
├── nmap_vuln.txt       ← Vuln script results
├── enum4linux.txt      ← SMB enumeration
├── smb_signing.txt     ← SMB signing status
├── ms17010.txt         ← EternalBlue check
├── ssh_enum.txt        ← SSH keys & algorithms
└── nikto_80.txt        ← Web vuln scan (per port)
```

---

## Example Terminal Output

```
[*] Phase 2: Port Scanning
[*] Quick scan — top 1000 ports...
[+] Quick scan complete
[*] Vuln script scan on common ports...
[!] SMB Signing DISABLED on 10.10.10.1 — vulnerable to relay attacks!
[!] MS17-010 (EternalBlue) DETECTED on 10.10.10.1!
[+] All scans complete
[+] Report saved to: ./recon_10_10_10_1_.../report.md
```

---

## Tools Used

`Nmap` · `Netdiscover` · `Enum4linux` · `Nikto` · `Bash` · `curl`

---

*Part of Tobi Bolaji's cybersecurity portfolio — [github.com/hijay166](https://github.com/hijay166)*
