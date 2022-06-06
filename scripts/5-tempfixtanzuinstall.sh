#####Install Tanzu Community Edition directly (without Homebrew)
##Based on Tanzu 0.12.1
echo "> Pre-Installing Tanzu Community Edition Binary: Build $tanzutce_version..."

# Set Versions
tanzutce_version="v0.12.1"

sudo install /tanzu/tce-linux-amd64-${tanzutce_version}/tanzu /usr/local/bin

