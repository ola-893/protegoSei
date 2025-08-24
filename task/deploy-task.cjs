
// Custom Hardhat tasks for Sei-specific operations
const { task } = require("hardhat/config");

// Task to deploy on Sei Testnet
task("deploy-sei-testnet", "Deploy Protego.ai contracts to Sei testnet")
  .setAction(async (taskArgs, hre) => {
    console.log("🌊 Deploying to Sei Atlantic-2 Testnet...");
    
    const network = await hre.ethers.provider.getNetwork();
    console.log(`Connected to chain ID: ${network.chainId}`);
    
    if (network.chainId !== 713715n) {
      throw new Error("Not connected to Sei testnet. Please check your network configuration.");
    }
    
    // Run the deployment script
    await hre.run("run", { script: "scripts/deploy-sei.js" });
  });

// Task to deploy on Sei Mainnet  
task("deploy-sei-mainnet", "Deploy Protego.ai contracts to Sei mainnet")
  .addFlag("verify", "Verify contracts after deployment")
  .setAction(async (taskArgs, hre) => {
    console.log("🌊 Deploying to Sei Pacific-1 Mainnet...");
    
    const network = await hre.ethers.provider.getNetwork();
    console.log(`Connected to chain ID: ${network.chainId}`);
    
    if (network.chainId !== 1329n) {
      throw new Error("Not connected to Sei mainnet. Please check your network configuration.");
    }
    
    // Run the deployment script
    await hre.run("run", { script: "scripts/deploy-sei.js" });
    
    if (taskArgs.verify) {
      console.log("🔍 Verifying contracts...");
      // Add verification logic here
    }
  });

// Task to run simulation
task("simulate-protego", "Run Protego.ai simulation on local network")
  .setAction(async (taskArgs, hre) => {
    console.log("🧪 Running Protego.ai simulation...");
    await hre.run("run", { script: "scripts/simulate-protego.js" });
  });

// Task to check Sei network status
task("sei-status", "Check Sei network connection and status")
  .setAction(async (taskArgs, hre) => {
    const provider = hre.ethers.provider;
    const network = await provider.getNetwork();
    const latestBlock = await provider.getBlock("latest");
    const gasPrice = await provider.getFeeData();
    
    console.log("🌊 Sei Network Status:");
    console.log(`   • Chain ID: ${network.chainId}`);
    console.log(`   • Network Name: ${network.name}`);
    console.log(`   • Latest Block: ${latestBlock.number}`);
    console.log(`   • Block Timestamp: ${new Date(latestBlock.timestamp * 1000).toISOString()}`);
    console.log(`   • Gas Price: ${hre.ethers.formatUnits(gasPrice.gasPrice || 0, "gwei")} gwei`);
    console.log(`   • Max Fee: ${hre.ethers.formatUnits(gasPrice.maxFeePerGas || 0, "gwei")} gwei`);
    console.log(`   • Priority Fee: ${hre.ethers.formatUnits(gasPrice.maxPriorityFeePerGas || 0, "gwei")} gwei`);
  });

// Task to estimate deployment costs
task("estimate-costs", "Estimate deployment costs for Protego.ai contracts")
  .setAction(async (taskArgs, hre) => {
    console.log("💰 Estimating deployment costs on Sei Network...");
    
    const gasPrice = await hre.ethers.provider.getFeeData();
    const currentGasPrice = gasPrice.gasPrice || hre.ethers.parseUnits("0.1", "gwei");
    
    // Estimated gas costs for each contract
    const contractEstimates = {
      "MockERC20 (USDC)": 800000,
      "ProtegoInvoiceNFT": 2500000,
      "ProtegoYieldVault": 3200000,
      "ProtegoMultiInvoiceNotes": 2800000,
      "ProtegoMasterVault": 3500000,
      "ProtegoYieldStrategy": 1800000
    };
    
    let totalGas = 0;
    
    console.log("📊 Contract Deployment Estimates:");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    for (const [contractName, gasEstimate] of Object.entries(contractEstimates)) {
      const cost = currentGasPrice * BigInt(gasEstimate);
      const costInEth = hre.ethers.formatEther(cost);
      console.log(`${contractName.padEnd(25)}: ${gasEstimate.toLocaleString()} gas (~${parseFloat(costInEth).toFixed(6)} SEI)`);
      totalGas += gasEstimate;
    }
    
    const totalCost = currentGasPrice * BigInt(totalGas);
    const totalCostInEth = hre.ethers.formatEther(totalCost);
    
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log(`${"TOTAL".padEnd(25)}: ${totalGas.toLocaleString()} gas (~${parseFloat(totalCostInEth).toFixed(6)} SEI)`);
    console.log(`\n💡 At current gas price: ${hre.ethers.formatUnits(currentGasPrice, "gwei")} gwei`);
  });

// Task to fund accounts for testing
task("fund-accounts", "Fund test accounts with SEI and USDC")
  .addParam("amount", "Amount of SEI to send to each account", "10")
  .setAction(async (taskArgs, hre) => {
    const [deployer] = await hre.ethers.getSigners();
    const amount = hre.ethers.parseEther(taskArgs.amount);
    
    // Test accounts to fund
    const testAccounts = [
      "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", // Marina
      "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", // Fashion Inc
      "0x90F79bf6EB2c4f870365E785982E1f101E93b906", // Investor 1
      "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65", // Investor 2
      "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", // Investor 3
    ];
    
    console.log(`🏦 Funding ${testAccounts.length} accounts with ${taskArgs.amount} SEI each...`);
    
    for (const account of testAccounts) {
      const tx = await deployer.sendTransaction({
        to: account,
        value: amount,
      });
      await tx.wait();
      console.log(`✅ Sent ${taskArgs.amount} SEI to ${account}`);
    }
    
    console.log("💰 All accounts funded successfully!");
  });