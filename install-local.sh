#!/bin/bash

# ==============================================================================
# DICOT PANEL - LOCAL INSTALLATION SCRIPT
# ==============================================================================
# Target: macOS, Linux, Windows WSL
# Port: 5006 (Proxy) -> 5005 (Python Flask Backend)
# Database: SQLite (local)
# ==============================================================================

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ASCII Art Header
clear
echo -e "${CYAN}"
echo "======================================================================"
echo "    ____  ___________  ______     ____  ___    _   Relation           "
echo "   / __ \/  _/ ____/  / __  /    / __ \/   |  / | / / ____/           "
echo "  / / / // // /     / / / /    / /_/ / /| | /  |/ / __/              "
echo " / /_/ // // /___  / /_/ /    / ____/ ___ |/ /|  / /___              "
echo "/_____/___/\____/  \____/    /_/   /_/  |_/_/ |_/_____/              "
echo "                                                                      "
echo "               - LOCAL SYSTEM RAPID DEPLOYMENT -                      "
echo "======================================================================"
echo -e "${NC}"

echo -e "🔮 ${CYAN}Initializing environment validation...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "❌ ${RED}Node.js is not installed. Please install Node.js (v18+) before continuing.${NC}"
    exit 1
else
    NODE_VERSION=$(node -v)
    echo -e "✅ ${GREEN}Found Node.js version: ${NODE_VERSION}${NC}"
fi

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "❌ ${RED}Python 3 is not installed. Please install Python 3 before continuing.${NC}"
    exit 1
else
    PYTHON_VERSION=$(python3 --version)
    echo -e "✅ ${GREEN}Found Python version: ${PYTHON_VERSION}${NC}"
fi

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "❌ ${RED}npm is not installed. Please install npm before continuing.${NC}"
    exit 1
fi

echo -e "\n📦 ${CYAN}Step 1: Installing Frontend Node.js Dependencies...${NC}"
npm install

echo -e "\n🐍 ${CYAN}Step 2: Creating Python Virtual Environment (venv)...${NC}"
if [ -d "venv" ]; then
    echo -e "ℹ️  ${YELLOW}Existing virtual environment found. Removing to ensure clean install...${NC}"
    rm -rf venv
fi

python3 -m venv venv
echo -e "✅ ${GREEN}Virtual environment created successfully in ./venv${NC}"

echo -e "\n🛠️  ${CYAN}Step 3: Installing Backend Python Dependencies...${NC}"
# Activate venv
source venv/bin/activate

# Upgrade pip and install requirements
pip install --upgrade pip
if [ -f "HVM-V7-main/requirements.txt" ]; then
    pip install -r HVM-V7-main/requirements.txt
else
    echo -e "❌ ${RED}requirements.txt not found in HVM-V7-main/! Please check paths.${NC}"
    exit 1
fi
echo -e "✅ ${GREEN}Python dependencies installed successfully.${NC}"

echo -e "\n📝 ${CYAN}Step 4: Generating Local Configuration & Env Secrets...${NC}"
if [ ! -f ".env" ]; then
    # Create from .env.example
    cp .env.example .env
    
    # Generate random secret key
    RANDOM_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
    
    # Append custom configurations
    echo "" >> .env
    echo "# --- LOCAL DEPLOYMENT AUTO-GENERATED PARAMS ---" >> .env
    echo "NODE_ENV=\"development\"" >> .env
    echo "PORT=5006" >> .env
    echo "PYTHON_PORT=5005" >> .env
    echo "SECRET_KEY=\"$RANDOM_SECRET\"" >> .env
    echo "SESSION_COOKIE_SECURE=\"false\"" >> .env
    echo "MAIN_ADMIN_USERNAME=\"admin\"" >> .env
    echo "MAIN_ADMIN_PASSWORD=\"admin123\"" >> .env
    echo "MAIN_ADMIN_EMAIL=\"admin@localhost\"" >> .env
    echo "APP_URL=\"http://localhost:5006\"" >> .env
    
    echo -e "✅ ${GREEN}Generated .env configuration file.${NC}"
else
    echo -e "ℹ️  ${YELLOW}.env file already exists. Skipping auto-generation to prevent overwriting.${NC}"
fi

# Load env variables for initialization
export PORT=5006
export PYTHON_PORT=5005
export SECRET_KEY=$(grep SECRET_KEY .env | cut -d '"' -f 2 || echo "local_fallback_secret_key")
export MAIN_ADMIN_USERNAME=$(grep MAIN_ADMIN_USERNAME .env | cut -d '"' -f 2 || echo "admin")
export MAIN_ADMIN_PASSWORD=$(grep MAIN_ADMIN_PASSWORD .env | cut -d '"' -f 2 || echo "admin123")
export MAIN_ADMIN_EMAIL=$(grep MAIN_ADMIN_EMAIL .env | cut -d '"' -f 2 || echo "admin@localhost")

echo -e "\n💾 ${CYAN}Step 5: Initializing SQLite Local Database...${NC}"
# Python starts up the database automatically, but let's run a quick dry-run to seed immediately
python3 -c "import sys; sys.path.append('HVM-V7-main'); from hvm import init_db; init_db(); print('SQLite database initialized successfully.')"
echo -e "✅ ${GREEN}Local database configured and seeded.${NC}"

echo -e "\n🏢 ${CYAN}Step 6: Generating Frontend Assets Build...${NC}"
npm run build
echo -e "✅ ${GREEN}Frontend assets built successfully.${NC}"

# Display Final Summary Information
echo -e "\n${GREEN}======================================================================${NC}"
echo -e "🎉 ${GREEN}DICOT PANEL LOCAL INSTALLATION COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "🔗 ${CYAN}Local Panel URL:${NC} http://localhost:5006"
echo -e "⚙️  ${CYAN}Local Proxy Port:${NC} 5006"
echo -e "🐍 ${CYAN}Flask Backend Port:${NC} 5005"
echo -e "👤 ${CYAN}Default Admin User:${NC} $MAIN_ADMIN_USERNAME"
echo -e "🔑 ${CYAN}Default Admin Pass:${NC} $MAIN_ADMIN_PASSWORD"
echo -e "💾 ${CYAN}Database Path:${NC} ./hvm.db"
echo -e "📁 ${CYAN}Storage Assets:${NC} Local filesystem"
echo -e "${GREEN}======================================================================${NC}"

# Auto start the panel
echo -e "\n⚡ ${PURPLE}Starting DICOT Panel Proxy and Backend Server...${NC}"
echo -e "Press ${YELLOW}Ctrl+C${NC} to terminate the servers at any time.\n"

# Run proxy which launches Flask
PORT=5006 PYTHON_PORT=5005 npm run dev
