#!/bin/bash

# Introduction and confirmation
clear

# Ensure locale settings
export LANGUAGE="en_GB.UTF-8"
export LC_ALL="en_GB.UTF-8"
export LC_CTYPE="en_GB.UTF-8"
export LANG="en_GB.UTF-8"

# Enable SPI using raspi-config
echo "Enabling SPI interface using raspi-config..."
raspi-config nonint do_spi 0

# Begin setup
echo "Starting TFT setup..."

# Configure fbcp-ili9341
echo "configuring fbcp-ili9341..."
# Use explicit path /home/ut2a/fbcp-ili9341 instead of ~
cd /home/ut2a/fbcp-ili9341
mkdir -p build
cd build
rm -rf *
cmake -DUSE_GPU=ON -DSPI_BUS_CLOCK_DIVISOR=4 \
      -DGPIO_TFT_DATA_CONTROL=25 -DGPIO_TFT_RESET_PIN=17 \
      -DILI9488=ON -DUSE_DMA_TRANSFERS=ON -DSTATISTICS=0 ..
make -j$(nproc)
if [ $? -ne 0 ]; then
    echo "Error: Compilation of fbcp-ili9341 failed. Exiting..."
    exit 1
fi
sudo install fbcp-ili9341 /usr/local/bin/

# Define the configuration file path
CONFIG_FILE="/boot/firmware/config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="/boot/config.txt"
fi

update_config() {
    local key=$1
    local value=$2

    # Check if the line already exists
    if grep -q "^$key" "$CONFIG_FILE"; then
        # Remove any preceding # and update value if necessary
        sed -i "s/^#$key/$key/" "$CONFIG_FILE"
        if [ -n "$value" ]; then
            sed -i "s|^$key.*|$key=$value|" "$CONFIG_FILE"
        fi
    else
        # Add the line if it doesn't exist
        if [ -z "$value" ]; then
            echo "$key" >> "$CONFIG_FILE"
        else
            echo "$key=$value" >> "$CONFIG_FILE"
        fi
    fi
}

remove_duplicates() {
    local file=$1
    # Retain line breaks and remove duplicate lines
    awk '!seen[$0]++' "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
}

# Comment the line max_framebuffers=2 if it exists
if grep -q "^max_framebuffers=2" "$CONFIG_FILE"; then
    sed -i "s|^max_framebuffers=2|#max_framebuffers=2 (line commented for TFT ILI9488 installation on $(date +%m/%d/%Y))|" "$CONFIG_FILE"
fi

# Comment the dtoverlay=vc4-kms-v3d line
sed -i "s|^dtoverlay=vc4-kms-v3d|#dtoverlay=vc4-kms-v3d (line commented for TFT ILI9488 installation on $(date +%m/%d/%Y))|" "$CONFIG_FILE"

# Add required configuration lines
echo "#Modifications for ILI9488 installation implemented by the script on $(date +%m/%d/%Y)" >> "$CONFIG_FILE"
update_config "dtoverlay" "spi0-0cs"
update_config "dtparam" "spi=on"
update_config "hdmi_force_hotplug" "1"
update_config "hdmi_cvt" "320 480 60 1 0 0 0"
update_config "hdmi_group" "2"
update_config "hdmi_mode" "87"
update_config "framebuffer_width" "320"
update_config "framebuffer_height" "480"
update_config "dtoverlay" "fbtft_device,name=ili9488,rotate=0,fps=30,speed=16000000"
update_config "dtparam" "dc_pin=22"
update_config "dtparam" "reset_pin=11"
update_config "gpu_mem" "128"
echo "# Utilized for TFT ILI9488 setup script by AdamoMD" >> "$CONFIG_FILE"
echo "# https://github.com/adamomd/4inchILI9488RpiScript/" >> "$CONFIG_FILE"
echo "# Feel free to send feedback and suggestions." >> "$CONFIG_FILE"

# Remove duplicates in config.txt
echo "Removing duplicate lines in config.txt..."
remove_duplicates "$CONFIG_FILE"

# Configure sudoers for fbcp-ili9341
echo "Setting permissions in sudoers..."
VISUDO_FILE="/etc/sudoers.d/fbcp-ili9341"
if [ ! -f "$VISUDO_FILE" ]; then
    echo "ALL ALL=(ALL) NOPASSWD: /usr/local/bin/fbcp-ili9341" > "$VISUDO_FILE"
    chmod 440 "$VISUDO_FILE"
fi

# Set binary permissions
echo "Configuring permissions for fbcp-ili9341..."
chmod u+s /usr/local/bin/fbcp-ili9341

# Configure rc.local to start fbcp-ili9341
echo "Configuring /etc/rc.local..."
RC_LOCAL="/etc/rc.local"
if [ ! -f "$RC_LOCAL" ]; then
    cat <<EOT > "$RC_LOCAL"
#!/bin/bash
# rc.local
# This script is executed at the end of each multi-user runlevel.

# Start fbcp-ili9341
/usr/local/bin/fbcp-ili9341 >> /var/log/fbcp-ili9341.log 2>&1 &

exit 0
EOT
    chmod +x "$RC_LOCAL"
else
    if ! grep -q "fbcp-ili9341" "$RC_LOCAL"; then
        sed -i '/exit 0/i \\n# Start fbcp-ili9341\n/usr/local/bin/fbcp-ili9341 >> /var/log/fbcp-ili9341.log 2>&1 &' "$RC_LOCAL"
    fi
fi

# Remove duplicates in rc.local
echo "Removing duplicate lines in rc.local..."
remove_duplicates "$RC_LOCAL"

# Enable and start rc.local service
echo "Enabling rc.local service..."
sudo chmod +x /etc/rc.local
sudo systemctl enable rc-local
sudo systemctl start rc-local

# Finish and force reboot
echo "Finalizing processes..."
killall -9 fbcp-ili9341 2>/dev/null || true
sync
echo -e "\nSetup complete. The Raspberry Pi will now reboot."
sudo reboot