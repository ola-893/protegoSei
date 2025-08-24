// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/interfaces/IERC4626.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "./protegoInvoiceNFT.sol";
// import "./protegoYieldVault.sol";
// import "./multiInvoiceNotes.sol";

// /**
//  * @title ProtegoMasterVault
//  * @dev Main coordination contract that manages the entire Protego.ai ecosystem
//  * Handles invoice creation, vault deployment, and yield strategies
//  * Enhanced with GOAT integration support
//  */
// contract ProtegoMasterVault is Ownable, ReentrancyGuard, IERC721Receiver, AccessControl {
//     using SafeMath for uint256;
    
//     /// @dev Role definitions
//     bytes32 public constant GOAT_EXECUTOR_ROLE = keccak256("GOAT_EXECUTOR_ROLE");
//     bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
//     bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
//     /// @dev Payment token used across the platform
//     IERC20 public immutable paymentToken;
    
//     /// @dev Invoice NFT contract
//     ProtegoInvoiceNFT public immutable invoiceNFT;
    
//     /// @dev Multi-invoice notes contract
//     ProtegoMultiInvoiceNotes public immutable multiInvoiceNotes;
    
//     /// @dev Platform treasury address
//     address public treasury;
    
//     /// @dev Platform fee in basis points
//     uint256 public platformFeeBps = 200; // 2%
    
//     /// @dev GOAT agent address
//     address public goatAgent;
    
//     /// @dev Mapping from invoice token ID to vault address
//     mapping(uint256 => address) public invoiceVaults;
    
//     /// @dev Array of all deployed vault addresses
//     address[] public allVaults;
    
//     /// @dev Total value locked across all vaults
//     uint256 public totalValueLocked;
    
//     /// @dev Total yield distributed across platform
//     uint256 public totalYieldDistributed;
    
//     /// @dev Track GOAT's global deployment across all vaults
//     mapping(address => uint256) public goatDeploymentByVault;
//     uint256 public totalGoatDeployment;
    
//     event VaultCreated(
//         uint256 indexed invoiceTokenId,
//         address indexed vaultAddress,
//         address indexed issuer,
//         uint256 fundingTarget
//     );
    
//     event PlatformYieldGenerated(
//         uint256 totalAmount,
//         uint256 vaultCount,
//         uint256 timestamp
//     );
    
//     event GoatAgentUpdated(
//         address indexed oldAgent,
//         address indexed newAgent,
//         uint256 timestamp
//     );
    
//     event GlobalEmergencyTriggered(
//         address indexed triggeredBy,
//         uint256 totalDeployedFunds,
//         uint256 vaultCount,
//         uint256 timestamp
//     );
    
//     constructor(
//         address paymentToken_,
//         address treasury_
//     ) {
//         require(paymentToken_ != address(0), "Invalid payment token");
//         require(treasury_ != address(0), "Invalid treasury");
        
//         paymentToken = IERC20(paymentToken_);
//         treasury = treasury_;
        
//         // Deploy invoice NFT contract
//         invoiceNFT = new ProtegoInvoiceNFT();
        
//         // Deploy multi-invoice notes contract
//         multiInvoiceNotes = new ProtegoMultiInvoiceNotes(paymentToken_, address(invoiceNFT));
        
//         // Setup roles
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _grantRole(GOAT_EXECUTOR_ROLE, msg.sender);
//         _grantRole(YIELD_MANAGER_ROLE, msg.sender);
//         _grantRole(EMERGENCY_ROLE, msg.sender);
//     }
    
//     /**
//      * @dev Implements IERC721Receiver to accept NFT transfers
//      */
//     function onERC721Received(
//         address,
//         address,
//         uint256,
//         bytes calldata
//     ) external pure override returns (bytes4) {
//         return IERC721Receiver.onERC721Received.selector;
//     }
    
//     // =================================================================================
//     // GOAT INTEGRATION FUNCTIONS
//     // =================================================================================
    
