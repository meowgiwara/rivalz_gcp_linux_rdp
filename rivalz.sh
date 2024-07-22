#!/bin/bash

# Check if the script is being run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Check for required parameters
if [ $# -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

# Set debconf to non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Define user and password variables from script parameters
NEW_USER=$1
NEW_PASSWORD=$2

# Update the package list and upgrade all your packages to their latest versions.
echo "Updating package list and upgrading packages..."
apt update && apt upgrade -y
if [ $? -ne 0 ]; then
  echo "Failed to update and upgrade packages."
  exit 1
fi

# Install all necessary packages
echo "Installing necessary packages..."
apt install -y xfce4 xfce4-goodies xrdp net-tools wget ethtool flatpak
if [ $? -ne 0 ]; then
  echo "Failed to install necessary packages."
  exit 1
fi

# User Creation
echo "Creating new user..."
useradd -m -s /bin/bash $NEW_USER
if [ $? -ne 0 ]; then
  echo "Failed to add new user."
  exit 1
fi

echo "$NEW_USER:$NEW_PASSWORD" | chpasswd
if [ $? -ne 0 ]; then
  echo "Failed to set password for new user."
  exit 1
fi

usermod -aG sudo $NEW_USER
if [ $? -ne 0 ]; then
  echo "Failed to add user to sudo group."
  exit 1
fi

# XRDP Configuration
echo "Configuring xrdp..."
echo "startxfce4" > /home/$NEW_USER/.xsession
chown $NEW_USER:$NEW_USER /home/$NEW_USER/.xsession

systemctl restart xrdp
if [ $? -ne 0 ]; then
  echo "Failed to restart xrdp."
  exit 1
fi

systemctl enable xrdp
if [ $? -ne 0 ]; then
  echo "Failed to enable xrdp."
  exit 1
fi

# Firefox with flatpak
echo "Installing Firefox with flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.mozilla.firefox
if [ $? -ne 0 ]; then
  echo "Failed to install Firefox."
  exit 1
fi

update-alternatives --install /usr/bin/x-www-browser x-www-browser /var/lib/flatpak/exports/bin/org.mozilla.firefox 200
update-alternatives --set x-www-browser /var/lib/flatpak/exports/bin/org.mozilla.firefox

# Download and set up the Rivalz.ai rClient AppImage
echo "Downloading and setting up Rivalz.ai rClient AppImage..."
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

wget https://api.rivalz.ai/fragmentz/clients/rClient-latest.AppImage -O $TMP_DIR/rClient-latest.AppImage
if [ $? -ne 0 ]; then
  echo "Failed to download rClient AppImage."
  exit 1
fi

chmod +x $TMP_DIR/rClient-latest.AppImage
sudo -u $NEW_USER mkdir -p /home/$NEW_USER/Documents
mv $TMP_DIR/rClient-latest.AppImage /home/$NEW_USER/Documents/rClient-latest.AppImage
chown $NEW_USER:$NEW_USER /home/$NEW_USER/Documents/rClient-latest.AppImage

# Create the systemd service file for network configuration
echo "Creating systemd service for network configuration..."
cat <<EOL > /etc/systemd/system/ens4-config.service
[Unit]
Description=Configure ens4 network interface
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s ens4 speed 1000 duplex full autoneg off
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable ens4-config.service
systemctl start ens4-config.service
if [ $? -ne 0 ]; then
  echo "Failed to configure network interface."
  exit 1
fi

# Clear command history
history -w
history -c

# Print the message important note
echo -e "
#################################################\n\
# Installation complete.
#################################################\n\
Components installed and started:\n\
- XFCE Desktop\n\
- xrdp\n\
- Rivalz.ai rClient\n\
- Firefox\n\
- Network configuration service\n\
"