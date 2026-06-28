#!/bin/bash

# ==============================================================================
# DICOT PANEL - PRODUCTION VPS INSTALLER
# ==============================================================================
# Supported OS: Ubuntu, Debian, Rocky Linux, AlmaLinux, Oracle Linux, etc.
# Target: Production server, listens on 0.0.0.0 (externally reachable)
# Supports: Systemd, PM2, and custom firewall configuration
# ==============================================================================

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
IS_ROOT=0
if [ "$EUID" -ne 0 ]; then
    IS_ROOT=1
fi

clear
echo -e "${PURPLE}"
echo "======================================================================"
echo "    ____  ___________  ______     ____  ___    _   Relation           "
echo "   / __ \/  _/ ____/  / __  /    / __ \/   |  / | / / ____/           "
echo "  / / / // // /     / / / /    / /_/ / /| | /  |/ / __/              "
echo " / /_/ // // /___  / /_/ /    / ____/ ___ |/ /|  / /___              "
echo "/_____/___/\____/  \____/    /_/   /_/  |_/_/ |_/_____/              "
echo "                                                                      "
echo "               - VPS PRODUCTION AUTOMATED DEPLOYER -                  "
echo "======================================================================"
echo -e "${NC}"

if [ $IS_ROOT -eq 1 ]; then
    echo -e "⚠️  ${YELLOW}Warning: Running as non-root user. System package installations and firewall updates may require sudo permissions or fail.${NC}"
    echo -e "It is recommended to run this script as root: ${CYAN}sudo ./install-vps.sh${NC}\n"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Detect OS
echo -e "🔍 ${CYAN}Step 1: Detecting Operating System...${NC}"
OS_NAME="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_PRETTY=$PRETTY_NAME
    echo -e "✅ ${GREEN}Detected OS: ${OS_PRETTY} (${OS_NAME})${NC}"
else
    echo -e "⚠️  ${YELLOW}Cannot read /etc/os-release. Falling back to generic Linux installation.${NC}"
fi

# Install dependencies based on OS
echo -e "\n📦 ${CYAN}Step 2: Installing System Dependencies...${NC}"
INSTALL_CMD=""
UPDATE_CMD=""

case "$OS_NAME" in
    ubuntu|debian|raspbian|pop)
        UPDATE_CMD="apt-get update -y"
        INSTALL_CMD="apt-get install -y python3 python3-pip python3-venv sqlite3 curl wget build-essential git"
        ;;
    rocky|almalinux|oracle|rhel|centos|fedora)
        UPDATE_CMD="dnf check-update || true"
        INSTALL_CMD="dnf install -y python3 python3-pip sqlite curl wget tar make gcc gcc-c++ git"
        ;;
    *)
        echo -e "⚠️  ${YELLOW}Generic or unsupported OS. Assuming development environment (Codespaces/IDX/Sandbox).${NC}"
        ;;
esac

# Execute system package manager updates if running as root
if [ $IS_ROOT -eq 0 ]; then
    if [ ! -z "$UPDATE_CMD" ]; then
        echo -e "🔄 Updating package lists..."
        $UPDATE_CMD
    fi
    if [ ! -z "$INSTALL_CMD" ]; then
        echo -e "📥 Installing packages: $INSTALL_CMD..."
        $INSTALL_CMD
    fi
else
    echo -e "ℹ️  ${YELLOW}Skipping automatic system-wide package installation due to insufficient privileges.${NC}"
    echo -e "Ensure python3, python3-pip, python3-venv, and sqlite3 are installed on your system."
fi

# Check / Install Node.js
echo -e "\n🟢 ${CYAN}Step 3: Checking Node.js Runtime...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "⚠️  ${YELLOW}Node.js is missing! Installing Node.js v20 LTS...${NC}"
    if [ $IS_ROOT -eq 0 ]; then
        case "$OS_NAME" in
            ubuntu|debian|raspbian|pop)
                curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
                apt-get install -y nodejs
                ;;
            rocky|almalinux|oracle|rhel|centos|fedora)
                dnf module enable nodejs:20 -y || true
                dnf install -y nodejs
                ;;
            *)
                echo -e "❌ ${RED}Unable to auto-install Node.js on this OS. Please install Node.js manually and re-run.${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "❌ ${RED}Node.js is not installed and cannot be auto-installed without root access. Please install Node.js (v18+) manually.${NC}"
        exit 1
    fi
