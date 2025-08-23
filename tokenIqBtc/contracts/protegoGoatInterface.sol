// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./core/yieldVaultCore.sol";
import "./masterVault.sol";
import "./protegoYieldStrategy.sol";


/**
 * @title ProtegoGoatInterface
 * @dev Interface contract for GOAT agent integration
 * Provides structured access to all GOAT-related functions across the ecosystem
 */
contract ProtegoGoatInterface is Ownable, AccessControl {
    using SafeMath for uint256;
    
    /// @dev Role definitions
    bytes32 public constant GOAT_AGENT_ROLE = keccak256("GOAT_AGENT_ROLE");
    
    /// @dev Core contract references
    ProtegoMasterVault public immutable masterVault;
    ProtegoYieldStrategy public immutable yieldStrategy;
    IERC20 public immutable paymentToken;
    
    /// @dev GOAT agent configuration
    struct GoatConfig {
        uint256 maxSingleDeployment;      // Maximum amount GOAT can deploy in one transaction
        uint256 maxTotalDeployment;       // Maximum total deployment across all vaults
        uint256 emergencyThreshold;       // Threshold for triggering emergency procedures
        uint256 yieldTargetBps;          // Target yield rate in basis points
        bool crossChainEnabled;          // Whether cross-chain operations are enabled
        bool emergencyMode;              // Whether emergency mode is active
    }
    
    GoatConfig public goatConfig;
    
    /// @dev Risk management parameters
    struct RiskParameters {
        uint256 maxVaultExposure;        // Maximum exposure per vault (percentage)
        uint256 maxProtocolExposure;     // Maximum exposure per external protocol
        uint256 liquidityReserve;        // Minimum liquidity reserve requirement
        uint256 riskScore;               // Current risk score (0-100)
        bool riskLimitsActive;           // Whether risk limits are enforced
    }
    
    RiskParameters public riskParameters;
    
    event GoatConfigUpdated(
        uint256 maxSingleDeployment,
        uint256 maxTotalDeployment,
        uint256 yieldTargetBps,
        bool crossChainEnabled
    );
    
    event RiskParametersUpdated(
        uint256 maxVaultExposure,
        uint256 maxProtocolExposure,
        uint256 liquidityReserve,
        uint256 riskScore
    );
    
    event GoatOperationExecuted(
        string operationType,
        uint256 totalAmount,
        uint256 vaultCount,
        bool success,
        uint256 timestamp
    );
    
    constructor(
        address masterVault_,
        address yieldStrategy_,
        address paymentToken_
    ) {
        require(masterVault_ != address(0), "Invalid master vault");
        require(yieldStrategy_ != address(0), "Invalid yield strategy");
        require(paymentToken_ != address(0), "Invalid payment token");
        
        masterVault = ProtegoMasterVault(masterVault_);
        yieldStrategy = ProtegoYieldStrategy(yieldStrategy_);
        paymentToken = IERC20(paymentToken_);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Initialize default configuration
        goatConfig = GoatConfig({
            maxSingleDeployment: 1000000 * 10**6, // 1M USDC
            maxTotalDeployment: 10000000 * 10**6,  // 10M USDC
            emergencyThreshold: 50, // 50% loss threshold
            yieldTargetBps: 1200,  // 12% annual target
            crossChainEnabled: true,
            emergencyMode: false
        });
        
        riskParameters = RiskParameters({
            maxVaultExposure: 8000,    // 80%
            maxProtocolExposure: 3000, // 30%
            liquidityReserve: 1000,    // 10%
            riskScore: 25,             // Low risk initially
            riskLimitsActive: true
        });
    }
    
    // =================================================================================
    // GOAT AGENT REGISTRATION AND MANAGEMENT
    // =================================================================================
    
    /**
     * @dev Register GOAT agent and set up permissions
     */
    function registerGoatAgent(address goatAgent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(goatAgent != address(0), "Invalid GOAT agent");
        
        _grantRole(GOAT_AGENT_ROLE, goatAgent);
        
        // Set GOAT agent in all related contracts
        masterVault.setGoatAgent(goatAgent);
        yieldStrategy.setGoatAgent(goatAgent);
    }
    
    /**
     * @dev Update GOAT configuration
     */
    function updateGoatConfig(
        uint256 maxSingleDeployment,
        uint256 maxTotalDeployment,
        uint256 emergencyThreshold,
        uint256 yieldTargetBps,
        bool crossChainEnabled
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        goatConfig.maxSingleDeployment = maxSingleDeployment;
        goatConfig.maxTotalDeployment = maxTotalDeployment;
        goatConfig.emergencyThreshold = emergencyThreshold;
        goatConfig.yieldTargetBps = yieldTargetBps;
        goatConfig.crossChainEnabled = crossChainEnabled;
        
        emit GoatConfigUpdated(
            maxSingleDeployment,
            maxTotalDeployment,
            yieldTargetBps,
            crossChainEnabled
        );
    }
    
    /**
     * @dev Update risk parameters
     */
    function updateRiskParameters(
        uint256 maxVaultExposure,
        uint256 maxProtocolExposure,
        uint256 liquidityReserve,
        uint256 riskScore,
        bool riskLimitsActive
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        riskParameters.maxVaultExposure = maxVaultExposure;
        riskParameters.maxProtocolExposure = maxProtocolExposure;
        riskParameters.liquidityReserve = liquidityReserve;
        riskParameters.riskScore = riskScore;
        riskParameters.riskLimitsActive = riskLimitsActive;
        
        emit RiskParametersUpdated(
            maxVaultExposure,
            maxProtocolExposure,
            liquidityReserve,
            riskScore
        );
    }
    
    // =================================================================================
    // GOAT EXECUTION FUNCTIONS
    // =================================================================================
    
    /**
     * @dev Execute optimized deployment strategy
     */
    function executeOptimizedDeployment() external onlyRole(GOAT_AGENT_ROLE) returns (
        uint256[] memory sessionIds,
        uint256 totalDeployed,
        bool success
    ) {
        require(!goatConfig.emergencyMode, "Emergency mode active");
        
        // Get optimal deployment strategy from master vault
        (
            address[] memory vaultAddresses,
            uint256[] memory availableAmounts,
            uint256[] memory recommendedDeployments,
            uint256 totalRecommended
        ) = masterVault.getOptimalDeploymentStrategy();
        
        // Apply risk limits
        if (riskParameters.riskLimitsActive) {
            totalRecommended = _applyRiskLimits(recommendedDeployments, totalRecommended);
        }
        
        // Check against GOAT configuration limits
        require(totalRecommended <= goatConfig.maxTotalDeployment, "Exceeds max total deployment");
        
        if (totalRecommended > 0) {
            // Execute batch withdrawal
            sessionIds = masterVault.goatBatchWithdrawForYield(vaultAddresses, recommendedDeployments);
            totalDeployed = totalRecommended;
            success = true;
            
            emit GoatOperationExecuted(
                "DEPLOYMENT",
                totalDeployed,
                vaultAddresses.length,
                success,
                block.timestamp
            );
        }
        
        return (sessionIds, totalDeployed, success);
    }
    
    /**
     * @dev Execute yield return across all active deployments
     */
    function executeYieldReturn(
        address[] memory vaultAddresses,
        uint256[] memory sessionIds,
        uint256[] memory totalAmounts
    ) external onlyRole(GOAT_AGENT_ROLE) {
        require(vaultAddresses.length == sessionIds.length, "Array length mismatch");
        require(sessionIds.length == totalAmounts.length, "Array length mismatch");
        
        uint256 totalReturned = 0;
        for (uint256 i = 0; i < totalAmounts.length; i++) {
            totalReturned = totalReturned.add(totalAmounts[i]);
        }
        
        // Ensure GOAT has sufficient balance
        require(paymentToken.balanceOf(msg.sender) >= totalReturned, "Insufficient GOAT balance");
        
        // Approve master vault to handle the return
        require(paymentToken.approve(address(masterVault), totalReturned), "Approval failed");
        
        // Execute batch return
        masterVault.goatBatchReturnYield(vaultAddresses, sessionIds, totalAmounts);
        
        emit GoatOperationExecuted(
            "YIELD_RETURN",
            totalReturned,
            vaultAddresses.length,
            true,
            block.timestamp
        );
    }
    
    /**
     * @dev Execute emergency withdrawal and return
     */
    function executeEmergencyProcedure() external onlyRole(GOAT_AGENT_ROLE) returns (uint256 totalEmergencyFunds) {
        goatConfig.emergencyMode = true;
        
        // Trigger global emergency withdrawal
        totalEmergencyFunds = masterVault.globalEmergencyWithdraw();
        
        emit GoatOperationExecuted(
            "EMERGENCY_WITHDRAWAL",
            totalEmergencyFunds,
            masterVault.getAllVaults().length,
            true,
            block.timestamp
        );
        
        return totalEmergencyFunds;
    }
    
    /**
     * @dev Return emergency funds and resume operations
     */
    function returnEmergencyFunds(
        address[] memory vaultAddresses,
        uint256[] memory amounts
    ) external onlyRole(GOAT_AGENT_ROLE) {
        uint256 totalReturned = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalReturned = totalReturned.add(amounts[i]);
        }
        
        // Ensure GOAT has sufficient balance
        require(paymentToken.balanceOf(msg.sender) >= totalReturned, "Insufficient GOAT balance");
        
        // Approve master vault to handle emergency return
        require(paymentToken.approve(address(masterVault), totalReturned), "Approval failed");
        
        // Execute emergency return
        masterVault.goatEmergencyReturn(vaultAddresses, amounts);
        
        // Resume operations
        masterVault.globalResumeOperations();
        goatConfig.emergencyMode = false;
        
        emit GoatOperationExecuted(
            "EMERGENCY_RETURN",
            totalReturned,
            vaultAddresses.length,
            true,
            block.timestamp
        );
    }
    
    // =================================================================================
    // MONITORING AND ANALYTICS FUNCTIONS
    // =================================================================================
    
    /**
     * @dev Get comprehensive system status for GOAT monitoring
     */
    function getSystemStatus() external view returns (
        bool systemHealthy,
        uint256 totalValueLocked,
        uint256 totalDeployed,
        uint256 deploymentRatio,
        uint256 currentRiskScore,
        bool emergencyActive
    ) {
        (
            ,
            ,
            uint256 tvl,
            ,
            uint256 goatDeployment,
        ) = masterVault.getPlatformStats();
        
        totalValueLocked = tvl;
        totalDeployed = goatDeployment;
        deploymentRatio = tvl > 0 ? goatDeployment.mul(10000).div(tvl) : 0;
        currentRiskScore = riskParameters.riskScore;
        emergencyActive = goatConfig.emergencyMode;
        
        // System is healthy if:
        // - Emergency mode is not active
        // - Risk score is below 70
        // - Deployment ratio is within limits
        systemHealthy = !emergencyActive && 
                       currentRiskScore < 70 && 
                       deploymentRatio <= riskParameters.maxVaultExposure;
    }
    
    /**
     * @dev Get optimal yield targets based on current conditions
     */
    function getOptimalYieldTargets() external view returns (
        uint256 currentYieldRate,
        uint256 targetYieldRate,
        uint256 riskAdjustedTarget,
        bool crossChainRecommended
    ) {
        currentYieldRate = yieldStrategy.calculateOptimalYieldRate();
        targetYieldRate = goatConfig.yieldTargetBps;
        
        // Adjust target based on risk score
        if (riskParameters.riskScore > 50) {
            riskAdjustedTarget = targetYieldRate.mul(100 - riskParameters.riskScore).div(100);
        } else {
            riskAdjustedTarget = targetYieldRate;
        }
        
        crossChainRecommended = goatConfig.crossChainEnabled && riskParameters.riskScore < 40;
        
        return (currentYieldRate, targetYieldRate, riskAdjustedTarget, crossChainRecommended);
    }
    
    // =================================================================================
    // INTERNAL HELPER FUNCTIONS
    // =================================================================================
    
    /**
     * @dev Apply risk limits to deployment amounts
     */
    function _applyRiskLimits(
        uint256[] memory deploymentAmounts,
        uint256 totalRecommended
    ) internal view returns (uint256 adjustedTotal) {
        adjustedTotal = 0;
        
        for (uint256 i = 0; i < deploymentAmounts.length; i++) {
            // Apply vault exposure limit
            uint256 maxAllowed = deploymentAmounts[i]
                .mul(riskParameters.maxVaultExposure)
                .div(10000);
            
            uint256 adjustedAmount = deploymentAmounts[i] > maxAllowed ? maxAllowed : deploymentAmounts[i];
            deploymentAmounts[i] = adjustedAmount;
            adjustedTotal = adjustedTotal.add(adjustedAmount);
        }
        
        // Apply total deployment limit
        if (adjustedTotal > goatConfig.maxTotalDeployment) {
            adjustedTotal = goatConfig.maxTotalDeployment;
        }
        
        return adjustedTotal;
    }
}