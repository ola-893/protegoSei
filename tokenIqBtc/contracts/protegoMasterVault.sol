// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./protegoInvoiceNFT.sol";
import "./core/yieldVaultCore.sol";
import "./multiInvoiceNotes.sol";

/**
 * @title ProtegoMasterVault
 * @dev Simplified master vault with multi-invoice notes functionality
 */
contract ProtegoMasterVault is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeMath for uint256;
    
    IERC20 public immutable paymentToken;
    ProtegoInvoiceNFT public immutable invoiceNFT;
    ProtegoMultiInvoiceNotes public immutable multiInvoiceNotes; // Added state variable
    
    address public treasury;
    uint256 public platformFeeBps = 200;
    address public goatAgent;
    
    mapping(uint256 => address) public invoiceVaults;
    address[] public allVaults;
    
    uint256 public totalValueLocked;
    uint256 public totalYieldDistributed;
    
    event VaultCreated(uint256 indexed invoiceTokenId, address indexed vaultAddress, address indexed issuer, uint256 fundingTarget);
    event GoatAgentUpdated(address indexed oldAgent, address indexed newAgent, uint256 timestamp);
    
    constructor(address paymentToken_, address treasury_) {
        require(paymentToken_ != address(0), "Invalid payment token");
        require(treasury_ != address(0), "Invalid treasury");
        
        paymentToken = IERC20(paymentToken_);
        treasury = treasury_;
        
        invoiceNFT = new ProtegoInvoiceNFT();
        // Deploy multi-invoice notes contract
        multiInvoiceNotes = new ProtegoMultiInvoiceNotes(paymentToken_, address(invoiceNFT));
    }
    
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    
    function setGoatAgent(address goatAgent_) external onlyOwner {
        require(goatAgent_ != address(0), "Invalid GOAT agent");
        
        address oldAgent = goatAgent;
        goatAgent = goatAgent_;
        
        emit GoatAgentUpdated(oldAgent, goatAgent_, block.timestamp);
    }
    
    function createInvoiceAndVault(
        address debtor,
        uint256 faceValue,
        uint256 discountRate,
        uint256 maturityDays,
        uint256 fundingDeadlineDays,
        string memory metadataURI,
        string memory vaultName,
        string memory vaultSymbol
    ) external returns (uint256 invoiceTokenId, address vaultAddress) {
        require(debtor != address(0), "Invalid debtor");
        require(faceValue > 0, "Face value must be positive");
        require(discountRate <= 2000, "Discount too high");
        
        uint256 fundingTarget = faceValue.mul(10000 - discountRate).div(10000);
        uint256 fundingDeadline = block.timestamp + (fundingDeadlineDays * 1 days);
        
         ProtegoYieldVaultCore vault = new ProtegoYieldVaultCore(
            address(paymentToken),
            address(invoiceNFT),
            0,
            fundingTarget,
            fundingDeadline,
            vaultName,
            vaultSymbol
        );
        
        vaultAddress = address(vault);
        
        invoiceTokenId = invoiceNFT.createInvoice(
            msg.sender,
            debtor,
            faceValue,
            discountRate,
            maturityDays,
            vaultAddress,
            metadataURI
        );
        
        invoiceVaults[invoiceTokenId] = vaultAddress;
        allVaults.push(vaultAddress);
        
        vault.transferOwnership(msg.sender);
        
        emit VaultCreated(invoiceTokenId, vaultAddress, msg.sender, fundingTarget);
        return (invoiceTokenId, vaultAddress);
    }

    /**
     * @dev Creates a multi-invoice note type from existing invoices
     */
    function createMultiInvoiceNote(
        string memory name,
        uint256[] memory invoiceTokenIds,
        uint256 minimumPurchase,
        uint256 pricePerUnit
    ) external onlyOwner returns (uint256) {
        return multiInvoiceNotes.createNoteType(
            name,
            invoiceTokenIds,
            minimumPurchase,
            pricePerUnit
        );
    }
    
    function getPlatformStats() external view returns (
        uint256 totalInvoices,
        uint256 totalVaults,
        uint256 totalValueLocked_,
        uint256 totalYieldDistributed_
    ) {
        totalInvoices = invoiceNFT.totalSupply();
        totalVaults = allVaults.length;
        totalValueLocked_ = totalValueLocked;
        totalYieldDistributed_ = totalYieldDistributed;
    }
    
    function getInvoiceVault(uint256 invoiceTokenId) external view returns (address) {
        return invoiceVaults[invoiceTokenId];
    }
    
    function getAllVaults() external view returns (address[] memory) {
        return allVaults;
    }
    
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = newTreasury;
    }
}