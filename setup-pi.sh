#!/bin/bash

# Exit on any error
set -e

echo "Setting up Spotify Connect Player..."

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check and configure audio
setup_audio() {
    log "Configuring audio..."
    
    # Enable the built-in audio output
    if [ -f /usr/bin/raspi-config ]; then
        sudo raspi-config nonint do_audio 1
    fi
    
    # Unmute and set default volume using amixer if available
    if command -v amixer &> /dev/null; then
        # Try different sound cards until we find one that works
        for CARD in default 0 1; do
            if amixer -c $CARD sget 'PCM' &> /dev/null; then
                amixer -c $CARD sset 'PCM' 90% unmute &> /dev/null || true
                log "Audio configured using card $CARD"
                break
            fi
        done
    fi
}

# Install Docker and Docker Compose
setup_docker() {
    log "Installing Docker..."
    
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
        log "Docker installed successfully"
    else
        log "Docker already installed"
    fi
}

# Create directories and configuration
setup_directories() {
    log "Setting up directory structure..."
    
    # Create required directories
    mkdir -p config logs
    
    # Copy config template if not exists
    if [ ! -f config/config.json ]; then
        cp config.json config/config.json
        log "Created default config.json"
    fi
}

# Setup systemd service
setup_service() {
    log "Setting up systemd service..."
    
    sudo tee /etc/systemd/system/spotify-connect.service << EOF
[Unit]
Description=Spotify Connect Player Container
Requires=docker.service
After=docker.service network.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
WorkingDirectory=/home/pi/spotify-connect-player
ExecStart=/usr/bin/docker-compose up
ExecStop=/usr/bin/docker-compose down
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable spotify-connect
    sudo systemctl start spotify-connect
    
    log "Service installed and started"
}

# Main installation flow
main() {
    setup_audio
    setup_docker
    setup_directories
    setup_service
    
    log "Installation completed successfully!"
    log "Please edit config/config.json with your Spotify credentials"
    log "The service will automatically start on boot"
    log "To check status: sudo systemctl status spotify-connect"
    log "To view logs: docker-compose logs -f"
}

# Run main installation
main