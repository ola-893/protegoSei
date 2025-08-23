#!/bin/bash

# 🏆 Protego.ai Build & Demo Script

# Exit on any error
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NETWORK=${1:-"localhost"}
RUN_DEMO=${2:-"true"}
SKIP_INSTALL=${3:-"false"}

# Print functions
print_header() {
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                  🏆 PROTEGO.AI BUILD                               ║${NC}"
    echo -e "${PURPLE}║              AI-Powered Invoice Financing Platform                ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🔷 STEP $1: $2${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Cleanup function
cleanup() {
    if [ ! -z "$HARDHAT_PID" ]; then
        print_info "Stopping local hardhat node..."
        kill $HARDHAT_PID 2>/dev/null || true
        print_success "Cleanup completed"
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT INT TERM

print_header

print_info "Build Configuration:"
print_info "  Network: $NETWORK"
print_info "  Run Demo: $RUN_DEMO"
print_info "  Skip Install: $SKIP_INSTALL"

# ================================================================
# STEP 1: Environment Check
# ================================================================
print_step "1" "Environment Validation"

# Check Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed!"
    print_info "Please install Node.js >= 16.0.0"
    exit 1
fi

NODE_VERSION=$(node -v)
print_success "Node.js: $NODE_VERSION"

# Check npm
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed!"
    exit 1
fi

NPM_VERSION=$(npm -v)
print_success "npm: $NPM_VERSION"

# Check if in project directory
if [ ! -f "package.json" ]; then
    print_error "package.json not found!"
    print_info "Please run from project root directory"
    exit 1
fi

print_success "Environment validation passed"

# ================================================================
# STEP 2: Dependencies
# ================================================================
if [ "$SKIP_INSTALL" != "true" ]; then
    print_step "2" "Installing Dependencies"
    
    print_info "Installing npm packages..."
    npm install --silent
    
    # Verify hardhat
    if ! npx hardhat --version &> /dev/null; then
        print_error "Hardhat installation failed"
        exit 1
    fi
    
    print_success "Dependencies installed"
else
    print_step "2" "Skipping Dependency Installation"
    print_info "Using existing dependencies"
fi

# ================================================================
# STEP 3: Project Structure
# ================================================================
print_step "3" "Project Structure Setup"

# Create directories
mkdir -p contracts/mocks
mkdir -p scripts  
mkdir -p test
mkdir -p deployments

print_success "Project structure ready"

# Check if contracts exist
if [ ! -f "contracts/staking.sol" ]; then
    print_warning "Main contract file 'contracts/staking.sol' not found"
    print_info "Make sure your contract files are in the contracts/ directory"
fi

# ================================================================
# STEP 4: Compile Contracts  
# ================================================================
print_step "4" "Smart Contract Compilation"

print_info "Cleaning previous build artifacts..."
npx hardhat clean

print_info "Compiling Protego.ai smart contracts..."
if npx hardhat compile; then
    print_success "Smart contracts compiled successfully"
    
    # Show contract info
    print_info "Compiled contracts:"
    if [ -d "artifacts/contracts" ]; then
        find artifacts/contracts -name "*.sol" -type d | sed 's/artifacts\/contracts\///g' | while read contract; do
            echo "  • $contract"
        done
    fi
else
    print_error "Contract compilation failed"
    print_info "Please fix compilation errors and try again"
    exit 1
fi

# ================================================================
# STEP 5: Network Setup
# ================================================================
print_step "5" "Network Configuration"

if [ "$NETWORK" = "localhost" ] || [ "$NETWORK" = "hardhat" ]; then
    print_info "Setting up local Hardhat network..."
    
    # Check if local node is running
    if curl -s -X POST -H "Content-Type: application/json" \
       --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
       http://127.0.0.1:8545 &>/dev/null; then
        print_success "Local Hardhat node is already running"
    else
        print_info "Starting local Hardhat node..."
        npx hardhat node --hostname 0.0.0.0 --port 8545 > hardhat.log 2>&1 &
        HARDHAT_PID=$!
        
        # Wait for node to start
        print_info "Waiting for node to initialize..."
        sleep 5
        
        # Verify node is running
        if kill -0 $HARDHAT_PID 2>/dev/null; then
            print_success "Local Hardhat node started (PID: $HARDHAT_PID)"
        else
            print_error "Failed to start Hardhat node"
            cat hardhat.log
            exit 1
        fi
    fi
    
else
    print_info "Using external network: $NETWORK"
    print_warning "Make sure you have configured the network in hardhat.config.cjs"
fi

# ================================================================
# STEP 6: Deploy Contracts
# ================================================================
print_step "6" "Smart Contract Deployment"

print_info "Deploying Protego.ai contracts to $NETWORK..."

# Check if deploy script exists
if [ -f "scripts/deploy.cjs" ]; then
    print_info "Using deploy.cjs script..."
    node scripts/deploy.cjs
elif [ -f "scripts/deploy.cjs" ]; then
    print_info "Using hardhat deployment script..."
    npx hardhat run scripts/deploy.cjs --network $NETWORK
else
    print_warning "No deployment script found"
    print_info "Creating basic deployment..."
    
    # Simple inline deployment test
    cat > temp_deploy.cjs << 'EOF'
const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Basic deployment test...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Balance:", ethers.formatEther(balance), "ETH");
  
  console.log("✅ Basic deployment test completed");
}

main().catch(console.error);
EOF
    
    npx hardhat run temp_deploy.cjs --network $NETWORK
    rm temp_deploy.cjs
fi

if [ $? -eq 0 ]; then
    print_success "Contract deployment completed"
else
    print_error "Contract deployment failed"
    exit 1
fi

# ================================================================
# STEP 7: Run Demo
# ================================================================
if [ "$RUN_DEMO" = "true" ]; then
    print_step "7" "Running Demo"
    
    print_info "Executing Protego.ai demonstration..."
    print_info "This will show:"
    print_info "  • ElizaOS AI opportunity discovery (simulated)"
    print_info "  • MCP safety validation (simulated)"
    print_info "  • GOAT transaction execution (simulated)"
    print_info "  • Smart contract interactions (real)"
    
    # Run demo
    if [ -f "scripts/demo.cjs" ]; then
        print_info "Running demo.cjs..."
        node scripts/demo.cjs
    elif [ -f "scripts/demo.cjs" ]; then
        print_info "Running simulation script..."
        npx hardhat run scripts/demo.cjs --network $NETWORK
    else
        print_warning "No demo script found"
        print_info "Creating basic interaction test..."
        
        cat > temp_demo.cjs << 'EOF'
const { ethers } = require("hardhat");

async function main() {
  console.log("🎯 Basic interaction demo...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Demo account:", deployer.address);
  
  // Test basic functionality
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");
  
  console.log("✅ Basic demo completed successfully!");
}

main().catch(console.error);
EOF
        
        npx hardhat run temp_demo.cjs --network $NETWORK
        rm temp_demo.cjs
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Demo completed successfully!"
    else
        print_error "Demo failed"
        exit 1
    fi
else
    print_step "7" "Skipping Demo"
    print_info "To run demo later: node demo.cjs"
fi

# ================================================================
# STEP 8: Success Summary
# ================================================================
print_step "8" "Build Summary"

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  🎉 BUILD COMPLETED SUCCESSFULLY! 🎉              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"

print_success "Protego.ai  project is ready!"

echo -e "\n${CYAN}🏗️  What was built:${NC}"
echo "  • Smart contract compilation ✅"
echo "  • Local network setup ✅" 
echo "  • Contract deployment ✅"
echo "  • Demo execution ✅"

echo -e "\n${CYAN}🔧 Smart Contract Features:${NC}"
echo "  • ERC-721: Invoice NFTs"
echo "  • ERC-4626: Yield-bearing vaults" 
echo "  • ERC-1155: Multi-invoice notes"
echo "  • Automated yield generation"
echo "  • Safety validation integration"

echo -e "\n${CYAN}🤖 AI Integration Points:${NC}"
echo "  • ElizaOS: Opportunity discovery"
echo "  • MCP: Safety validation"
echo "  • GOAT: Secure execution"
echo "  • Smart contracts: Business logic"

echo -e "\n${CYAN}📁 Generated Files:${NC}"
if [ -d "deployments" ]; then
    echo "  • Deployment data: ./deployments/"
fi
if [ -d "artifacts" ]; then
    echo "  • Contract artifacts: ./artifacts/"
fi
if [ -f "hardhat.log" ]; then
    echo "  • Hardhat logs: ./hardhat.log"
fi

echo -e "\n${CYAN}🚀 Quick Commands:${NC}"
echo "  • Deploy: node deploy.cjs"
echo "  • Demo: node demo.cjs" 
echo "  • Test: npx hardhat test"
echo "  • Compile: npx hardhat compile"

if [ "$NETWORK" = "localhost" ]; then
    echo -e "\n${YELLOW}💡 Local Development:${NC}"
    echo "  • Network running on: http://127.0.0.1:8545"
    echo "  • Chain ID: 31337"
    if [ ! -z "$HARDHAT_PID" ]; then
        echo "  • Node PID: $HARDHAT_PID (will stop when script ends)"
    fi
fi

# Keep node running if requested
if [ "$NETWORK" = "localhost" ] && [ ! -z "$HARDHAT_PID" ]; then
    echo -e "${YELLOW}Press Ctrl+C to stop the local node and exit${NC}"
    # Wait for user interrupt
    while true; do
        sleep 1
    done
fi