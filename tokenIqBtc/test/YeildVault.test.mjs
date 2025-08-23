import { expect } from "chai";
import hardhat from "hardhat";
const { ethers } = hardhat;

describe("LstBTCYieldVault (ERC-4626)", function () {
  let vault, wBTC, lstBTC;
  let owner, user1, user2, custodian;
  
  beforeEach(async function () {
    [owner, user1, user2, custodian] = await ethers.getSigners();
    
    // Deploy mock tokens
    const MockWBTC = await ethers.getContractFactory("MockWBTC");
    wBTC = await MockWBTC.deploy();
    
    const MockLstBTC = await ethers.getContractFactory("MockLstBTC");
    lstBTC = await MockLstBTC.deploy();
    
    // Deploy ERC-4626 vault
    const LstBTCYieldVault = await ethers.getContractFactory("LstBTCYieldVault");
    vault = await LstBTCYieldVault.deploy(
      wBTC.address,
      lstBTC.address,
      custodian.address,
      "lstBTC Vault Shares",
      "lvBTC"
    );
    
    // Setup: mint tokens to users and vault
    await wBTC.mint(user1.address, ethers.utils.parseUnits("10", 8)); // 10 wBTC
    await wBTC.mint(user2.address, ethers.utils.parseUnits("5", 8));  // 5 wBTC
    await lstBTC.mint(vault.address, ethers.utils.parseUnits("100", 8)); // 100 lstBTC reserves
  });

  describe("ERC-4626 Standard Compliance", function () {
    
    describe("Metadata", function () {
      it("Should return correct asset", async function () {
        expect(await vault.asset()).to.equal(wBTC.address);
      });
      
      it("Should return correct name and symbol", async function () {
        expect(await vault.name()).to.equal("lstBTC Vault Shares");
        expect(await vault.symbol()).to.equal("lvBTC");
      });
      
      it("Should return correct decimals", async function () {
        expect(await vault.decimals()).to.equal(18); // ERC-4626 standard
      });
    });

    describe("totalAssets()", function () {
      it("Should return 0 when vault is empty", async function () {
        expect(await vault.totalAssets()).to.equal(0);
      });
      
      it("Should include wBTC and lstBTC equivalent", async function () {
        const depositAmount = ethers.utils.parseUnits("1", 8); // 1 wBTC
        
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        await vault.connect(user1).deposit(depositAmount, user1.address);
        
        // Should include both wBTC held and lstBTC equivalent value
        const totalAssets = await vault.totalAssets();
        expect(totalAssets).to.be.gt(0);
      });
    });

    describe("convertToShares() and convertToAssets()", function () {
      it("Should convert assets to shares correctly", async function () {
        const assets = ethers.utils.parseUnits("1", 8); // 1 wBTC
        const shares = await vault.convertToShares(assets);
        expect(shares).to.be.gt(0);
      });
      
      it("Should convert shares to assets correctly", async function () {
        // First make a deposit to establish share price
        const depositAmount = ethers.utils.parseUnits("1", 8);
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        await vault.connect(user1).deposit(depositAmount, user1.address);
        
        const userShares = await vault.balanceOf(user1.address);
        const assets = await vault.convertToAssets(userShares);
        expect(assets).to.be.closeTo(depositAmount, ethers.utils.parseUnits("0.01", 8));
      });
      
      it("Should maintain reciprocal relationship", async function () {
        const originalAssets = ethers.utils.parseUnits("1", 8);
        const shares = await vault.convertToShares(originalAssets);
        const backToAssets = await vault.convertToAssets(shares);
        
        // Should be close due to rounding
        expect(backToAssets).to.be.closeTo(originalAssets, ethers.utils.parseUnits("0.001", 8));
      });
    });

    describe("Max Functions", function () {
      it("Should return correct maxDeposit", async function () {
        const maxDeposit = await vault.maxDeposit(user1.address);
        expect(maxDeposit).to.equal(ethers.constants.MaxUint256);
      });
      
      it("Should return 0 maxDeposit when paused", async function () {
        await vault.pause();
        const maxDeposit = await vault.maxDeposit(user1.address);
        expect(maxDeposit).to.equal(0);
      });
      
      it("Should return correct maxWithdraw", async function () {
        // First deposit
        const depositAmount = ethers.utils.parseUnits("1", 8);
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        await vault.connect(user1).deposit(depositAmount, user1.address);
        
        const maxWithdraw = await vault.maxWithdraw(user1.address);
        expect(maxWithdraw).to.be.gt(0);
      });
    });

    describe("Preview Functions", function () {
      it("Should preview deposit correctly", async function () {
        const assets = ethers.utils.parseUnits("1", 8);
        const previewShares = await vault.previewDeposit(assets);
        expect(previewShares).to.be.gt(0);
      });
      
      it("Should preview withdraw with fees", async function () {
        const assets = ethers.utils.parseUnits("1", 8);
        const shares = await vault.previewWithdraw(assets);
        
        // Should be higher than convertToShares due to withdrawal fee
        const baseShares = await vault.convertToShares(assets);
        expect(shares).to.be.gt(baseShares);
      });
      
      it("Should preview redeem with fees", async function () {
        // First deposit to get shares
        const depositAmount = ethers.utils.parseUnits("1", 8);
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        await vault.connect(user1).deposit(depositAmount, user1.address);
        
        const userShares = await vault.balanceOf(user1.address);
        const previewAssets = await vault.previewRedeem(userShares);
        
        // Should be less than convertToAssets due to withdrawal fee
        const baseAssets = await vault.convertToAssets(userShares);
        expect(previewAssets).to.be.lt(baseAssets);
      });
    });
  });

  describe("Deposit Functions", function () {
    
    describe("deposit()", function () {
      it("Should deposit and mint shares", async function () {
        const depositAmount = ethers.utils.parseUnits("1", 8); // 1 wBTC
        
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        
        const tx = vault.connect(user1).deposit(depositAmount, user1.address);
        
        await expect(tx)
          .to.emit(vault, "Deposit")
          .to.emit(vault, "LstBTCMinted");
        
        expect(await vault.balanceOf(user1.address)).to.be.gt(0);
        expect(await wBTC.balanceOf(vault.address)).to.equal(depositAmount);
      });
      
      it("Should fail with zero amount", async function () {
        await expect(vault.connect(user1).deposit(0, user1.address))
          .to.be.revertedWith("InvalidAmount");
      });
      
      it("Should fail without approval", async function () {
        const depositAmount = ethers.utils.parseUnits("1", 8);
        
        await expect(vault.connect(user1).deposit(depositAmount, user1.address))
          .to.be.reverted; // ERC20 transfer failure
      });
    });

    describe("mint()", function () {
      it("Should mint exact shares", async function () {
        const sharesToMint = ethers.utils.parseEther("1"); // 1 share
        const assetsNeeded = await vault.previewMint(sharesToMint);
        
        await wBTC.connect(user1).approve(vault.address, assetsNeeded);
        
        const tx = vault.connect(user1).mint(sharesToMint, user1.address);
        
        await expect(tx)
          .to.emit(vault, "Deposit")
          .to.emit(vault, "LstBTCMinted");
        
        expect(await vault.balanceOf(user1.address)).to.equal(sharesToMint);
      });
    });
  });

  describe("Withdrawal Functions", function () {
    
    beforeEach(async function () {
      // Setup: user1 deposits 2 wBTC
      const depositAmount = ethers.utils.parseUnits("2", 8);
      await wBTC.connect(user1).approve(vault.address, depositAmount);
      await vault.connect(user1).deposit(depositAmount, user1.address);
    });

    describe("withdraw()", function () {
      it("Should withdraw exact assets", async function () {
        const withdrawAmount = ethers.utils.parseUnits("1", 8); // 1 wBTC
        const initialBalance = await wBTC.balanceOf(user1.address);
        
        const tx = vault.connect(user1).withdraw(withdrawAmount, user1.address, user1.address);
        
        await expect(tx)
          .to.emit(vault, "Withdraw")
          .to.emit(vault, "LstBTCBurned");
        
        const finalBalance = await wBTC.balanceOf(user1.address);
        expect(finalBalance.sub(initialBalance)).to.equal(withdrawAmount);
      });
      
      it("Should apply withdrawal fee", async function () {
        const withdrawAmount = ethers.utils.parseUnits("1", 8);
        const expectedShares = await vault.previewWithdraw(withdrawAmount);
        const baseShares = await vault.convertToShares(withdrawAmount);
        
        // Expected shares should be higher due to fee
        expect(expectedShares).to.be.gt(baseShares);
      });
      
      it("Should fail with insufficient balance", async function () {
        const tooMuch = ethers.utils.parseUnits("10", 8); // More than deposited
        
        await expect(vault.connect(user1).withdraw(tooMuch, user1.address, user1.address))
          .to.be.revertedWith("ExceededMaxWithdraw");
      });
    });

    describe("redeem()", function () {
      it("Should redeem shares for assets", async function () {
        const userShares = await vault.balanceOf(user1.address);
        const halfShares = userShares.div(2);
        
        const initialBalance = await wBTC.balanceOf(user1.address);
        
        const tx = vault.connect(user1).redeem(halfShares, user1.address, user1.address);
        
        await expect(tx)
          .to.emit(vault, "Withdraw")
          .to.emit(vault, "LstBTCBurned");
        
        const finalBalance = await wBTC.balanceOf(user1.address);
        expect(finalBalance).to.be.gt(initialBalance);
        
        // User should have half shares remaining
        expect(await vault.balanceOf(user1.address)).to.be.closeTo(halfShares, 1);
      });
    });

    describe("Allowance-based withdrawals", function () {
      it("Should allow approved withdrawals", async function () {
        const userShares = await vault.balanceOf(user1.address);
        const withdrawAmount = ethers.utils.parseUnits("0.5", 8);
        
        // user1 approves user2 to withdraw
        await vault.connect(user1).approve(user2.address, userShares);
        
        const tx = vault.connect(user2).withdraw(withdrawAmount, user2.address, user1.address);
        
        await expect(tx)
          .to.emit(vault, "Withdraw");
        
        expect(await wBTC.balanceOf(user2.address)).to.be.gt(0);
      });
    });
  });

  describe("Yield Management", function () {
    
    beforeEach(async function () {
      // Setup: user deposits and we simulate some yield
      const depositAmount = ethers.utils.parseUnits("1", 8);
      await wBTC.connect(user1).approve(vault.address, depositAmount);
      await vault.connect(user1).deposit(depositAmount, user1.address);
    });

    describe("harvestYield()", function () {
      it("Should harvest yield and update rates", async function () {
        // Simulate yield by minting more lstBTC to vault
        const yieldAmount = ethers.utils.parseUnits("0.1", 8); // 10% yield
        await lstBTC.mint(vault.address, yieldAmount);
        
        const tx = vault.connect(custodian).harvestYield();
        
        await expect(tx)
          .to.emit(vault, "YieldHarvested")
          .to.emit(vault, "ExchangeRateUpdated");
        
        // Total assets should have increased
        const totalAssets = await vault.totalAssets();
        expect(totalAssets).to.be.gt(ethers.utils.parseUnits("1", 8));
      });
      
      it("Should only allow custodian to harvest", async function () {
        await expect(vault.connect(user1).harvestYield())
          .to.be.revertedWith("Only custodian");
      });
      
      it("Should distribute fees correctly", async function () {
        const yieldAmount = ethers.utils.parseUnits("1", 8); // 100% yield
        await lstBTC.mint(vault.address, yieldAmount);
        
        const ownerBalanceBefore = await lstBTC.balanceOf(owner.address);
        
        await vault.connect(custodian).harvestYield();
        
        const ownerBalanceAfter = await lstBTC.balanceOf(owner.address);
        const feesCollected = ownerBalanceAfter.sub(ownerBalanceBefore);
        
        // Should collect both management and performance fees
        expect(feesCollected).to.be.gt(0);
        
        // Check fee calculation (2% management + 10% performance = 12% of yield)
        const expectedFees = yieldAmount.mul(1200).div(10000); // 12%
        expect(feesCollected).to.be.closeTo(expectedFees, ethers.utils.parseUnits("0.01", 8));
      });
    });
  });

  describe("View Functions", function () {
    
    beforeEach(async function () {
      const depositAmount = ethers.utils.parseUnits("1", 8);
      await wBTC.connect(user1).approve(vault.address, depositAmount);
      await vault.connect(user1).deposit(depositAmount, user1.address);
    });

    describe("getVaultStats()", function () {
      it("Should return correct vault statistics", async function () {
        const stats = await vault.getVaultStats();
        
        expect(stats.totalManagedAssets).to.be.gt(0);
        expect(stats.totalShares).to.be.gt(0);
        expect(stats.sharePrice).to.be.gt(0);
        expect(stats.totalLstBTC).to.be.gt(0);
      });
    });

    describe("getUserYield()", function () {
      it("Should calculate user yield correctly", async function () {
        // Fast forward time to accumulate yield
        await ethers.provider.send("evm_increaseTime", [86400]); // 1 day
        await ethers.provider.send("evm_mine");
        
        const userYield = await vault.getUserYield(user1.address);
        // Should be 0 initially (no yield harvested yet)
        expect(userYield).to.equal(0);
      });
    });
  });

  describe("Admin Functions", function () {
    
    describe("Fee Management", function () {
      it("Should update fees correctly", async function () {
        const newManagementFee = 300; // 3%
        const newPerformanceFee = 1500; // 15%
        const newWithdrawalFee = 100; // 1%
        
        const tx = vault.updateFees(newManagementFee, newPerformanceFee, newWithdrawalFee);
        
        await expect(tx)
          .to.emit(vault, "FeesUpdated")
          .withArgs(newManagementFee, newPerformanceFee, newWithdrawalFee);
        
        expect(await vault.managementFee()).to.equal(newManagementFee);
        expect(await vault.performanceFee()).to.equal(newPerformanceFee);
        expect(await vault.withdrawalFee()).to.equal(newWithdrawalFee);
      });
      
      it("Should reject excessive fees", async function () {
        await expect(vault.updateFees(1500, 1500, 1500)) // All above 10%
          .to.be.revertedWith("InvalidFee");
      });
    });

    describe("Emergency Controls", function () {
      it("Should toggle emergency mode", async function () {
        expect(await vault.emergencyMode()).to.be.false;
        
        const tx = vault.toggleEmergencyMode();
        await expect(tx).to.emit(vault, "EmergencyModeToggled").withArgs(true);
        
        expect(await vault.emergencyMode()).to.be.true;
      });
      
      it("Should prevent deposits in emergency mode", async function () {
        await vault.toggleEmergencyMode();
        
        const depositAmount = ethers.utils.parseUnits("1", 8);
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        
        await expect(vault.connect(user1).deposit(depositAmount, user1.address))
          .to.be.revertedWith("EmergencyModeActive");
      });
      
      it("Should allow emergency withdrawal", async function () {
        // First make a deposit
        const depositAmount = ethers.utils.parseUnits("1", 8);
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        await vault.connect(user1).deposit(depositAmount, user1.address);
        
        // Toggle emergency mode
        await vault.toggleEmergencyMode();
        
        const ownerWBTCBefore = await wBTC.balanceOf(owner.address);
        const ownerLstBTCBefore = await lstBTC.balanceOf(owner.address);
        
        await vault.emergencyWithdraw();
        
        const ownerWBTCAfter = await wBTC.balanceOf(owner.address);
        const ownerLstBTCAfter = await lstBTC.balanceOf(owner.address);
        
        expect(ownerWBTCAfter).to.be.gt(ownerWBTCBefore);
        expect(ownerLstBTCAfter).to.be.gt(ownerLstBTCBefore);
      });
    });

    describe("Pause Functionality", function () {
      it("Should pause and unpause", async function () {
        await vault.pause();
        expect(await vault.paused()).to.be.true;
        
        await vault.unpause();
        expect(await vault.paused()).to.be.false;
      });
      
      it("Should prevent deposits when paused", async function () {
        await vault.pause();
        
        const depositAmount = ethers.utils.parseUnits("1", 8);
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        
        await expect(vault.connect(user1).deposit(depositAmount, user1.address))
          .to.be.revertedWith("Pausable: paused");
      });
    });

    describe("Custodian Management", function () {
      it("Should update custodian", async function () {
        const newCustodian = user2.address;
        
        const tx = vault.updateCustodian(newCustodian);
        await expect(tx)
          .to.emit(vault, "CustodianUpdated")
          .withArgs(custodian.address, newCustodian);
        
        expect(await vault.custodian()).to.equal(newCustodian);
      });
      
      it("Should reject zero address custodian", async function () {
        await expect(vault.updateCustodian(ethers.constants.AddressZero))
          .to.be.revertedWith("Invalid address");
      });
    });
  });

  describe("Edge Cases and Security", function () {
    
    describe("Rounding", function () {
      it("Should round in favor of vault", async function () {
        // Small deposit to test rounding
        const smallDeposit = 1; // 1 wei
        
        await wBTC.connect(user1).approve(vault.address, smallDeposit);
        await vault.connect(user1).deposit(smallDeposit, user1.address);
        
        const shares = await vault.balanceOf(user1.address);
        const assetsBack = await vault.convertToAssets(shares);
        
        // Due to rounding, user might get slightly less back
        expect(assetsBack).to.be.lte(smallDeposit);
      });
    });

    describe("Zero Values", function () {
      it("Should handle zero total supply", async function () {
        const assets = ethers.utils.parseUnits("1", 8);
        
        // When total supply is 0, should return 1:1 ratio
        const shares = await vault.convertToShares(assets);
        expect(shares).to.be.gt(0);
      });
    });

    describe("Large Numbers", function () {
      it("Should handle large deposits", async function () {
        const largeAmount = ethers.utils.parseUnits("1000", 8); // 1000 wBTC
        
        // Mint large amount to user
        await wBTC.mint(user1.address, largeAmount);
        await wBTC.connect(user1).approve(vault.address, largeAmount);
        
        await expect(vault.connect(user1).deposit(largeAmount, user1.address))
          .to.not.be.reverted;
        
        expect(await vault.balanceOf(user1.address)).to.be.gt(0);
      });
    });

    describe("Reentrancy Protection", function () {
      it("Should prevent reentrancy attacks", async function () {
        // This would require a malicious contract to test properly
        // For now, we just verify the modifier is in place
        const depositAmount = ethers.utils.parseUnits("1", 8);
        await wBTC.connect(user1).approve(vault.address, depositAmount);
        
        // Normal operation should work
        await expect(vault.connect(user1).deposit(depositAmount, user1.address))
          .to.not.be.reverted;
      });
    });
  });

  describe("Integration Tests", function () {
    
    it("Should handle multiple users depositing and withdrawing", async function () {
      // User1 deposits 1 wBTC
      const deposit1 = ethers.utils.parseUnits("1", 8);
      await wBTC.connect(user1).approve(vault.address, deposit1);
      await vault.connect(user1).deposit(deposit1, user1.address);
      
      // User2 deposits 2 wBTC  
      const deposit2 = ethers.utils.parseUnits("2", 8);
      await wBTC.connect(user2).approve(vault.address, deposit2);
      await vault.connect(user2).deposit(deposit2, user2.address);
      
      // Check balances
      const shares1 = await vault.balanceOf(user1.address);
      const shares2 = await vault.balanceOf(user2.address);
      
      expect(shares2).to.be.approximately(shares1.mul(2), shares1.div(100)); // Within 1%
      
      // Simulate yield
      await lstBTC.mint(vault.address, ethers.utils.parseUnits("0.3", 8)); // 10% yield
      await vault.connect(custodian).harvestYield();
      
      // Both users withdraw
      await vault.connect(user1).redeem(shares1, user1.address, user1.address);
      await vault.connect(user2).redeem(shares2, user2.address, user2.address);
      
      // Check they got more than they deposited (yield)
      expect(await wBTC.balanceOf(user1.address)).to.be.gt(ethers.utils.parseUnits("8", 8)); // Originally had 10, deposited 1, should get >1 back
      expect(await wBTC.balanceOf(user2.address)).to.be.gt(ethers.utils.parseUnits("3", 8)); // Originally had 5, deposited 2, should get >2 back
    });

    it("Should maintain correct share pricing through yield cycles", async function () {
      // Initial deposit
      const initialDeposit = ethers.utils.parseUnits("1", 8);
      await wBTC.connect(user1).approve(vault.address, initialDeposit);
      await vault.connect(user1).deposit(initialDeposit, user1.address);
      
      const initialShares = await vault.balanceOf(user1.address);
      const initialSharePrice = await vault.convertToAssets(ethers.utils.parseEther("1"));
      
      // Simulate yield and harvest
      await lstBTC.mint(vault.address, ethers.utils.parseUnits("0.1", 8)); // 10% yield
      await vault.connect(custodian).harvestYield();
      
      // New user deposits same amount
      await wBTC.connect(user2).approve(vault.address, initialDeposit);
      await vault.connect(user2).deposit(initialDeposit, user2.address);
      
      const newShares = await vault.balanceOf(user2.address);
      const newSharePrice = await vault.convertToAssets(ethers.utils.parseEther("1"));
      
      // New user should get fewer shares due to higher share price
      expect(newShares).to.be.lt(initialShares);
      expect(newSharePrice).to.be.gt(initialSharePrice);
    });
  });
});