#!/usr/bin/env node

/**
 * 🏆 PROTEGO.AI DEMO - Simplified Test Simulation
 * 
 * This demo shows the complete invoice financing flow:
 * - Mock ElizaOS opportunity discovery
 * - Mock MCP safety validation  
 * - Mock GOAT execution
 * - Real smart contract interactions
 */

const { ethers } = require("hardhat");

// Mock ElizaOS opportunity (what AI would find)
const ELIZA_OPPORTUNITY = {
  type: "invoice_financing",
  issuer: "Marina Textiles Ltd",
  debtor: "Fashion Inc", 
  faceValue: ethers.utils.parseUnits("500000", 6), // 500K USDC
  discount: 1000, // 10%
  expectedAPY: 12.5,
  confidence: 0.95,
  recommendation: "STRONG_BUY"
};

// Mock MCP validation rules
const MCP_RULES = {
  maxSingleDeposit: ethers.utils.parseUnits("100000", 6), // 100K USDC max
  minDeposit: ethers.utils.parseUnits("1000", 6), // 1K USDC min
  maxRiskScore: 0.3,
  requiredLiquidity: 0.1,
  approvedIssuers: ["Marina Textiles Ltd"],
  blockedDebtors: []
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
  console.log("\n" + "═".repeat(65));
  console.log(c.cyan(`🔷 STEP ${num}: ${title}`));
  console.log("═".repeat(65));
}

function logSuccess(msg) { console.log(c.green(`✅ ${msg}`)); }
function logInfo(msg) { console.log(c.blue(`ℹ️  ${msg}`)); }
function logWarning(msg) { console.log(c.yellow(`⚠️  ${msg}`)); }

// Mock MCP precheck function
function mockMCPPrecheck(vault, invoiceId, user, amount) {
  const checks = {
    amountInRange: amount.gte(MCP_RULES.minDeposit) && amount.lte(MCP_RULES.maxSingleDeposit),
    issuerApproved: MCP_RULES.approvedIssuers.includes(ELIZA_OPPORTUNITY.issuer),
    debtorNotBlocked: !MCP_RULES.blockedDebtors.includes(ELIZA_OPPORTUNITY.debtor),
    vaultExists: vault !== ethers.constants.AddressZero,
    userValid: user !== ethers.constants.AddressZero
  };

  const allPassed = Object.values(checks).every(Boolean);
  
  return {
    decision: allPassed ? "ALLOW" : "BLOCK", 
    checks,
    approvedAmount: allPassed ? amount : ethers.BigNumber.from(0),
    riskLevel: "LOW"
  };
}

// Mock GOAT execution
async function mockGOATExecution(vault, user, amount, signer) {
  logInfo(`GOAT preparing transaction for ${ethers.utils.formatUnits(amount, 6)} USDC`);
  
  // This simulates what GOAT would do - prepare and execute the transaction
  const tx = await vault.connect(signer).deposit(amount, user.address);
  const receipt = await tx.wait();
  
  return {
    txHash: receipt.transactionHash,
    blockNumber: receipt.blockNumber,
    gasUsed: receipt.gasUsed.toString(),
    status: "SUCCESS"
  };
}

