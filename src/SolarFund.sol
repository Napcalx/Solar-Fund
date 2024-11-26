// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol"; // Import the Strings library
import {IERC1155Receiver, IERC165} from "lib/openzeppelin-contracts/contracts//token/ERC1155/IERC1155Receiver.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {console} from "forge-std/Test.sol";

contract FundNFT is ERC1155, IERC1155Receiver, ReentrancyGuard {
    uint256 private currentTokenId; // Token ID counter
    address private owner; // Owner of the contract
    string private baseURI; // The base URI to the metadata folder (Pinata IPFS URL)

    struct Fund {
        uint256 tokenId; // Token ID associated with the fund
        uint256 totalSupply; // Total number of NFTs allocated for the fund
        uint256 availableSupply; // Number of NFTs still available for purchase
        string baseURI; // Base URI for this specific fund
        uint256 price; // Price of the NFT for each fund
        string name; // Name of the Fund Created
        string symbol; // Symbol of the Fund Created
    }

    mapping(uint256 => Fund) private funds; // Mapping of fund ID to Fund details
    mapping(uint256 => mapping(address => uint256[])) private tokenIds; // Mapping to track investors' token IDs by fund
    mapping(uint256 => uint256) private fundTokenIdCounter; // Tracks next token ID for each fund
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        private tokenBalances;
    uint256 private currentFundId; // Fund ID counter

    event FundCreated(
        uint256 indexed fundId,
        uint256 indexed tokenId,
        uint256 totalSupply,
        string baseURI,
        string name,
        string symbol
    );
    event NFTPurchased(
        address indexed buyer, // address of the buyer
        uint256 indexed fundId, // The FundId associated with the purchase
        uint256 indexed tokenId, // Unique tokenId of the NFT purchased
        uint256 amount, // Number of NFTs purchased
        uint256 timestamp // timeStamp of the NFT purchase
    );

    // Custom onlyOwner modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    constructor(string memory initialBaseURI) ERC1155(initialBaseURI) {
        owner = msg.sender; // Set the owner to the deployer's address
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector; // Required to indicate the receipt was successful
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector; // Required for batch transfers
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Function to create a new fund with a specified number of NFTs
    function createFund(
        uint256 nftSupply,
        string memory fundBaseURI,
        uint256 nft_Price,
        string memory fundName,
        string memory fundSymbol
    ) external onlyOwner returns (uint256) {
        require(nftSupply > 0, "NFT supply must be greater than zero");
        require(nft_Price > 0, "NFT price must be greater than 0");
        require(bytes(fundName).length > 0, "Fund Name must not be empty");
        require(bytes(fundSymbol).length > 0, "Fund symbol must not be empty");

        uint256 newTokenId = currentTokenId++; // Increment token ID for the new fund
        currentFundId += 1; // Increment fund ID

        // Create a new fund
        funds[currentFundId] = Fund({
            tokenId: currentTokenId,
            totalSupply: nftSupply,
            availableSupply: nftSupply,
            baseURI: fundBaseURI,
            price: nft_Price,
            name: fundName,
            symbol: fundSymbol
        });

        emit FundCreated(
            currentFundId,
            currentTokenId,
            nftSupply,
            fundBaseURI,
            fundName,
            fundSymbol
        );
        return currentFundId; // Return the new fund's ID
    }

    // Function to allow investors to swap 0.05 ETH for an NFT of a specific fund
    function buyNFT(
        uint256 fundId,
        uint256 quantity
    ) external payable nonReentrant {
        require(fundId > 0 && fundId <= currentFundId, "Invalid fund ID");
        require(quantity > 0, "Quantity must be greater than Zero");

        // Fetch the fund details
        Fund storage fund = funds[fundId];

        // Ensure the Fund has available NFTs
        require(
            fund.availableSupply >= quantity,
            "Not enough NFTs available for this fund"
        );

        // Calculate the total price for the Requested Quantity
        uint256 totalPrice = fund.price * quantity;

        // Ensure the Buyer has sent the correct amount of Ether
        require(
            msg.value >= totalPrice,
            "Insufficient Ether sent to purchase NFT"
        );

        fund.availableSupply -= quantity; // Decrease the available supply for the fund

        if (quantity == 1) {
            // Handle single Mint
            uint256 newTokenId = ++fundTokenIdCounter[fundId]; // Generate a new unique token Id for this nft
            _mint(msg.sender, newTokenId, 1, ""); // Mint a single NFT
            tokenIds[fundId][msg.sender].push(newTokenId); // Track the token Id for the buyer

            // Update the user's balance for this specific token ID
            tokenBalances[fundId][msg.sender][newTokenId] = 1; // Each NFT should have a balance of 1
        } else {
            //Handle Batch Mint
            uint256[] memory tokenIdsBatch = new uint256[](quantity);
            uint256[] memory quantitiesBatch = new uint256[](quantity);

            for (uint256 i = 0; i < quantity; i++) {
                uint256 newTokenId = ++fundTokenIdCounter[fundId]; // Generate a new unique Token ID for this nft
                tokenIdsBatch[i] = newTokenId; // Add to Batch
                quantitiesBatch[i] = 1; // Each NFT quantity is 1
                tokenIds[fundId][msg.sender].push(newTokenId); // Track the token ID for the buyers

                tokenBalances[fundId][msg.sender][newTokenId] = 1; // Each NFT should have a balance of 1
            }
            _mintBatch(msg.sender, tokenIdsBatch, quantitiesBatch, ""); // Mints all NFTs in one transaction
        }

        // Refund any excess Ether
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit NFTPurchased(
            msg.sender,
            fundId,
            fundTokenIdCounter[fundId],
            quantity,
            block.timestamp
        );
    }

    // Function to withdraw ETH collected from NFT sales
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available for withdrawal");

        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    // Function to set a new base URI for metadata (if needed)
    function setBaseURI(
        uint256 fundId,
        string memory newBaseURI
    ) external onlyOwner {
        require(fundId > 0 && fundId <= currentFundId, "Invalid fund ID");
        Fund storage fund = funds[fundId];
        fund.baseURI = newBaseURI;
        _setURI(newBaseURI);
    }

    // Function to construct the metadata URL based on the base URI and token ID
    function constructMetadataURL(
        uint256 fundId,
        uint256 tokenId
    ) public view returns (string memory) {
        require(fundId > 0 && fundId <= currentFundId, "Invalid fund ID");

        Fund storage fund = funds[fundId];

        require(
            tokenId == fund.tokenId,
            "Token ID does not match the fund's token ID"
        );

        // Ensure baseURI is set correctly
        require(bytes(fund.baseURI).length > 0, "Base URI is empty");

        // require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token ID");
        string memory slash = bytes(fund.baseURI)[
            bytes(fund.baseURI).length - 1
        ] == "/"
            ? ""
            : "/";
        return
            string(
                abi.encodePacked(
                    fund.baseURI,
                    slash,
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    // Getter function for currentTokenId
    function getCurrentTokenId() external view returns (uint256) {
        return currentTokenId;
    }

    // Getter function for currentFundId
    function getCurrentFundId() external view returns (uint256) {
        return currentFundId;
    }

    // Getter function for fund details
    function getFundDetails(
        uint256 fundId
    )
        external
        view
        returns (
            uint256 tokenId,
            uint256 totalSupply,
            uint256 availableSupply,
            string memory fundBaseURI,
            uint256 price,
            string memory name,
            string memory symbol
        )
    {
        require(fundId > 0 && fundId <= currentFundId, "Invalid fund ID");
        Fund storage fund = funds[fundId];
        return (
            fund.tokenId,
            fund.totalSupply,
            fund.availableSupply,
            fund.baseURI,
            fund.price,
            fund.name,
            fund.symbol
        );
    }

    function getMetadataURL(
        uint256 fundId,
        uint256 tokenId
    ) external view returns (string memory) {
        return constructMetadataURL(fundId, tokenId);
    }

    function getNftTokenIds(
        uint256 fundId,
        address buyer
    ) external view returns (uint256[] memory) {
        require(fundId > 0 && fundId <= currentFundId, "Invalid FundId");
        return (tokenIds[fundId][buyer]);
    }

    function getFundTokenIdCounter(
        uint256 fundId
    ) external view returns (uint256) {
        return fundTokenIdCounter[fundId];
    }

    function getTokenBalance(
        uint256 fundId,
        address user,
        uint256 tokenId
    ) external view returns (uint256) {
        return tokenBalances[fundId][user][tokenId];
    }
}