//     /**
//      * @dev Sets the GOAT agent address and grants necessary roles
//      */
//     function setGoatAgent(address goatAgent_) external onlyRole(DEFAULT_ADMIN_ROLE) {
//         require(goatAgent_ != address(0), "Invalid GOAT agent");
        
//         address oldAgent = goatAgent;
        
//         // Revoke roles from old agent if exists
//         if (oldAgent != address(0)) {
//             _revokeRole(GOAT_EXECUTOR_ROLE, oldAgent);
//             _revokeRole(YIELD_MANAGER_ROLE, oldAgent);
//             _revokeRole(EMERGENCY_ROLE, oldAgent);
//         }
        
//         // Set new agent and grant roles
//         goatAgent = goatAgent_;
//         _grantRole(GOAT_EXECUTOR_ROLE, goatAgent_);
//         _grantRole(YIELD_MANAGER_ROLE, goatAgent_);
//         _grantRole(EMERGENCY_ROLE, goatAgent_);
        
//         // Grant GOAT agent roles in all existing vaults
//         for (uint256 i = 0; i < allVaults.length; i++) {
//             ProtegoYieldVault vault = ProtegoYieldVault(allVaults[i]);
//             vault.grantRole(vault.STRATEGY_EXECUTOR_ROLE(), goatAgent_);
//             vault.grantRole(vault.YIELD_MANAGER_ROLE(), goatAgent_);
//             vault.grantRole(vault.EMERGENCY_ROLE(), goatAgent_);
//         }
        
//         emit GoatAgentUpdated(oldAgent, goatAgent_, block.timestamp);
//     }
    
//     /**
//      * @dev GOAT function to get optimal deployment strategy across all vaults
//      */
//     function getOptimalDeploymentStrategy() external view onlyRole(GOAT_EXECUTOR_ROLE) returns (
//         address[] memory vaultAddresses,
//         uint256[] memory availableAmounts,
//         uint256[] memory recommendedDeployments,
//         uint256 totalRecommended
//     ) {
//         vaultAddresses = new address[](allVaults.length);
//         availableAmounts = new uint256[](allVaults.length);
//         recommendedDeployments = new uint256[](allVaults.length);
//         totalRecommended = 0;
        
//         for (uint256 i = 0; i < allVaults.length; i++) {
//             ProtegoYieldVault vault = ProtegoYieldVault(allVaults[i]);
            
//             vaultAddresses[i] = allVaults[i];
//             availableAmounts[i] = vault.getAvailableForDeployment();
            
//             // Simple strategy: deploy 80% of available funds from each vault
//             recommendedDeployments[i] = availableAmounts[i].mul(80).div(100);
//             totalRecommended = totalRecommended.add(recommendedDeployments[i]);
//         }
        
//         return (vaultAddresses, availableAmounts, recommendedDeployments, totalRecommended);
//     }
    
//     /**
//      * @dev GOAT function to execute batch withdrawal across multiple vaults
//      */
//     function goatBatchWithdrawForYield(
//         address[] memory vaultAddresses,
//         uint256[] memory amounts
//     ) external onlyRole(GOAT_EXECUTOR_ROLE) returns (uint256[] memory sessionIds) {
//         require(vaultAddresses.length == amounts.length, "Array length mismatch");
        
//         sessionIds = new uint256[](vaultAddresses.length);
        
//         for (uint256 i = 0; i < vaultAddresses.length; i++) {
//             if (amounts[i] > 0) {
//                 ProtegoYieldVault vault = ProtegoYieldVault(vaultAddresses[i]);
//                 uint256 sessionId = vault.withdrawForYield(amounts[i]);
//                 sessionIds[i] = sessionId;
                
//                 // Track global deployment
//                 goatDeploymentByVault[vaultAddresses[i]] = goatDeploymentByVault[vaultAddresses[i]].add(amounts[i]);
//                 totalGoatDeployment = totalGoatDeployment.add(amounts[i]);
//             }
//         }
        
