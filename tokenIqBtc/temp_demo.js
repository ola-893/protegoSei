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
