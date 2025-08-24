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


/**
 * @title ProtegoYieldVaultGoat
 * @dev GOAT-specific functions for the vault - Separate contract to reduce size
 */
contract ProtegoYieldVaultGoat is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    
    bytes32 public constant STRATEGY_EXECUTOR_ROLE = keccak256("STRATEGY_EXECUTOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    ProtegoYieldVaultCore public immutable vaultCore;
    IERC20 public immutable asset;
    
    struct YieldSession {
        uint256 deployedAmount;
        uint256 deploymentTime;
        bool isActive;
        address executor;
    }
    
    mapping(uint256 => YieldSession) public yieldSessions;
    uint256 public currentSessionId;
    uint256 public deployedFunds;
    uint256 public maxDeploymentPercentage = 8000;
    uint256 public reservedFunds;
    
    event FundsDeployedForYield(uint256 indexed sessionId, uint256 amount, address indexed executor, uint256 timestamp);
    event YieldReturned(uint256 indexed sessionId, uint256 principalReturned, uint256 yieldGenerated, uint256 timestamp);
    event EmergencyWithdrawal(uint256 amount, address indexed executor, uint256 timestamp);
    
    constructor(address vaultCore_, address asset_) {
        require(vaultCore_ != address(0), "Invalid vault core");
        require(asset_ != address(0), "Invalid asset");
        
        vaultCore = ProtegoYieldVaultCore(vaultCore_);
        asset = IERC20(asset_);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STRATEGY_EXECUTOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
    }
    
    function withdrawForYield(uint256 amount) external onlyRole(STRATEGY_EXECUTOR_ROLE) nonReentrant returns (uint256 sessionId) {
        require(amount > 0, "Amount must be positive");
        
        uint256 availableForDeployment = _calculateAvailableForDeployment();
        require(amount <= availableForDeployment, "Exceeds deployment limit");
        
        currentSessionId++;
        sessionId = currentSessionId;
        
        yieldSessions[sessionId] = YieldSession({
            deployedAmount: amount,
            deploymentTime: block.timestamp,
            isActive: true,
            executor: msg.sender
        });
        
        deployedFunds = deployedFunds.add(amount);
        require(asset.transfer(msg.sender, amount), "Transfer failed");
        
        emit FundsDeployedForYield(sessionId, amount, msg.sender, block.timestamp);
        return sessionId;
    }
    
    function depositYieldReturn(uint256 sessionId, uint256 totalAmount) external onlyRole(STRATEGY_EXECUTOR_ROLE) nonReentrant {
        require(yieldSessions[sessionId].isActive, "Session not active");
        require(yieldSessions[sessionId].executor == msg.sender, "Unauthorized for this session");
        require(totalAmount >= yieldSessions[sessionId].deployedAmount, "Cannot return less than principal");
        
        uint256 principal = yieldSessions[sessionId].deployedAmount;
        uint256 yieldGenerated = totalAmount.sub(principal);
        
        yieldSessions[sessionId].isActive = false;
        deployedFunds = deployedFunds.sub(principal);
        
        require(asset.transferFrom(msg.sender, address(this), totalAmount), "Transfer failed");
        
        emit YieldReturned(sessionId, principal, yieldGenerated, block.timestamp);
    }
    
    function emergencyWithdrawDeployedFunds() external onlyRole(EMERGENCY_ROLE) nonReentrant returns (uint256 totalWithdrawn) {
        totalWithdrawn = deployedFunds;
        
        for (uint256 i = 1; i <= currentSessionId; i++) {
            if (yieldSessions[i].isActive) {
                yieldSessions[i].isActive = false;
            }
        }
        
        deployedFunds = 0;
        emit EmergencyWithdrawal(totalWithdrawn, msg.sender, block.timestamp);
        return totalWithdrawn;
    }
    
    function _calculateAvailableForDeployment() internal view returns (uint256) {
        uint256 totalFunds = vaultCore.totalAssets();
        uint256 maxDeployable = totalFunds.mul(maxDeploymentPercentage).div(10000);
        uint256 alreadyDeployed = deployedFunds;
        uint256 reserved = reservedFunds;
        
        if (maxDeployable <= alreadyDeployed.add(reserved)) {
            return 0;
        }
        
        return maxDeployable.sub(alreadyDeployed).sub(reserved);
    }
    
    function getAvailableForDeployment() external view returns (uint256) {
        return _calculateAvailableForDeployment();
    }
    
    function getYieldSession(uint256 sessionId) external view returns (YieldSession memory) {
        return yieldSessions[sessionId];
    }
}