//         return sessionIds;
//     }
    
//     /**
//      * @dev GOAT function to execute batch yield return across multiple vaults
//      */
//     function goatBatchReturnYield(
//         address[] memory vaultAddresses,
//         uint256[] memory sessionIds,
//         uint256[] memory totalAmounts
//     ) external onlyRole(GOAT_EXECUTOR_ROLE) {
//         require(
//             vaultAddresses.length == sessionIds.length && 
//             sessionIds.length == totalAmounts.length, 
//             "Array length mismatch"
//         );
        
//         uint256 totalYieldReturned = 0;
        
//         for (uint256 i = 0; i < vaultAddresses.length; i++) {
//             if (totalAmounts[i] > 0) {
//                 ProtegoYieldVault vault = ProtegoYieldVault(vaultAddresses[i]);
                
//                 // Get session details to calculate yield
//                 ProtegoYieldVault.YieldSession memory session = vault.getYieldSession(sessionIds[i]);
                
//                 // Approve vault to take the return amount
//                 require(
//                     paymentToken.approve(vaultAddresses[i], totalAmounts[i]),
//                     "Approval failed"
//                 );
                
//                 vault.depositYieldReturn(sessionIds[i], totalAmounts[i]);
                
//                 // Update global tracking
//                 goatDeploymentByVault[vaultAddresses[i]] = goatDeploymentByVault[vaultAddresses[i]].sub(session.deployedAmount);
//                 totalGoatDeployment = totalGoatDeployment.sub(session.deployedAmount);
                
//                 // Track yield generated
//                 uint256 yieldGenerated = totalAmounts[i].sub(session.deployedAmount);
//                 totalYieldReturned = totalYieldReturned.add(yieldGenerated);
//             }
//         }
        
//         totalYieldDistributed = totalYieldDistributed.add(totalYieldReturned);
        
//         emit PlatformYieldGenerated(totalYieldReturned, vaultAddresses.length, block.timestamp);
//     }
    
//     /**
//      * @dev Global emergency function to trigger emergency withdrawal across all vaults
//      */
//     function globalEmergencyWithdraw() external onlyRole(EMERGENCY_ROLE) returns (uint256 totalEmergencyFunds) {
//         totalEmergencyFunds = 0;
        
//         for (uint256 i = 0; i < allVaults.length; i++) {
//             ProtegoYieldVault vault = ProtegoYieldVault(allVaults[i]);
//             uint256 deployedFunds = vault.emergencyWithdrawDeployedFunds();
//             totalEmergencyFunds = totalEmergencyFunds.add(deployedFunds);
//         }
        
//         // Reset global deployment tracking
//         totalGoatDeployment = 0;
//         for (uint256 i = 0; i < allVaults.length; i++) {
//             goatDeploymentByVault[allVaults[i]] = 0;
//         }
        
//         emit GlobalEmergencyTriggered(msg.sender, totalEmergencyFunds, allVaults.length, block.timestamp);
        
//         return totalEmergencyFunds;
//     }
    
//     /**
//      * @dev GOAT function to return emergency funds across multiple vaults
//      */
//     function goatEmergencyReturn(
//         address[] memory vaultAddresses,
//         uint256[] memory amounts
//     ) external onlyRole(EMERGENCY_ROLE) {
//         require(vaultAddresses.length == amounts.length, "Array length mismatch");
        
//         for (uint256 i = 0; i < vaultAddresses.length; i++) {
//             if (amounts[i] > 0) {
//                 ProtegoYieldVault vault = ProtegoYieldVault(vaultAddresses[i]);
                
//                 // Approve vault to take the emergency return amount
//                 require(
//                     paymentToken.approve(vaultAddresses[i], amounts[i]),
//                     "Emergency approval failed"
//                 );
                
//                 vault.emergencyDepositReturn(amounts[i]);
//             }
//         }
//     }
    
