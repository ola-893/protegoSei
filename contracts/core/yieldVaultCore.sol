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
import "../protegoInvoiceNFT.sol";

/**
 * @title ProtegoYieldVaultCore
 * @dev Core vault functionality - Split from full implementation
 */
contract ProtegoYieldVaultCore is ERC20, IERC4626, Ownable, ReentrancyGuard, AccessControl {
    using SafeMath for uint256;
    using Math for uint256;
    
    // Role definitions
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant STRATEGY_EXECUTOR_ROLE = keccak256("STRATEGY_EXECUTOR_ROLE");
    
    IERC20 private immutable _asset;
    ProtegoInvoiceNFT public immutable invoiceNFT;
    uint256 public immutable invoiceTokenId;
    
    uint256 public platformFeeBps = 200;
    uint256 public minimumDeposit = 100 * 10**6;
    uint256 public maximumDeposit = 100000 * 10**6;
    uint256 public fundingDeadline;
    uint256 public fundingTarget;
    
    bool public isActive = true;
    bool public emergencyPaused = false;
    
    uint256 public totalYieldGenerated;
    uint256 public deployedFunds;
    uint256 public maxDeploymentPercentage = 8000;
    uint256 public reservedFunds;
    
    mapping(address => uint256) public userDeposits;
    address[] public depositors;
    
    // Yield session tracking
    struct YieldSession {
        uint256 deployedAmount;
        uint256 deploymentTime;
        bool isActive;
        address executor;
    }
    
    mapping(uint256 => YieldSession) public yieldSessions;
    uint256 public currentSessionId;
    
    event YieldGenerated(uint256 amount, uint256 timestamp);
    event FundingCompleted(uint256 totalAmount, uint256 investorCount);
    event FundsDeployedForYield(uint256 indexed sessionId, uint256 amount, address indexed executor, uint256 timestamp);
    event YieldReturned(uint256 indexed sessionId, uint256 principalReturned, uint256 yieldGenerated, uint256 timestamp);
    event EmergencyWithdrawal(uint256 amount, address indexed executor, uint256 timestamp);
    
    constructor(
        address asset_,
        address invoiceNFT_,
        uint256 invoiceTokenId_,
        uint256 fundingTarget_,
        uint256 fundingDeadline_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        require(asset_ != address(0), "Invalid asset");
        require(invoiceNFT_ != address(0), "Invalid invoice NFT");
        require(fundingTarget_ > 0, "Invalid funding target");
        require(fundingDeadline_ > block.timestamp, "Invalid deadline");
        
        _asset = IERC20(asset_);
        invoiceNFT = ProtegoInvoiceNFT(invoiceNFT_);
        invoiceTokenId = invoiceTokenId_;
        fundingTarget = fundingTarget_;
        fundingDeadline = fundingDeadline_;
        currentSessionId = 0;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(YIELD_MANAGER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(STRATEGY_EXECUTOR_ROLE, msg.sender);
    }
    
    // ERC-4626 Implementation
    function asset() public view virtual override returns (address) {
        return address(_asset);
    }
    
    function totalAssets() public view virtual override returns (uint256) {
        return _asset.balanceOf(address(this)).add(deployedFunds);
    }
    
    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }
    
    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }
    
    function maxDeposit(address) public view virtual override returns (uint256) {
        if (emergencyPaused) return 0;
        return isActive && block.timestamp < fundingDeadline ? maximumDeposit : 0;
    }
    
    function maxMint(address) public view virtual override returns (uint256) {
        if (emergencyPaused) return 0;
        return isActive && block.timestamp < fundingDeadline ? convertToShares(maximumDeposit) : 0;
    }
    
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        if (emergencyPaused) return 0;
        uint256 availableInVault = _asset.balanceOf(address(this));
        uint256 userAssets = convertToAssets(balanceOf(owner));
        return Math.min(availableInVault, userAssets);
    }
    
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        if (emergencyPaused) return 0;
        uint256 availableInVault = _asset.balanceOf(address(this));
        uint256 userShares = balanceOf(owner);
        uint256 maxRedeemableByAssets = convertToShares(availableInVault);
        return Math.min(userShares, maxRedeemableByAssets);
    }
    
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }
    
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Up);
    }
    
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Up);
    }
    
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }
    
    function deposit(uint256 assets, address receiver) public virtual override nonReentrant returns (uint256) {
        require(!emergencyPaused, "Emergency paused");
        require(isActive, "Vault not active");
        require(block.timestamp < fundingDeadline, "Funding period ended");
        require(assets >= minimumDeposit, "Below minimum deposit");
        require(assets <= maximumDeposit, "Above maximum deposit");
        require(totalAssets().add(assets) <= fundingTarget, "Would exceed funding target");
        
        uint256 shares = previewDeposit(assets);
        _deposit(msg.sender, receiver, assets, shares);
        
        if (userDeposits[receiver] == 0) {
            depositors.push(receiver);
        }
        userDeposits[receiver] = userDeposits[receiver].add(assets);
        
        if (totalAssets() >= fundingTarget) {
            _completeFunding();
        }
        
        return shares;
    }
    
    function mint(uint256 shares, address receiver) public virtual override nonReentrant returns (uint256) {
        require(!emergencyPaused, "Emergency paused");
        require(isActive, "Vault not active");
        require(block.timestamp < fundingDeadline, "Funding period ended");
        
        uint256 assets = previewMint(shares);
        require(assets >= minimumDeposit, "Below minimum deposit");
        require(totalAssets().add(assets) <= fundingTarget, "Would exceed funding target");
        
        _deposit(msg.sender, receiver, assets, shares);
        
        if (userDeposits[receiver] == 0) {
            depositors.push(receiver);
        }
        userDeposits[receiver] = userDeposits[receiver].add(assets);
        
        if (totalAssets() >= fundingTarget) {
            _completeFunding();
        }
        
        return assets;
    }
    
    function withdraw(uint256 assets, address receiver, address owner) public virtual override nonReentrant returns (uint256) {
        require(!emergencyPaused, "Emergency paused");
        require(assets <= maxWithdraw(owner), "Withdraw more than max");
        
        uint256 shares = previewWithdraw(assets);
        _withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }
    
    function redeem(uint256 shares, address receiver, address owner) public virtual override nonReentrant returns (uint256) {
        require(!emergencyPaused, "Emergency paused");
        require(shares <= maxRedeem(owner), "Redeem more than max");
        
        uint256 assets = previewRedeem(shares);
        _withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }
    
    // Internal functions
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        uint256 supply = totalSupply();
        return (assets == 0 || supply == 0) ? assets : Math.mulDiv(assets, supply, totalAssets(), rounding);
    }
    
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        uint256 supply = totalSupply();
        return (supply == 0) ? shares : Math.mulDiv(shares, totalAssets(), supply, rounding);
    }
    
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual {
        require(_asset.transferFrom(caller, address(this), assets), "Transfer failed");
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }
    
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal virtual {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        
        _burn(owner, shares);
        require(_asset.transfer(receiver, assets), "Transfer failed");
        emit Withdraw(caller, receiver, owner, assets, shares);
    }
    
    function _completeFunding() internal {
        invoiceNFT.updateInvoiceStatus(invoiceTokenId, ProtegoInvoiceNFT.InvoiceStatus.Funded);
        emit FundingCompleted(totalAssets(), depositors.length);
    }
    
    function getDepositorCount() external view returns (uint256) {
        return depositors.length;
    }
    
    function getDepositors() external view returns (address[] memory) {
        return depositors;
    }
}