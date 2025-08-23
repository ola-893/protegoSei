#!/usr/bin/env node

/**
 * 🛠️ PROTEGO.AI - Vault State Diagnostic Script
 *
 * Queries the deployed vault on Sei testnet and prints out all
 * critical parameters that affect `deposit()`.
 */

const { ethers } = require("ethers");

// Replace with Sei testnet RPC + vault address
const RPC_URL = "https://evm-rpc-testnet.sei-apis.com"; 
const VAULT_ADDRESS = "0xe91EF9C06aDD6b030bfb22cbf7dfF51904DEaC10";

// Minimal ABI for diagnostics
const VAULT_ABI = [
  "function isActive() view returns (bool)",
  "function emergencyPaused() view returns (bool)",
  "function fundingDeadline() view returns (uint256)",
  "function minimumDeposit() view returns (uint256)",
  "function maximumDeposit() view returns (uint256)",
  "function fundingTarget() view returns (uint256)",
  "function totalAssets() view returns (uint256)",
  "function asset() view returns (address)"
];

// Color functions
const c = {
  red: (s) => `\x1b[31m${s}\x1b[0m`,
  green: (s) => `\x1b[32m${s}\x1b[0m`,
  yellow: (s) => `\x1b[33m${s}\x1b[0m`,
  cyan: (s) => `\x1b[36m${s}\x1b[0m`,
  bold: (s) => `\x1b[1m${s}\x1b[0m`
};

async function main() {
  console.log(c.cyan("\n🔍 PROTEGO VAULT DIAGNOSTIC - SEI TESTNET\n"));

  const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
  const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, provider);

  // Query vault state
  const [
    isActive,
    emergencyPaused,
    fundingDeadline,
    minimumDeposit,
    maximumDeposit,
    fundingTarget,
    totalAssets,
    assetAddress
  ] = await Promise.all([
    vault.isActive(),
    vault.emergencyPaused(),
    vault.fundingDeadline(),
    vault.minimumDeposit(),
    vault.maximumDeposit(),
    vault.fundingTarget(),
    vault.totalAssets(),
    vault.asset()
  ]);

  // Format deadline
  const deadlineDate = new Date(fundingDeadline.toNumber() * 1000);

  console.log(`Vault Address: ${c.bold(VAULT_ADDRESS)}`);
  console.log(`Underlying Asset: ${c.bold(assetAddress)}\n`);
  
  console.log(`isActive: ${isActive ? c.green("✅ true") : c.red("❌ false")}`);
  console.log(`emergencyPaused: ${emergencyPaused ? c.red("⏸️ paused") : c.green("▶️ running")}`);
  console.log(`fundingDeadline: ${fundingDeadline} (${deadlineDate.toUTCString()})`);
  console.log(`minimumDeposit: ${ethers.utils.formatUnits(minimumDeposit, 6)} USDC`);
  console.log(`maximumDeposit: ${ethers.utils.formatUnits(maximumDeposit, 6)} USDC`);
  console.log(`fundingTarget: ${ethers.utils.formatUnits(fundingTarget, 6)} USDC`);
  console.log(`totalAssets: ${ethers.utils.formatUnits(totalAssets, 6)} USDC\n`);

  console.log(c.yellow("👉 Use this output to check why deposit() is reverting.\n"));
}

if (require.main === module) {
  main().catch((err) => {
    console.error(c.red("\n❌ Diagnostic failed:"), err);
    process.exit(1);
  });
}
