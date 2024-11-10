// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFundNFT {
    function createFund(uint256 nftSupply) external returns (uint256);

    function buyNFT(uint256 fundId) external payable;

    function withdrawFunds() external;

    function getAvailableSupply(uint256 fundId) external view returns (uint256);
}

contract InteractionContract {
    address public owner;
    IFundNFT public fundNFTContract;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor(address _fundNFTAddress) {
        owner = msg.sender;
        fundNFTContract = IFundNFT(_fundNFTAddress); // Set the address of the deployed FundNFT contract
    }

    // Function to interact with createFund function on FundNFT contract
    function createFundOnNFTContract(
        uint256 nftSupply
    ) external onlyOwner returns (uint256) {
        require(nftSupply > 0, "Supply must be greater than zero");
        uint256 fundId = fundNFTContract.createFund(nftSupply); // Call the createFund function from the FundNFT contract
        return fundId;
    }

    // Function to interact with the buyNFT function on FundNFT contract
    function buyNFTOnNFTContract(uint256 fundId) external payable {
        require(msg.value == 0.1 ether, "Need to send 0.1 ETH");
        fundNFTContract.buyNFT{value: msg.value}(fundId); // Call the buyNFT function
    }

    // Function to withdraw funds from the NFT contract
    function withdrawFromNFTContract() external onlyOwner {
        fundNFTContract.withdrawFunds(); // Call the withdrawFunds function
    }

    // Function to check available supply in a fund on the NFT contract
    function checkAvailableSupply(
        uint256 fundId
    ) external view returns (uint256) {
        return fundNFTContract.getAvailableSupply(fundId); // Call the getAvailableSupply function
    }

    // Fallback function to receive Ether
    receive() external payable {}

    // Function to withdraw any Ether from this interaction contract
    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