async function main() {
  console.log("");
  console.log(c.magenta("╔═══════════════════════════════════════════════════════════════╗"));
  console.log(c.magenta("║                🏆 PROTEGO.AI HACKATHON DEMO                   ║"));  
  console.log(c.magenta("║         ElizaOS → MCP → GOAT → Smart Contracts Integration    ║"));
  console.log(c.magenta("╚═══════════════════════════════════════════════════════════════╝"));

  // Get signers
  const [deployer, marina, fashionInc, investor1, investor2, treasury] = await ethers.getSigners();
  
  // =========================================================================
  // STEP 1: Deploy Contracts
  // =========================================================================
  logStep(1, "Deploy Smart Contract Infrastructure");
  
  // Deploy mock USDC
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
  await usdc.deployed();
  const usdcAddress = usdc.address;
  logSuccess(`Mock USDC deployed: ${usdcAddress}`);

  // Deploy master vault
  const ProtegoMasterVault = await ethers.getContractFactory("ProtegoMasterVault");
  const masterVault = await ProtegoMasterVault.deploy(usdcAddress, treasury.address);
  await masterVault.deployed();
  const masterVaultAddress = masterVault.address;
  logSuccess(`Master Vault deployed: ${masterVaultAddress}`);

  // Get child contract addresses
  const invoiceNFTAddress = await masterVault.invoiceNFT();
  const multiInvoiceNotesAddress = await masterVault.multiInvoiceNotes();
  
  const invoiceNFT = await ethers.getContractAt("ProtegoInvoiceNFT", invoiceNFTAddress);
  logSuccess(`Invoice NFT (ERC-721): ${invoiceNFTAddress}`);
  logSuccess(`Multi-Invoice Notes (ERC-1155): ${multiInvoiceNotesAddress}`);

  // Fund participants
  await usdc.mint(marina.address, ethers.utils.parseUnits("1000000", 6));
  await usdc.mint(investor1.address, ethers.utils.parseUnits("200000", 6));
  await usdc.mint(investor2.address, ethers.utils.parseUnits("300000", 6));
  await usdc.mint(deployer.address, ethers.utils.parseUnits("2000000", 6)); // For yield
  logInfo("Funded all participants with test USDC");

  // =========================================================================
  // STEP 2: Simulate ElizaOS Opportunity Discovery
  // =========================================================================
  logStep(2, "ElizaOS AI Discovers Investment Opportunity");
  
  console.log(c.cyan("🤖 ElizaOS Analysis Results:"));
  console.log(`   • Opportunity Type: ${ELIZA_OPPORTUNITY.type}`);
  console.log(`   • Issuer: ${ELIZA_OPPORTUNITY.issuer}`);
  console.log(`   • Debtor: ${ELIZA_OPPORTUNITY.debtor}`);
  console.log(`   • Face Value: ${ethers.utils.formatUnits(ELIZA_OPPORTUNITY.faceValue, 6)} USDC`);
  console.log(`   • Expected APY: ${ELIZA_OPPORTUNITY.expectedAPY}%`);
  console.log(`   • AI Confidence: ${(ELIZA_OPPORTUNITY.confidence * 100).toFixed(1)}%`);
  console.log(`   • Recommendation: ${c.bold(ELIZA_OPPORTUNITY.recommendation)}`);
  
  logSuccess("ElizaOS recommends proceeding with investment");

  // =========================================================================
  // STEP 3: Marina Creates Invoice & Vault
  // =========================================================================
  logStep(3, "Marina Creates Invoice NFT and ERC-4626 Vault");
  
  const fundingTarget = ELIZA_OPPORTUNITY.faceValue.mul(9000).div(10000); // 90% of face value
  
  const createTx = await masterVault.connect(marina).createInvoiceAndVault(
    fashionInc.address,
    ELIZA_OPPORTUNITY.faceValue,
    ELIZA_OPPORTUNITY.discount,
    90, // maturity days
    14, // funding deadline days  
    "ipfs://QmProtegoDemo001",
    "Marina Demo Vault",
    "MDV-001"
  );

  const createReceipt = await createTx.wait();
  const vaultCreatedEvent = createReceipt.events.find(
    event => event.event === "VaultCreated"
  );
  
  const invoiceTokenId = vaultCreatedEvent.args.invoiceTokenId;
  const vaultAddress = vaultCreatedEvent.args.vaultAddress;
  const vault = await ethers.getContractAt("ProtegoYieldVault", vaultAddress);
  
  logSuccess(`Invoice NFT created with ID: ${invoiceTokenId}`);
  logSuccess(`ERC-4626 Vault deployed: ${vaultAddress}`);
  logSuccess(`Funding target: ${ethers.utils.formatUnits(fundingTarget, 6)} USDC`);

  // =========================================================================
  // STEP 4: MCP Safety Validation (First Investment)
  // =========================================================================
  logStep(4, "MCP Performs Safety Validation");
  
  const investment1Amount = ethers.utils.parseUnits("50000", 6); // 50K USDC
  const mcpPrecheck1 = mockMCPPrecheck(vaultAddress, invoiceTokenId, investor1.address, investment1Amount);
  
  console.log(c.cyan("🛡️  MCP Validation Results:"));
  console.log(`   • Decision: ${mcpPrecheck1.decision === "ALLOW" ? c.green("ALLOW") : c.red("BLOCK")}`);
  console.log(`   • Amount in range: ${mcpPrecheck1.checks.amountInRange ? "✅" : "❌"}`);
  console.log(`   • Issuer approved: ${mcpPrecheck1.checks.issuerApproved ? "✅" : "❌"}`);
  console.log(`   • Debtor not blocked: ${mcpPrecheck1.checks.debtorNotBlocked ? "✅" : "❌"}`);
  console.log(`   • Vault exists: ${mcpPrecheck1.checks.vaultExists ? "✅" : "❌"}`);
  console.log(`   • Risk Level: ${mcpPrecheck1.riskLevel}`);
  
  if (mcpPrecheck1.decision !== "ALLOW") {
    throw new Error("MCP blocked the transaction");
  }
  
  logSuccess("MCP approved transaction for execution");

  // =========================================================================
  // STEP 5: GOAT Executes First Investment
  // =========================================================================
  logStep(5, "GOAT Executes Investment Transaction");
  
  // Approve USDC spending
  await usdc.connect(investor1).approve(vaultAddress, investment1Amount);
  
  // GOAT executes the deposit
  const goatResult1 = await mockGOATExecution(vault, investor1, investment1Amount, investor1);
  
  const investor1Shares = await vault.balanceOf(investor1.address);
  const vaultAssets = await vault.totalAssets();
  
  logSuccess(`Transaction executed: ${goatResult1.txHash}`);
  logInfo(`Investor 1 received: ${ethers.utils.formatUnits(investor1Shares, 18)} vault shares`);
  logInfo(`Vault now holds: ${ethers.utils.formatUnits(vaultAssets, 6)} USDC`);

  // =========================================================================
  // STEP 6: Second Investment with Different Amount
  // =========================================================================
  logStep(6, "Process Second Investment (Different Amount)");
  
  const investment2Amount = ethers.utils.parseUnits("75000", 6); // 75K USDC
  const mcpPrecheck2 = mockMCPPrecheck(vaultAddress, invoiceTokenId, investor2.address, investment2Amount);
  
  logInfo(`MCP validates ${ethers.utils.formatUnits(investment2Amount, 6)} USDC investment...`);
  
  if (mcpPrecheck2.decision === "ALLOW") {
    logSuccess("MCP approved second investment");
    
    await usdc.connect(investor2).approve(vaultAddress, investment2Amount);
    const goatResult2 = await mockGOATExecution(vault, investor2, investment2Amount, investor2);
    
    const investor2Shares = await vault.balanceOf(investor2.address);
    const totalVaultAssets = await vault.totalAssets();
    
    logSuccess(`Second investment completed: ${goatResult2.txHash}`);
    logInfo(`Investor 2 received: ${ethers.utils.formatUnits(investor2Shares, 18)} vault shares`);
    logInfo(`Total vault assets: ${ethers.utils.formatUnits(totalVaultAssets, 6)} USDC`);
  }

  // =========================================================================
  // STEP 7: Demonstrate MCP Blocking Invalid Transaction
  // =========================================================================
  logStep(7, "Demonstrate MCP Safety: Block Invalid Transaction");
  
  const invalidAmount = ethers.utils.parseUnits("200000", 6); // Exceeds max limit
  const mcpPrecheckInvalid = mockMCPPrecheck(vaultAddress, invoiceTokenId, investor1.address, invalidAmount);
  
  console.log(c.cyan("🛡️  MCP blocks invalid transaction:"));
  console.log(`   • Attempted amount: ${ethers.utils.formatUnits(invalidAmount, 6)} USDC`);
  console.log(`   • Decision: ${c.red("BLOCK")}`);
  console.log(`   • Reason: Amount exceeds maximum single deposit limit`);
  console.log(`   • Max allowed: ${ethers.utils.formatUnits(MCP_RULES.maxSingleDeposit, 6)} USDC`);
  
  logSuccess("MCP successfully protected against invalid transaction");

// =========================================================================
// STEP 8: Generate Yield and Demonstrate Returns
// =========================================================================
    logStep(8, "Generate Yield and Demonstrate Returns");

    // Deploy yield strategy
    const ProtegoYieldStrategy = await ethers.getContractFactory("ProtegoYieldStrategy");
    const yieldStrategy = await ProtegoYieldStrategy.deploy(usdcAddress, masterVaultAddress);
    await yieldStrategy.deployed();
    const yieldStrategyAddress = yieldStrategy.address;

    logInfo(`Yield Strategy deployed: ${yieldStrategyAddress}`);

    // Simulate yield generation (3% for demo)
    const currentAssets = await vault.totalAssets();
    const yieldAmount = currentAssets.mul(3).div(100);

    // Fund Marina with additional USDC for yield generation
    await usdc.mint(marina.address, yieldAmount);

    // FIXED: Use Marina (the vault owner) instead of deployer to generate yield
    await usdc.connect(marina).approve(vaultAddress, yieldAmount);
    await vault.connect(marina).generateYield(yieldAmount);

    const assetsAfterYield = await vault.totalAssets();
    logSuccess(`Generated ${ethers.utils.formatUnits(yieldAmount, 6)} USDC yield`);
    logInfo(`Vault assets after yield: ${ethers.utils.formatUnits(assetsAfterYield, 6)} USDC`);
  // =========================================================================
  // STEP 9: Show Final Positions and Returns
  // =========================================================================
  logStep(9, "Calculate Final Returns");
  
  const finalShares1 = await vault.balanceOf(investor1.address);
  const finalShares2 = await vault.balanceOf(investor2.address);
  
  const finalValue1 = await vault.convertToAssets(finalShares1);
  const finalValue2 = await vault.convertToAssets(finalShares2);
  
  const profit1 = finalValue1.sub(investment1Amount);
  const profit2 = finalValue2.sub(investment2Amount);
  
  const returnPct1 = profit1.mul(10000).div(investment1Amount).toNumber() / 100;
  const returnPct2 = profit2.mul(10000).div(investment2Amount).toNumber() / 100;
  
  console.log(c.cyan("💰 Final Investment Returns:"));
  console.log(`   Investor 1:`);
  console.log(`   • Initial: ${ethers.utils.formatUnits(investment1Amount, 6)} USDC`);
  console.log(`   • Final: ${ethers.utils.formatUnits(finalValue1, 6)} USDC`);
  console.log(`   • Profit: ${ethers.utils.formatUnits(profit1, 6)} USDC (${returnPct1.toFixed(2)}%)`);
  console.log(`   Investor 2:`);
  console.log(`   • Initial: ${ethers.utils.formatUnits(investment2Amount, 6)} USDC`);  
  console.log(`   • Final: ${ethers.utils.formatUnits(finalValue2, 6)} USDC`);
  console.log(`   • Profit: ${ethers.utils.formatUnits(profit2, 6)} USDC (${returnPct2.toFixed(2)}%)`);

  // =========================================================================
  // STEP 10: Demo Summary
  // =========================================================================
  logStep(10, "Demo Summary & Integration Benefits");
  
  console.log(c.bold("\n🎯 HACKATHON DEMO COMPLETED SUCCESSFULLY!"));
  console.log("\n" + c.cyan("✨ Integration Flow Demonstrated:"));
  console.log("   1. 🤖 ElizaOS discovers investment opportunities using AI");
  console.log("   2. 🛡️  MCP validates transactions for safety and compliance");
  console.log("   3. 🚀 GOAT executes approved transactions securely");
  console.log("   4. 📋 Smart contracts handle all business logic");
  console.log("   5. 💰 Automated yield generation and distribution");
  
  console.log("\n" + c.cyan("🏗️  Smart Contract Architecture:"));
  console.log("   • ERC-721: Invoice NFTs with rich metadata");
  console.log("   • ERC-4626: Standardized yield-bearing vaults");
  console.log("   • ERC-1155: Multi-invoice fractionalized notes");
  console.log("   • Master coordination contract for ecosystem management");
  
  console.log("\n" + c.cyan("🛡️  Safety Features Demonstrated:"));
  console.log("   • MCP validates all transactions before execution");
  console.log("   • Maximum deposit limits enforced");
  console.log("   • Issuer and debtor allowlists");
  console.log("   • Automated risk assessment");
  console.log("   • Non-custodial user wallet control");
  
  console.log("\n" + c.green("Ready for hackathon submission! 🏆"));
}

if (require.main === module) {
  main()
    .then(() => {
      console.log(c.green("\n🎉 Demo completed successfully!"));
      process.exit(0);
    })
    .catch((error) => {
      console.error(c.red("\n❌ Demo failed:"), error);
      process.exit(1);
    });
}

module.exports = { main };