//     /**
//      * @dev Resume operations across all vaults after emergency
//      */
//     function globalResumeOperations() external onlyRole(EMERGENCY_ROLE) {
//         for (uint256 i = 0; i < allVaults.length; i++) {
//             ProtegoYieldVault vault = ProtegoYieldVault(allVaults[i]);
//             vault.resumeOperations();
//         }
//     }
    
//     // =================================================================================
//     // ENHANCED VAULT CREATION WITH GOAT INTEGRATION
//     // =================================================================================
    
//     /**
//      * @dev Creates a new invoice and associated ERC-4626 vault with GOAT integration
//      */
//     function createInvoiceAndVault(
//         address debtor,
//         uint256 faceValue,
//         uint256 discountRate,
//         uint256 maturityDays,
//         uint256 fundingDeadlineDays,
//         string memory metadataURI,
//         string memory vaultName,
//         string memory vaultSymbol
//     ) external returns (uint256 invoiceTokenId, address vaultAddress) {
//         require(debtor != address(0), "Invalid debtor");
//         require(faceValue > 0, "Face value must be positive");
//         require(discountRate <= 2000, "Discount too high"); // Max 20%
        
//         // Calculate funding target based on discount rate
//         uint256 fundingTarget = faceValue.mul(10000 - discountRate).div(10000);
//         uint256 fundingDeadline = block.timestamp + (fundingDeadlineDays * 1 days);
        
//         // Deploy ERC-4626 vault
//         ProtegoYieldVault vault = new ProtegoYieldVault(
//             address(paymentToken),
//             address(invoiceNFT),
//             0, // Temporary, will be updated
//             fundingTarget,
//             fundingDeadline,
//             vaultName,
//             vaultSymbol
//         );
        
//         vaultAddress = address(vault);
        
//         // Create invoice NFT
//         invoiceTokenId = invoiceNFT.createInvoice(
//             msg.sender,
//             debtor,
//             faceValue,
//             discountRate,
//             maturityDays,
//             vaultAddress,
//             metadataURI
//         );
        
//         // Record vault
//         invoiceVaults[invoiceTokenId] = vaultAddress;
//         allVaults.push(vaultAddress);
        
//         // Transfer vault ownership to invoice issuer
//         vault.transferOwnership(msg.sender);
        
//         // Grant GOAT agent necessary roles if set
//         if (goatAgent != address(0)) {
//             vault.grantRole(vault.STRATEGY_EXECUTOR_ROLE(), goatAgent);
//             vault.grantRole(vault.YIELD_MANAGER_ROLE(), goatAgent);
//             vault.grantRole(vault.EMERGENCY_ROLE(), goatAgent);
//         }
        
//         emit VaultCreated(invoiceTokenId, vaultAddress, msg.sender, fundingTarget);
        
//         return (invoiceTokenId, vaultAddress);
//     }
    
//     // =================================================================================
//     // EXISTING FUNCTIONS (MAINTAINED FOR COMPATIBILITY)
//     // =================================================================================
    
//     /**
//      * @dev Batch yield generation across multiple vaults
//      */
//     function batchGenerateYield(
//         address[] memory vaultAddresses,
//         uint256[] memory yieldAmounts
//     ) external onlyRole(YIELD_MANAGER_ROLE) {
//         require(vaultAddresses.length == yieldAmounts.length, "Array length mismatch");
        
//         uint256 totalYield = 0;
        
//         for (uint256 i = 0; i < vaultAddresses.length; i++) {
//             if (yieldAmounts[i] > 0) {
//                 // Transfer yield to this contract first
//                 require(
//                     paymentToken.transferFrom(msg.sender, address(this), yieldAmounts[i]),
//                     "Yield transfer failed"
//                 );
                
//                 // Approve vault to spend the yield
//                 require(
//                     paymentToken.approve(vaultAddresses[i], yieldAmounts[i]),
//                     "Yield approval failed"
//                 );
                
