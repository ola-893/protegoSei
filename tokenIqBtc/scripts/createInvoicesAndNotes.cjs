const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting Invoice and Multi-Invoice Note Creation Script...");

  // --- Configuration ---
  // Ensure these addresses are from your LATEST SUCCESSFUL deployment.
  // You can typically find them in 'deployments/protego-latest.json'
  const deploymentData = require("../deployments/protego-latest.json");

  const usdcAddress = deploymentData.contracts.mockUSDC;
  const masterVaultAddress = deploymentData.contracts.masterVault;
  const invoiceNFTAddress = deploymentData.contracts.invoiceNFT;
  const multiInvoiceNotesAddress = deploymentData.contracts.multiInvoiceNotes;

  console.log(`Using Mock USDC Address: ${usdcAddress}`);
  console.log(`Using Master Vault Address: ${masterVaultAddress}`);
  console.log(`Using Invoice NFT Address: ${invoiceNFTAddress}`);
  console.log(`Using Multi-Invoice Notes Address: ${multiInvoiceNotesAddress}`);

  // Get signers
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address: ${deployer.address}`);

  // --- Load Contract Instances ---
  const MasterVaultFactory = await ethers.getContractFactory("ProtegoMasterVault");
  const masterVault = MasterVaultFactory.attach(masterVaultAddress);

  const MultiInvoiceNotesFactory = await ethers.getContractFactory("ProtegoMultiInvoiceNotes");
  const multiInvoiceNotes = MultiInvoiceNotesFactory.attach(multiInvoiceNotesAddress);

  // Interface for parsing InvoiceCreated event from ProtegoInvoiceNFT
  // This must EXACTLY match the event signature in ProtegoInvoiceNFT.sol
  const invoiceNFTInterface = new ethers.utils.Interface([
    "event InvoiceCreated(uint256 indexed tokenId, address indexed issuer, address indexed debtor, uint256 faceValue, uint256 discountRate, uint256 maturityDate, address vaultAddress)"
  ]);


  // --- Create Sample Invoices ---
  console.log("\n--- Creating Sample Invoice NFTs ---");
  const sampleInvoiceDetails = [
    { debtor: deployer.address, faceValue: ethers.utils.parseUnits("10000", 6), dueDate: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60) }, // 90 days
    { debtor: deployer.address, faceValue: ethers.utils.parseUnits("15000", 6), dueDate: Math.floor(Date.now() / 1000) + (60 * 24 * 60 * 60) }, // 60 days
    { debtor: deployer.address, faceValue: ethers.utils.parseUnits("8000", 6), dueDate: Math.floor(Date.now() / 1000) + (120 * 24 * 60 * 60) }, // 120 days
    { debtor: deployer.address, faceValue: ethers.utils.parseUnits("12000", 6), dueDate: Math.floor(Date.now() / 1000) + (75 * 24 * 60 * 60) }, // 75 days
    { debtor: deployer.address, faceValue: ethers.utils.parseUnits("20000", 6), dueDate: Math.floor(Date.now() / 1000) + (45 * 24 * 60 * 60) }, // 45 days
    { debtor: deployer.address, faceValue: ethers.utils.parseUnits("25000", 6), dueDate: Math.floor(Date.now() / 1000) + (150 * 24 * 60 * 60) } // 150 days
  ];

  const mintedInvoiceTokenIds = [];
  for (let i = 0; i < sampleInvoiceDetails.length; i++) {
    const invoice = sampleInvoiceDetails[i];
    try {
      console.log(`Attempting to create invoice for debtor ${invoice.debtor}...`);

      // Call createInvoiceAndVault on the MasterVault
      const tx = await masterVault.createInvoiceAndVault(
        invoice.debtor,
        invoice.faceValue,
        200, // discountRate (e.g., 200 bps = 2%)
        90,  // maturityDays (e.g., 90 days)
        30,  // fundingDeadlineDays (e.g., 30 days)
        `ipfs://invoice_metadata_${i + 1}`, // metadataURI
        `Vault for ${invoice.debtor.substring(0, 6)}...`, // vaultName
        `VLT${i + 1}` // vaultSymbol
      );
      const receipt = await tx.wait();

      let createdTokenId = null;
      // Look for the InvoiceCreated event emitted by the ProtegoInvoiceNFT contract
      for (const log of receipt.logs) {
        if (log.address.toLowerCase() === invoiceNFTAddress.toLowerCase()) {
          try {
            const parsedLog = invoiceNFTInterface.parseLog(log);
            if (parsedLog.name === "InvoiceCreated") {
              createdTokenId = parsedLog.args.tokenId.toNumber();
              break;
            }
          } catch (e) {
            // Ignore logs that are not InvoiceCreated from the NFT contract
          }
        }
      }

      if (createdTokenId !== null) {
        mintedInvoiceTokenIds.push(createdTokenId);
        console.log(`✅ Created Invoice NFT with ID: ${createdTokenId} for ${invoice.debtor}`);
      } else {
        console.warn(`⚠️ Transaction for invoice ${i + 1} succeeded, but could not find InvoiceCreated event.`);
      }

    } catch (error) {
      console.error(`❌ Failed to create invoice ${i + 1}: ${error.message}`);
    }
  }

  console.log(`\nSuccessfully created ${mintedInvoiceTokenIds.length} Invoice NFTs: [${mintedInvoiceTokenIds.join(', ')}]`);

  // --- Create Multi-Invoice Note Types ---
  console.log("\n--- Creating Multi-Invoice Note Portfolios ---");

  if (mintedInvoiceTokenIds.length === 0) {
    console.error("❌ No invoices were successfully created. Cannot create Multi-Invoice Note Portfolios.");
    return;
  }

  const noteTypesData = [
    {
      name: "Q1 2024 High-Yield Portfolio",
      invoiceTokenIds: mintedInvoiceTokenIds.slice(0, 3), // Use actual invoice IDs
      minimumPurchase: ethers.utils.parseUnits("100", 18), // 100 units (scaled to 18 decimals)
      pricePerUnit: ethers.utils.parseUnits("1", 18),    // 1 USDC per unit (scaled to 18 decimals)
    },
    {
      name: "Q2 2024 Balanced Portfolio",
      invoiceTokenIds: mintedInvoiceTokenIds.slice(3, 6), // Use actual invoice IDs
      minimumPurchase: ethers.utils.parseUnits("50", 18),  // 50 units (scaled to 18 decimals)
      pricePerUnit: ethers.utils.parseUnits("1.5", 18),  // 1.5 USDC per unit (scaled to 18 decimals)
    },
  ];

  const createdNoteTypeIds = [];
  for (let i = 0; i < noteTypesData.length; i++) {
    const portfolio = noteTypesData[i];
    if (portfolio.invoiceTokenIds.length === 0) {
      console.warn(`⚠️ Skipping portfolio "${portfolio.name}" as it has no associated invoice IDs.`);
      continue;
    }

    try {
      console.log(`Attempting to create note type: "${portfolio.name}"...`);
      const tx = await multiInvoiceNotes.createNoteType(
        portfolio.name,
        portfolio.invoiceTokenIds,
        portfolio.minimumPurchase,
        portfolio.pricePerUnit
      );
      await tx.wait();

      // Assuming createNoteType emits an event with the new noteTypeId,
      // or using a simple increment for demo purposes as in the original script.
      // For more robustness, you'd parse a NoteTypeCreated event here.
      const noteTypeId = i + 1; // Simplistic ID assignment for now
      createdNoteTypeIds.push(noteTypeId);

      console.log(`✅ Created note type #${noteTypeId} for "${portfolio.name}"`);
      console.log(`   Invoices included: [${portfolio.invoiceTokenIds.join(', ')}]`);
    } catch (error) {
      console.error(`❌ Failed to create note type "${portfolio.name}": ${error.message}`);
    }
  }

  console.log(`\nSuccessfully created ${createdNoteTypeIds.length} Multi-Invoice Note Types: [${createdNoteTypeIds.join(', ')}]`);
  console.log("\n🎉 Script finished successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("🚨 Script failed:", error);
    process.exit(1);
  });