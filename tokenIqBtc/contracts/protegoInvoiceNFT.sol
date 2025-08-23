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

/**
 * @title ProtegoInvoiceNFT
 * @dev ERC-721 contract for unique invoice tokens
 * Each invoice is represented as a unique NFT with detailed metadata
 */
contract ProtegoInvoiceNFT is ERC721, Ownable {
    using SafeMath for uint256;
    
    /// @dev Counter for token IDs
    uint256 private _tokenCounter;
    
    /// @dev Invoice status enumeration
    enum InvoiceStatus {
        Created,    // Invoice created, awaiting funding
        Funded,     // Fully funded by investors
        Matured,    // Invoice reached maturity date
        Paid,       // Invoice paid by debtor
        Defaulted   // Invoice defaulted (past due)
    }
    
    /// @dev Core invoice data structure
    struct Invoice {
        uint256 tokenId;           // NFT token ID
        address issuer;            // Company issuing the invoice
        address debtor;            // Company that owes payment
        uint256 faceValue;         // Original invoice amount
        uint256 discountRate;      // Discount rate in basis points (e.g., 500 = 5%)
        uint256 maturityDate;      // When payment is due
        uint256 createdAt;         // Block timestamp of creation
        InvoiceStatus status;      // Current status
        address vaultAddress;      // Associated ERC-4626 vault
        string metadataURI;        // IPFS metadata URI
    }
    
    /// @dev Mapping from token ID to invoice data
    mapping(uint256 => Invoice) public invoices;
    
    /// @dev Mapping from issuer to their invoice token IDs
    mapping(address => uint256[]) public issuerInvoices;
    
    event InvoiceCreated(
        uint256 indexed tokenId,
        address indexed issuer,
        address indexed debtor,
        uint256 faceValue,
        uint256 discountRate,
        uint256 maturityDate,
        address vaultAddress
    );
    
    event InvoiceStatusUpdated(
        uint256 indexed tokenId,
        InvoiceStatus oldStatus,
        InvoiceStatus newStatus,
        uint256 timestamp
    );
    
    constructor() ERC721("Protego.ai Invoice NFT", "PINV") {
        _tokenCounter = 0;
    }
    
    /**
     * @dev Creates a new invoice NFT
     */
    function createInvoice(
        address issuer,
        address debtor,
        uint256 faceValue,
        uint256 discountRate,
        uint256 maturityDays,
        address vaultAddress,
        string memory metadataURI
    ) external returns (uint256) {
        require(issuer != address(0), "Invalid issuer");
        require(debtor != address(0), "Invalid debtor");
        require(faceValue > 0, "Face value must be positive");
        require(discountRate <= 2000, "Discount rate too high"); // Max 20%
        require(maturityDays > 0 && maturityDays <= 365, "Invalid maturity");
        require(vaultAddress != address(0), "Invalid vault address");
        
        _tokenCounter++;
        uint256 tokenId = _tokenCounter;
        
        uint256 maturityDate = block.timestamp + (maturityDays * 1 days);
        
        // Create invoice record
        invoices[tokenId] = Invoice({
            tokenId: tokenId,
            issuer: issuer,
            debtor: debtor,
            faceValue: faceValue,
            discountRate: discountRate,
            maturityDate: maturityDate,
            createdAt: block.timestamp,
            status: InvoiceStatus.Created,
            vaultAddress: vaultAddress,
            metadataURI: metadataURI
        });
        
        // Track issuer's invoices
        issuerInvoices[issuer].push(tokenId);
        
        // Mint NFT directly to issuer
        _safeMint(issuer, tokenId);
        
        emit InvoiceCreated(
            tokenId,
            issuer,
            debtor,
            faceValue,
            discountRate,
            maturityDate,
            vaultAddress
        );
        
        return tokenId;
    }
    
    /**
     * @dev Updates invoice status (restricted to vault or owner)
     */
    function updateInvoiceStatus(uint256 tokenId, InvoiceStatus newStatus) external {
        require(_exists(tokenId), "Invoice does not exist");
        
        Invoice storage invoice = invoices[tokenId];
        require(
            msg.sender == invoice.vaultAddress || 
            msg.sender == owner() || 
            msg.sender == invoice.issuer,
            "Unauthorized"
        );
        
        InvoiceStatus oldStatus = invoice.status;
        invoice.status = newStatus;
        
        emit InvoiceStatusUpdated(tokenId, oldStatus, newStatus, block.timestamp);
    }
    
    /**
     * @dev Returns invoice data
     */
    function getInvoice(uint256 tokenId) external view returns (Invoice memory) {
        require(_exists(tokenId), "Invoice does not exist");
        return invoices[tokenId];
    }
    
    /**
     * @dev Returns all invoice IDs for an issuer
     */
    function getIssuerInvoices(address issuer) external view returns (uint256[] memory) {
        return issuerInvoices[issuer];
    }
    
    /**
     * @dev Override tokenURI to use IPFS metadata
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        return invoices[tokenId].metadataURI;
    }
    
    /**
     * @dev Returns the total number of invoices created
     */
    function totalSupply() external view returns (uint256) {
        return _tokenCounter;
    }
}