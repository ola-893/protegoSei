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
import "./protegoInvoiceNFT.sol";

/**
 * @title ProtegoMultiInvoiceNotes
 * @dev ERC-1155 contract for fractionalized multi-invoice investment products
 * Allows investors to buy into portfolios of multiple invoices
 */
contract ProtegoMultiInvoiceNotes is ERC1155, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    
    /// @dev Counter for note type IDs
    uint256 private _noteTypeCounter;
    
    /// @dev Note type structure
    struct NoteType {
        uint256 noteTypeId;        // Unique identifier
        string name;               // Note type name (e.g., "Q1 2024 Portfolio")
        uint256[] invoiceTokenIds; // Array of invoice NFT IDs in this portfolio
        uint256 totalValue;        // Combined value of all invoices
        uint256 minimumPurchase;   // Minimum amount to buy this note type
        uint256 pricePerUnit;      // Price per fraction in USDC
        bool isActive;             // Whether this note type is available
        uint256 createdAt;         // Creation timestamp
    }
    
    /// @dev Payment token for purchasing notes
    IERC20 public immutable paymentToken;
    
    /// @dev Reference to invoice NFT contract
    ProtegoInvoiceNFT public immutable invoiceNFT;
    
    /// @dev Mapping from note type ID to note data
    mapping(uint256 => NoteType) public noteTypes;
    
    /// @dev Mapping from note type ID to total supply
    mapping(uint256 => uint256) public noteTypeSupply;
    
    /// @dev Mapping from note type ID to user holdings for yield calculation
    mapping(uint256 => mapping(address => uint256)) public userHoldings;
    
    /// @dev Mapping from note type ID to total yield generated
    mapping(uint256 => uint256) public noteTypeYield;
    
    event NoteTypeCreated(
        uint256 indexed noteTypeId,
        string name,
        uint256[] invoiceTokenIds,
        uint256 totalValue,
        uint256 pricePerUnit
    );
    
    event NotePurchased(
        uint256 indexed noteTypeId,
        address indexed buyer,
        uint256 amount,
        uint256 cost
    );
    
    event YieldDistributedToNotes(
        uint256 indexed noteTypeId,
        uint256 yieldAmount,
        uint256 timestamp
    );
    
    constructor(
        address paymentToken_,
        address invoiceNFT_
    ) ERC1155("") {
        require(paymentToken_ != address(0), "Invalid payment token");
        require(invoiceNFT_ != address(0), "Invalid invoice NFT");
        
        paymentToken = IERC20(paymentToken_);
        invoiceNFT = ProtegoInvoiceNFT(invoiceNFT_);
        _noteTypeCounter = 0;
    }
    
    /**
     * @dev Creates a new multi-invoice note type
     */
    function createNoteType(
        string memory name,
        uint256[] memory invoiceTokenIds,
        uint256 minimumPurchase,
        uint256 pricePerUnit
    ) external onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(invoiceTokenIds.length > 0, "Must include invoices");
        require(pricePerUnit > 0, "Price must be positive");
        
        _noteTypeCounter++;
        uint256 noteTypeId = _noteTypeCounter;
        
        // Calculate total value of included invoices
        uint256 totalValue = 0;
        for (uint256 i = 0; i < invoiceTokenIds.length; i++) {
            ProtegoInvoiceNFT.Invoice memory invoice = invoiceNFT.getInvoice(invoiceTokenIds[i]);
            totalValue = totalValue.add(invoice.faceValue);
        }
        
        // Create note type
        noteTypes[noteTypeId] = NoteType({
            noteTypeId: noteTypeId,
            name: name,
            invoiceTokenIds: invoiceTokenIds,
            totalValue: totalValue,
            minimumPurchase: minimumPurchase,
            pricePerUnit: pricePerUnit,
            isActive: true,
            createdAt: block.timestamp
        });
        
        emit NoteTypeCreated(
            noteTypeId,
            name,
            invoiceTokenIds,
            totalValue,
            pricePerUnit
        );
        
        return noteTypeId;
    }
    
    /**
     * @dev Purchase multi-invoice notes
     */
    function purchaseNotes(
        uint256 noteTypeId,
        uint256 amount
    ) external nonReentrant {
        require(noteTypes[noteTypeId].isActive, "Note type not active");
        require(amount >= noteTypes[noteTypeId].minimumPurchase, "Below minimum purchase");
        
        uint256 cost = amount.mul(noteTypes[noteTypeId].pricePerUnit).div(1e18);
        
        // Transfer payment
        require(
            paymentToken.transferFrom(msg.sender, address(this), cost),
            "Payment transfer failed"
        );
        
        // Mint notes to buyer
        _mint(msg.sender, noteTypeId, amount, "");
        
        // Track holding for yield calculation
        if (userHoldings[noteTypeId][msg.sender] == 0) {
            // First purchase, no need to track separately as ERC1155 handles balances
        }
        userHoldings[noteTypeId][msg.sender] = userHoldings[noteTypeId][msg.sender].add(amount);
        noteTypeSupply[noteTypeId] = noteTypeSupply[noteTypeId].add(amount);
        
        emit NotePurchased(noteTypeId, msg.sender, amount, cost);
    }
    
    /**
     * @dev Distributes yield to note holders
     */
    function distributeYield(uint256 noteTypeId, uint256 yieldAmount) external onlyOwner {
        require(noteTypes[noteTypeId].isActive, "Note type not active");
        require(yieldAmount > 0, "Yield must be positive");
        
        // Transfer yield to contract
        require(
            paymentToken.transferFrom(msg.sender, address(this), yieldAmount),
            "Yield transfer failed"
        );
        
        noteTypeYield[noteTypeId] = noteTypeYield[noteTypeId].add(yieldAmount);
        
        emit YieldDistributedToNotes(noteTypeId, yieldAmount, block.timestamp);
    }
    
    /**
     * @dev Calculates claimable yield for a note holder
     */
    function claimableYield(uint256 noteTypeId, address holder) public view returns (uint256) {
        uint256 holderBalance = balanceOf(holder, noteTypeId);
        uint256 totalSupply = noteTypeSupply[noteTypeId];
        
        if (holderBalance == 0 || totalSupply == 0) return 0;
        
        return noteTypeYield[noteTypeId].mul(holderBalance).div(totalSupply);
    }
    
    /**
     * @dev Returns note type details
     */
    function getNoteType(uint256 noteTypeId) external view returns (NoteType memory) {
        return noteTypes[noteTypeId];
    }
    
    /**
     * @dev Returns invoice token IDs in a note type
     */
    function getNoteTypeInvoices(uint256 noteTypeId) external view returns (uint256[] memory) {
        return noteTypes[noteTypeId].invoiceTokenIds;
    }
}