//                 // Generate yield in the vault
//                 ProtegoYieldVault(vaultAddresses[i]).generateYield(yieldAmounts[i]);
//                 totalYield = totalYield.add(yieldAmounts[i]);
//             }
//         }
        
//         totalYieldDistributed = totalYieldDistributed.add(totalYield);
        
//         emit PlatformYieldGenerated(totalYield, vaultAddresses.length, block.timestamp);
//     }
    
//     /**
//      * @dev Creates a multi-invoice note type from existing invoices
//      */
//     function createMultiInvoiceNote(
//         string memory name,
//         uint256[] memory invoiceTokenIds,
//         uint256 minimumPurchase,
//         uint256 pricePerUnit
//     ) external onlyOwner returns (uint256) {
//         return multiInvoiceNotes.createNoteType(
//             name,
//             invoiceTokenIds,
//             minimumPurchase,
//             pricePerUnit
//         );
//     }
    
//     /**
//      * @dev Returns platform statistics including GOAT deployment metrics
//      */
//     function getPlatformStats() external view returns (
//         uint256 totalInvoices,
//         uint256 totalVaults,
//         uint256 totalValueLocked_,
//         uint256 totalYieldDistributed_,
//         uint256 totalGoatDeployment_,
//         address goatAgent_
//     ) {
//         totalInvoices = invoiceNFT.totalSupply();
//         totalVaults = allVaults.length;
//         totalValueLocked_ = totalValueLocked;
//         totalYieldDistributed_ = totalYieldDistributed;
//         totalGoatDeployment_ = totalGoatDeployment;
//         goatAgent_ = goatAgent;
//     }
    
//     /**
//      * @dev Get comprehensive GOAT monitoring data
//      */
//     function getGoatMonitoringData() external view returns (
//         address[] memory vaultAddresses,
//         uint256[] memory vaultTotalAssets,
//         uint256[] memory vaultDeployedFunds,
//         uint256[] memory vaultAvailableForDeployment,
//         bool[] memory vaultEmergencyStatus,
//         uint256 globalDeploymentTotal
//     ) {
//         uint256 vaultCount = allVaults.length;
        
//         vaultAddresses = new address[](vaultCount);
//         vaultTotalAssets = new uint256[](vaultCount);
//         vaultDeployedFunds = new uint256[](vaultCount);
//         vaultAvailableForDeployment = new uint256[](vaultCount);
//         vaultEmergencyStatus = new bool[](vaultCount);
        
//         for (uint256 i = 0; i < vaultCount; i++) {
//             ProtegoYieldVault vault = ProtegoYieldVault(allVaults[i]);
            
//             vaultAddresses[i] = allVaults[i];
//             vaultTotalAssets[i] = vault.totalAssets();
//             vaultDeployedFunds[i] = vault.deployedFunds();
//             vaultAvailableForDeployment[i] = vault.getAvailableForDeployment();
            
//             (, , , , bool isPaused) = vault.getVaultHealthMetrics();
//             vaultEmergencyStatus[i] = isPaused;
//         }
        
//         globalDeploymentTotal = totalGoatDeployment;
        
//         return (
//             vaultAddresses,
//             vaultTotalAssets,
//             vaultDeployedFunds,
//             vaultAvailableForDeployment,
//             vaultEmergencyStatus,
//             globalDeploymentTotal
//         );
//     }
    
//     /**
//      * @dev Returns vault address for an invoice
//      */
//     function getInvoiceVault(uint256 invoiceTokenId) external view returns (address) {
//         return invoiceVaults[invoiceTokenId];
//     }
    
//     /**
//      * @dev Returns all vault addresses
//      */
//     function getAllVaults() external view returns (address[] memory) {
//         return allVaults;
//     }
    
//     /**
//      * @dev Updates treasury address
//      */
//     function setTreasury(address newTreasury) external onlyOwner {
//         require(newTreasury != address(0), "Invalid treasury");
//         treasury = newTreasury;
//     }
    
// }