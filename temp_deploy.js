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
