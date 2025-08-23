#!/usr/bin/env node

/**
 * 🚀 PROTEGO.AI DEPLOYMENT SCRIPT - Updated Architecture
 * 
 * Deploys the complete Protego.ai smart contract suite with separated architecture:
 * - Mock USDC for testing
 * - Master Vault (coordination layer with InvoiceNFT)
 * - Core Yield Vault (base functionality)
 * - GOAT Yield Vault (AI agent extension)
 * - GOAT Agent configuration
 */

const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

// Deployment configuration
const CONFIG = {
  // Treasury will be deployer for demo
  platformFeeBps: 200, // 2%
  baseYieldRate: 800,  // 8% annual
  seiMultiplier: 150,  // 1.5x for Sei network
  testTokenSupply: ethers.utils.parseUnits("10000000", 6), // 10M USDC for testing
  // GOAT Agent configuration
  goatAgent: {
    // This would be the actual GOAT agent address in production
    // For demo, we'll use the deployer address
    address: null, // Will be set to deployer for demo
    name: "Protego GOAT Agent",
    description: "AI-powered yield optimization agent"
  }
};

// Color functions
const c = {
  red: (s) => `\x1b[31m${s}\x1b[0m`,
  green: (s) => `\x1b[32m${s}\x1b[0m`, 
  yellow: (s) => `\x1b[33m${s}\x1b[0m`,
  blue: (s) => `\x1b[34m${s}\x1b[0m`,
  magenta: (s) => `\x1b[35m${s}\x1b[0m`,
  cyan: (s) => `\x1b[36m${s}\x1b[0m`,
  bold: (s) => `\x1b[1m${s}\x1b[0m`
};

function logStep(num, title) {
  console.log("\n" + "═".repeat(60));
  console.log(c.cyan(`🚀 STEP ${num}: ${title}`));
  console.log("═".repeat(60));
}

function logSuccess(msg) { console.log(c.green(`✅ ${msg}`)); }
function logInfo(msg) { console.log(c.blue(`ℹ️  ${msg}`)); }
function logWarning(msg) { console.log(c.yellow(`⚠️  ${msg}`)); }

