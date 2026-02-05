#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

TS="$(date +%Y-%m-%d_%H%M%S)"
OUTDIR="$HOME/ROOK_HOUSEMAP_$TS"
mkdir -p "$OUTDIR"

note() { printf "\n## %s\n" "$1" >> "$OUTDIR/housemap.md"; }
cmd()  { printf "\n### $ %s\n" "$1" >> "$OUTDIR/housemap.md"; sh -c "$1" >> "$OUTDIR/housemap.md" 2>&1 || true; }

# Optional installs (Termux)
if command -v pkg >/dev/null 2>&1; then
  pkg install -y iproute2 coreutils >/dev/null 2>&1 || true
  # termux-api only if you want wifi info
  pkg install -y termux-api >/dev/null 2>&1 || true
fi

echo "# ROOK HouseMap Report ($TS)" > "$OUTDIR/housemap.md"

note "ROOK.CORE (this device)"
cmd "whoami"
cmd "hostname"
cmd "uname -a"
cmd "uptime"

note "Storage (Vault candidates)"
cmd "df -h"
cmd "ls -la \$HOME | sed -n '1,80p'"

note "Network (WormGate candidates)"
cmd "ip -br addr"
cmd "ip route"

# Termux Wi-Fi info if available
note "Wi-Fi (if termux-api available)"
cmd "command -v termux-wifi-connectioninfo && termux-wifi-connectioninfo"
cmd "command -v termux-wifi-scaninfo && termux-wifi-scaninfo | sed -n '1,120p'"

note "Neighbor table (local devices you can see)"
cmd "ip neigh"

# Build a starter graph (Graphviz DOT)
GW="$(ip route 2>/dev/null | awk '/default/ {print $3; exit}' || true)"
IP="$(ip -br addr 2>/dev/null | awk '/UP/ && $3 ~ /[0-9]+\./ {print $3; exit}' | cut -d/ -f1 || true)"

cat > "$OUTDIR/housemap.dot" <<EOF
digraph HOUSEMAP {
  rankdir=LR;
  node [shape=box];

  "ROOK.CORE\\n(this device)\\nIP:$IP" -> "WormGate\\n(backbone link)";
  "WormGate\\n(backbone link)" -> "ROUTER/GATEWAY\\n$GW";

  "ROUTER/GATEWAY\\n$GW" -> "Bishop/Pawn Relay\\n(mesh/extender/AP)";
  "ROOK.CORE\\n(this device)\\nIP:$IP" -> "Vault Node\\n(NAS/Drive/Closet Box)";
  "ROOK.CORE\\n(this device)\\nIP:$IP" -> "Forensic Mirror\\n(Offline Backup Disk)";
  "ROOK.CORE\\n(this device)\\nIP:$IP" -> "Quarantine Lock\\n(Isolated Folder/VLAN)";
}
EOF

echo
echo "DONE ✅"
echo "Report:   $OUTDIR/housemap.md"
echo "Graph:    $OUTDIR/housemap.dot"
echo
echo "If you have graphviz on Linux:"
echo "  dot -Tpng \"$OUTDIR/housemap.dot\" -o \"$OUTDIR/housemap.png\""