fi

NODE_VERSION=$(node -v)
echo -e "✅ ${GREEN}Using Node.js version: ${NODE_VERSION}${NC}"

# Check Python and Pip
echo -e "\n🐍 ${CYAN}Step 4: Setting up Python Virtual Environment...${NC}"
if [ -d "venv" ]; then
    echo -e "ℹ️  Removing old virtual environment..."
    rm -rf venv
fi

python3 -m venv venv
echo -e "✅ Created production virtual environment in ./venv"

# Install python dependencies in venv
echo -e "📥 Installing production Python packages..."
source venv/bin/activate
pip install --upgrade pip
if [ -f "HVM-V7-main/requirements.txt" ]; then
    pip install -r HVM-V7-main/requirements.txt
else
    echo -e "❌ ${RED}requirements.txt not found in HVM-V7-main/requirements.txt!${NC}"
    exit 1
fi
echo -e "✅ ${GREEN}Python dependencies installed inside virtual environment.${NC}"

# Install node dependencies and build
echo -e "\n🏢 ${CYAN}Step 5: Installing Node Modules & Compiling Production Build...${NC}"
npm install
npm run build
echo -e "✅ ${GREEN}Production build successfully generated in ./dist${NC}"

# Set up Production env variables
echo -e "\n📝 ${CYAN}Step 6: Configuring Production Environment variables...${NC}"
# Prompt user for port or use 3000
PANEL_PORT=3000
echo -e "Enter the port for the panel to listen on [Default: 3000]: "
read -t 10 INPUT_PORT || INPUT_PORT=""
if [ ! -z "$INPUT_PORT" ]; then
    PANEL_PORT=$INPUT_PORT
fi

# Detect external IP address
VPS_IP=$(curl -s https://api.ipify.org || echo "YOUR_SERVER_IP")

if [ ! -f ".env" ]; then
    cp .env.example .env
    RANDOM_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
    
    echo "" >> .env
    echo "# --- PRODUCTION VPS DEPLOYMENT ---" >> .env
    echo "NODE_ENV=\"production\"" >> .env
    echo "PORT=$PANEL_PORT" >> .env
    echo "PYTHON_PORT=5000" >> .env
    echo "SECRET_KEY=\"$RANDOM_SECRET\"" >> .env
    echo "SESSION_COOKIE_SECURE=\"false\"" >> .env
    echo "MAIN_ADMIN_USERNAME=\"admin\"" >> .env
    echo "MAIN_ADMIN_PASSWORD=\"admin123\"" >> .env
    echo "MAIN_ADMIN_EMAIL=\"admin@localhost\"" >> .env
    echo "APP_URL=\"http://$VPS_IP:$PANEL_PORT\"" >> .env
    echo -e "✅ ${GREEN}Created production .env file.${NC}"
else
    echo -e "ℹ️  ${YELLOW}.env already exists. Retaining current values.${NC}"
fi

# Seed DB dry-run
echo -e "\n💾 ${CYAN}Step 7: Initializing Production SQLite Database...${NC}"
python3 -c "import sys; sys.path.append('HVM-V7-main'); from hvm import init_db; init_db(); print('SQLite database initialized successfully.')"

# Permissions
echo -e "\n🔒 ${CYAN}Step 8: Configuring Permissions...${NC}"
chmod -R 755 static/ templates/ HVM-V7-main/ || true

# Firewall Configuration
echo -e "\n🛡️  ${CYAN}Step 9: Configuring Firewall Rules...${NC}"
if [ $IS_ROOT -eq 0 ]; then
    if command -v ufw &> /dev/null; then
        echo -e "Adding UFW rule for port $PANEL_PORT..."
        ufw allow $PANEL_PORT/tcp || true
        echo -e "✅ ${GREEN}UFW updated.${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        echo -e "Adding Firewalld rule for port $PANEL_PORT..."
        firewall-cmd --zone=public --add-port=$PANEL_PORT/tcp --permanent || true
        firewall-cmd --reload || true
        echo -e "✅ ${GREEN}Firewalld updated.${NC}"
    else
        echo -e "ℹ️  No known firewall manager (ufw/firewalld) found active. Please ensure port $PANEL_PORT is open in your cloud provider's console."
    fi
else
    echo -e "ℹ️  Skipped firewall rule updates (non-root execution). Please ensure port $PANEL_PORT is open."
fi

# Service Daemons (Systemd or PM2)
echo -e "\n⚡ ${CYAN}Step 10: Configuring Process Managers (PM2 / Systemd)...${NC}"
PM2_AVAILABLE=0
if command -v pm2 &> /dev/null; then
    PM2_AVAILABLE=1
fi

SERVICE_CHOICE=""
if [ $PM2_AVAILABLE -eq 1 ]; then
    echo -e "PM2 is installed! We can register and launch with PM2."
    SERVICE_CHOICE="pm2"
elif [ $IS_ROOT -eq 0 ]; then
    echo -e "Choose your preferred background service manager:"
    echo "1) Systemd Service (Recommended for dedicated servers / VPS)"
    echo "2) PM2 (Requires pm2 to be installed)"
    echo "3) No daemon (Run directly in foreground)"
    read -p "Select choice [1-3]: " CHOICE
    case "$CHOICE" in
        2) SERVICE_CHOICE="pm2" ;;
        3) SERVICE_CHOICE="none" ;;
        *) SERVICE_CHOICE="systemd" ;;
    esac
