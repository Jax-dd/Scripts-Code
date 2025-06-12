#!/bin/bash

if [[ "$EUID" -eq 0 ]]; then
  echo "❌ Don't run this script as root. It will ask for sudo when needed."
  exit 1
fi

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

if ! command_exists proxychains; then
  echo "❌ proxychains not found. Install it with: sudo apt install proxychains4"
  exit 1
fi

if ! command_exists tor; then
  echo "❌ tor is not installed. Install it with: sudo apt install tor"
  exit 1
fi

if ! systemctl is-active --quiet tor; then
  echo "🔌 Tor is not running. Starting it..."
  sudo systemctl start tor
fi

if ! systemctl is-enabled --quiet tor; then
  echo "🛠️ Tor is not enabled at boot. Enable it? (y/n)"
  read -r enable_tor
  if [[ "$enable_tor" == "y" ]]; then
    sudo systemctl enable tor
  fi
fi

declare -A countries=(
  [1]="US"
  [2]="NL"
  [3]="DE"
  [4]="FR"
  [5]="CA"
  [6]="CH"
  [7]="SE"
  [8]="GE"
)

echo "🌍 Select a Tor exit node country:"
for i in "${!countries[@]}"; do
  echo "$i) ${countries[$i]}"
done

read -rp "Enter the number corresponding to your choice: " choice
EXIT_NODE="${countries[$choice]}"

if [[ -z "$EXIT_NODE" ]]; then
  echo "❌ Invalid selection."
  exit 1
fi

echo "✍ Updating /etc/tor/torrc with ExitNodes {$EXIT_NODE}"

TORRC="/etc/tor/torrc"

sudo sed -i '/^# Custom ExitNode settings$/d' "$TORRC"
sudo sed -i '/^ExitNodes {.*}$/d' "$TORRC"
sudo sed -i '/^FastFirstHopPK 1$/d' "$TORRC"

echo -e "\n# Custom ExitNode settings" | sudo tee -a "$TORRC" > /dev/null
echo "ExitNodes {${EXIT_NODE}}" | sudo tee -a "$TORRC" > /dev/null
echo "FastFirstHopPK 1" | sudo tee -a "$TORRC" > /dev/null

echo "🔄 Restarting Tor service..."
sudo systemctl restart tor
sleep 2

echo -e "👤 Now launching LibreWolf via proxychains..."
echo -e "ℹ️ If this is your first time launching with profile 'proxy', LibreWolf may prompt you to create it."
echo -e "👉 Please manually create a profile named 'proxy' when prompted."

proxychains librewolf -P "proxy" -no-remote
