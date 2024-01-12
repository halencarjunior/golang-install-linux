#!/bin/bash
#Author: bt0 (https://github.com/halencarjunior)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print messages in color
print_message() {
    echo -e "${2}${1}${NC}"
}

print_message "[!] Starting Go installation script..." "$YELLOW"

# Function to check if a command is installed
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if jq is installed
if ! command_exists jq; then
  print_message "[-] jq is not installed. Attempting to install..." "$RED"
  if [ -f /etc/debian_version ]; then
    # If the system is Debian-based, use apt-get to install jq
    sudo apt-get update
    sudo apt-get install -y jq
    print_message "\t[+] jq installed successfully." "$GREEN"
  else
    print_message "[-] jq is not installed, and this script does not support your system's package manager." "$RED"
    exit 1
  fi
fi

print_message "[!] Detecting system information..." "$YELLOW"
# Detect the OS, architecture, and shell
OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
SHELL=$(basename "$SHELL")

if [ "$ARCH" == "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" == "aarch64" ]; then
  ARCH="arm64"
else
  print_message "\t[-] Unsupported architecture: $ARCH" "$RED"
  exit 1
fi

print_message "[!] Fetching Go versions..." "$YELLOW"
# Fetch JSON from Go download API, follow redirects if any
JSON=$(curl -s -L https://golang.org/dl/?mode=json)
if [ -z "$JSON" ]; then
  print_message "\t[-] Failed to fetch Go versions JSON." "$RED"
  exit 1
fi

print_message "[!] Parsing JSON for download URL..." "$YELLOW"
# Parse JSON to get the download URL for the appropriate version
GO_URL=$(echo "$JSON" | jq -r --arg os "$OS" --arg arch "$ARCH" '.[0].files[] | select(.os==$os and .arch==$arch) | .filename' | head -1)

if [ -z "$GO_URL" ]; then
  print_message "\t[-] Failed to retrieve the download URL for Go." "$RED"
  exit 1
fi

# Define the directory where Go will be installed
INSTALL_DIR="/usr/local"

print_message "[!] Removing old Go installation if it exists..." "$YELLOW"
# Remove old Go installation
if [ -d "$INSTALL_DIR/go" ]; then
  sudo rm -rf "$INSTALL_DIR/go"
  print_message "\t[+] Old Go installation removed." "$GREEN"
fi

print_message "[!] Downloading Go..." "$YELLOW"
# Construct the full download URL
GO_URL="https://golang.org/dl/$GO_URL"

# Download and extract Go in silent mode
wget -q -O go.tar.gz "$GO_URL"
sudo tar -C "$INSTALL_DIR" -xzf go.tar.gz
rm go.tar.gz
print_message "\t[+] Go downloaded and installed." "$GREEN"

# Determine which profile file to use
PROFILE_FILE=""
if [ "$SHELL" = "zsh" ]; then
  PROFILE_FILE="$HOME/.zshrc"
elif [ "$SHELL" = "bash" ]; then
  PROFILE_FILE="$HOME/.bashrc"
else
  print_message "\t[-] Unsupported shell: $SHELL" "$RED"
  exit 1
fi

print_message "[!] Configuring environment variables..." "$YELLOW"
# Avoid duplicate entries in the profile file
if ! grep -q 'export GOPATH=~/go' "$PROFILE_FILE"; then
  mkdir -p ~/go/{bin,pkg,src}
  print_message "\t[+] Setting up GOPATH" "$GREEN"
  echo "export GOPATH=~/go" >> "$PROFILE_FILE"
fi

if ! grep -q 'export PATH=$PATH:/usr/local/go/bin' "$PROFILE_FILE"; then
  print_message "\t[+] Setting PATH to include golang binaries" "$GREEN"
  echo 'export PATH=$PATH:/usr/local/go/bin' >> "$PROFILE_FILE"
fi

print_message "\t[+] Environment variables configured. Please run 'source $PROFILE_FILE' to activate." "$GREEN"
print_message "[+] Go installation script completed successfully." "$GREEN"