else
    echo -e "ℹ️  Skipping Systemd registration due to non-root privileges. Running directly."
    SERVICE_CHOICE="none"
fi

CURRENT_DIR=$(pwd)
NPM_PATH=$(command -v npm || which npm || echo "/usr/bin/npm")

if [ "$SERVICE_CHOICE" = "systemd" ]; then
    echo -e "🛠️  Creating Systemd service unit at /etc/systemd/system/dicot.service..."
    cat <<EOF > /etc/systemd/system/dicot.service
[Unit]
Description=DICOT Virtualization Control Panel
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$CURRENT_DIR
ExecStart=$NPM_PATH run start
Restart=on-failure
Environment=NODE_ENV=production PORT=$PANEL_PORT

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dicot.service
    systemctl start dicot.service
    echo -e "✅ ${GREEN}Systemd service 'dicot' successfully created, enabled, and started!${NC}"

elif [ "$SERVICE_CHOICE" = "pm2" ]; then
    if ! command -v pm2 &> /dev/null; then
        echo -e "Installing PM2 globally..."
        npm install -g pm2
    fi
    pm2 delete dicot-panel &> /dev/null || true
    pm2 start dist/server.cjs --name "dicot-panel" --env PORT=$PANEL_PORT
    pm2 save
    echo -e "✅ ${GREEN}PM2 process 'dicot-panel' started and saved successfully!${NC}"

else
    echo -e "ℹ️  No daemon selected. To start the application manually, run:"
    echo -e "  ${CYAN}PORT=$PANEL_PORT npm run start${NC}"
fi

# Summary
echo -e "\n${GREEN}======================================================================${NC}"
echo -e "🎉 ${GREEN}DICOT PANEL PRODUCTION VPS DEPLOYMENT COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "🔗 ${CYAN}Access Panel URL:${NC} http://$VPS_IP:$PANEL_PORT"
echo -e "🌐 ${CYAN}Listening Host:${NC} 0.0.0.0 (all interfaces)"
echo -e "⚙️  ${CYAN}Proxy Port:${NC} $PANEL_PORT"
echo -e "👤 ${CYAN}Default Admin User:${NC} admin"
echo -e "🔑 ${CYAN}Default Admin Pass:${NC} admin123"
echo -e "📁 ${CYAN}Installation Path:${NC} $CURRENT_DIR"
echo -e "💾 ${CYAN}Database Path:${NC} $CURRENT_DIR/hvm.db"
echo -e "${GREEN}======================================================================${NC}"
echo -e "💡 ${YELLOW}Production Tip:${NC} You can connect a custom domain or Cloudflare reverse"
echo -e "proxy to forward port 80/443 to port $PANEL_PORT seamlessly."
echo -e "${GREEN}======================================================================${NC}\n"