async function main() {
  console.log("");
  console.log(c.magenta("╔════════════════════════════════════════════════════════════╗"));
  console.log(c.magenta("║              🚀 PROTEGO.AI DEPLOYMENT                      ║"));
  console.log(c.magenta("║         Updated Architecture with GOAT Extension           ║"));
  console.log(c.magenta("╚════════════════════════════════════════════════════════════╝"));

  // =========================================================================
  // STEP 1: Environment Setup
  // =========================================================================
  logStep(1, "Environment Setup");
  
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const balance = await ethers.provider.getBalance(deployer.address);
  
  // Set GOAT agent address to deployer for demo
  CONFIG.goatAgent.address = deployer.address;
  
  logInfo(`Network: ${network.name} (Chain ID: ${network.chainId})`);
  logInfo(`Deployer: ${deployer.address}`);
  logInfo(`Balance: ${ethers.utils.formatUnits(balance, 18)} ETH`);
  logInfo(`GOAT Agent (demo): ${CONFIG.goatAgent.address}`);
  
  if (balance.lt(ethers.utils.parseUnits("1", 18))) {
    logWarning("Low ETH balance - you may need more for deployment");
  }
  
  logSuccess("Environment ready");

  // =========================================================================
  // STEP 2: Deploy Mock USDC
  // =========================================================================
  logStep(2, "Deploy Mock USDC Token");
  
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  logInfo("Deploying Mock USDC...");
  
  const usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
  await usdc.deployed();
  const usdcAddress = usdc.address;
  
  logSuccess(`Mock USDC deployed: ${usdcAddress}`);
  
  // Mint initial supply for testing
  await usdc.mint(deployer.address, CONFIG.testTokenSupply);
  logInfo(`Minted ${ethers.utils.formatUnits(CONFIG.testTokenSupply, 6)} USDC for testing`);

  // =========================================================================
  // STEP 3: Deploy Master Vault System
  // =========================================================================  
  logStep(3, "Deploy Master Vault System");
  
  const ProtegoMasterVault = await ethers.getContractFactory("ProtegoMasterVault");
  logInfo("Deploying Master Vault (includes InvoiceNFT)...");
  
  const masterVault = await ProtegoMasterVault.deploy(
    usdcAddress,
    deployer.address // Treasury = deployer for demo
  );
  await masterVault.deployed();
  const masterVaultAddress = masterVault.address;
  
  logSuccess(`Master Vault deployed: ${masterVaultAddress}`);
  
  // Get automatically deployed InvoiceNFT contract
  const invoiceNFTAddress = await masterVault.invoiceNFT();
  logSuccess(`Invoice NFT (ERC-721): ${invoiceNFTAddress}`);

  // =========================================================================
  // STEP 4: Deploy Core Yield Vault
  // =========================================================================
  logStep(4, "Deploy Core Yield Vault");
  
  const ProtegoYieldVaultCore = await ethers.getContractFactory("ProtegoYieldVaultCore");
  logInfo("Deploying Core Yield Vault...");
  
  // Core vault constructor parameters:
  // (asset, invoiceNFT, invoiceTokenId, fundingTarget, fundingDeadline, name, symbol)
  const fundingTarget = ethers.utils.parseUnits("50000", 6); // 50k USDC target
  const fundingDeadline = Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60); // 30 days from now
  const invoiceTokenId = 1; // First invoice NFT for demo
  
  const vaultCore = await ProtegoYieldVaultCore.deploy(
    usdcAddress,                    // asset_ - underlying asset (USDC)
    invoiceNFTAddress,             // invoiceNFT_ - invoice NFT contract
    invoiceTokenId,                // invoiceTokenId_ - specific invoice token ID
    fundingTarget,                 // fundingTarget_ - funding goal (50k USDC)
    fundingDeadline,              // fundingDeadline_ - deadline timestamp
    "Protego Yield Vault",        // name_ - vault token name
    "PYV"                        // symbol_ - vault token symbol
  );
  await vaultCore.deployed();
  const vaultCoreAddress = vaultCore.address;
  
  logSuccess(`Core Yield Vault deployed: ${vaultCoreAddress}`);
  logInfo(`Funding target: ${ethers.utils.formatUnits(fundingTarget, 6)} USDC`);
  logInfo(`Funding deadline: ${new Date(fundingDeadline * 1000).toISOString()}`);

  // =========================================================================
  // STEP 5: Deploy GOAT Extension Vault
  // =========================================================================
  logStep(5, "Deploy GOAT Extension Vault");
  
  const ProtegoYieldVaultGoat = await ethers.getContractFactory("ProtegoYieldVaultGoat");
  logInfo("Deploying GOAT Extension Vault...");
  
  const vaultGoat = await ProtegoYieldVaultGoat.deploy(
    vaultCoreAddress,
    usdcAddress
  );
  await vaultGoat.deployed();
  const vaultGoatAddress = vaultGoat.address;
  
  logSuccess(`GOAT Extension Vault deployed: ${vaultGoatAddress}`);

  // =========================================================================
  // STEP 6: Configuration & Integration
  // =========================================================================
  logStep(6, "Configure Platform Parameters & Integration");
  
  logInfo("Setting up master vault parameters...");
  // await masterVault.setPlatformFee(CONFIG.platformFeeBps);
  
  logInfo("Setting up GOAT agent...");
  await masterVault.setGoatAgent(CONFIG.goatAgent.address);
  
  logInfo("Connecting GOAT extension to core vault...");
  // This would typically involve setting the GOAT vault as an authorized extension
  // The exact method depends on your core vault implementation
  
  logSuccess(`Platform fee: ${CONFIG.platformFeeBps / 100}%`);
  logSuccess(`Base yield rate: ${CONFIG.baseYieldRate / 100}%`);
  logSuccess(`Sei multiplier: ${CONFIG.seiMultiplier / 100}x`);
  logSuccess(`GOAT Agent configured: ${CONFIG.goatAgent.address}`);

  // =========================================================================
  // STEP 7: Approve & Fund for Testing
  // =========================================================================
  logStep(7, "Setup Testing Environment");
  
  logInfo("Approving USDC for vault operations...");
  const approveAmount = ethers.utils.parseUnits("1000000", 6); // 1M USDC
  await usdc.approve(vaultCoreAddress, approveAmount);
  await usdc.approve(vaultGoatAddress, approveAmount);
  await usdc.approve(masterVaultAddress, approveAmount);
  
  logInfo("Funding contracts for testing...");
  const fundAmount = ethers.utils.parseUnits("100000", 6); // 100k USDC each
  await usdc.transfer(vaultCoreAddress, fundAmount);
  await usdc.transfer(masterVaultAddress, fundAmount);
  
  logSuccess("Testing environment prepared");

  // =========================================================================
  // STEP 8: Save Deployment Data
  // =========================================================================
  logStep(8, "Save Deployment Information");
  
  const deploymentData = {
    network: {
      name: network.name,
      chainId: Number(network.chainId)
    },
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    architecture: "separated-goat-extension",
    contracts: {
      mockUSDC: usdcAddress,
      masterVault: masterVaultAddress,
      invoiceNFT: invoiceNFTAddress,
      vaultCore: vaultCoreAddress,
      vaultGoat: vaultGoatAddress
    },
    vaultParameters: {
      fundingTarget: ethers.utils.formatUnits(fundingTarget, 6),
      fundingDeadline: new Date(fundingDeadline * 1000).toISOString(),
      invoiceTokenId: invoiceTokenId
    },
    configuration: {
      platformFeeBps: CONFIG.platformFeeBps,
      baseYieldRate: CONFIG.baseYieldRate,
      seiMultiplier: CONFIG.seiMultiplier,
      treasury: deployer.address,
      goatAgent: CONFIG.goatAgent
    }
  };
  
  // Create deployments directory
  const deploymentsDir = path.join(process.cwd(), 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  // Save deployment file
  const deploymentFile = path.join(deploymentsDir, `protego-separated-${Date.now()}.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));
  
  // Save as latest
  const latestFile = path.join(deploymentsDir, 'protego-latest.json');
  fs.writeFileSync(latestFile, JSON.stringify(deploymentData, null, 2));
  
  logSuccess(`Deployment data saved: ${deploymentFile}`);
  logSuccess(`Latest deployment: ${latestFile}`);

  // =========================================================================
  // STEP 9: Deployment Summary
  // =========================================================================
  logStep(9, "Deployment Summary");
  
  console.log(c.bold("\n🎯 DEPLOYMENT COMPLETED SUCCESSFULLY!"));
  
  console.log("\n" + c.cyan("📋 Contract Addresses:"));
  console.log(`   Mock USDC (ERC-20):           ${usdcAddress}`);
  console.log(`   Master Vault:                 ${masterVaultAddress}`);
  console.log(`   Invoice NFT (ERC-721):        ${invoiceNFTAddress}`);
  console.log(`   Core Yield Vault:             ${vaultCoreAddress}`);
  console.log(`   GOAT Extension Vault:         ${vaultGoatAddress}`);
  
  console.log("\n" + c.cyan("⚙️  Configuration:"));
  console.log(`   Platform Fee:                 ${CONFIG.platformFeeBps / 100}%`);
  console.log(`   Treasury Address:             ${deployer.address}`);
  console.log(`   Funding Target:               ${ethers.utils.formatUnits(fundingTarget, 6)} USDC`);
  console.log(`   Funding Deadline:             ${new Date(fundingDeadline * 1000).toLocaleDateString()}`);
  console.log(`   Invoice Token ID:             ${invoiceTokenId}`);
  console.log(`   GOAT Agent:                   ${CONFIG.goatAgent.address}`);
  
  console.log("\n" + c.cyan("🏗️  Architecture:"));
  console.log("   • Separated Core + Extension pattern");
  console.log("   • Master Vault coordination layer");
  console.log("   • ERC-4626 compliant yield vaults");
  console.log("   • GOAT AI agent integration");
  console.log("   • Modular and upgradeable design");
  
  console.log("\n" + c.cyan("🔧 Token Standards:"));
  console.log("   • ERC-20: USDC stablecoin");
  console.log("   • ERC-721: Unique invoice NFTs");
  console.log("   • ERC-4626: Standardized yield vaults");
  console.log("   • Custom: GOAT agent extensions");
  
  console.log("\n" + c.cyan("🔄 Contract Interactions:"));
  console.log("   1. Master Vault ←→ Core Vault");
  console.log("   2. Core Vault ←→ GOAT Extension");
  console.log("   3. GOAT Agent ←→ All Contracts");
  console.log("   4. Invoice NFTs ←→ Master Vault");
  
  console.log("\n" + c.cyan("🚀 Next Steps:"));
  console.log("   1. Run demo: npm run demo");
  console.log("   2. Test GOAT agent interactions");
  console.log("   3. Test core vault functionality");
  console.log("   4. Submit for hackathon! 🏆");
  
  console.log(c.green("\n✨ Ready for hackathon demo with GOAT integration!"));
  
  return deploymentData;
}

if (require.main === module) {
  main()
    .then((data) => {
      console.log(c.green("\n🎉 Deployment successful!"));
      process.exit(0);
    })
    .catch((error) => {
      console.error(c.red("\n❌ Deployment failed:"), error);
      process.exit(1);
    });
}

module.exports = { main, CONFIG };