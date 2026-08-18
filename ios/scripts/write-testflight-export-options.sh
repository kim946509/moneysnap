#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: write-testflight-export-options.sh <team-id> <output.plist>" >&2
  exit 64
fi

team_id=$1
output=$2

if [[ ! "$team_id" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Apple Team ID must be 10 alphanumeric characters" >&2
  exit 65
fi

cat > "$output" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$team_id</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF
