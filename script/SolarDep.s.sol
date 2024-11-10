// SPDX-License-Identifier: MI

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {FundNFT} from "../src/SolarFund.sol";

contract DeployFundNFT is Script {
    function run() external {
        // Begin broadcasting transactions
        vm.startBroadcast();

        // Deploy the FundNFT contract with a base URI
        string memory baseURI = "ipfs://QmYourIpfsHash/";
        FundNFT fundNFT = new FundNFT(baseURI);

        // Output the contract address
        console.log("FundNFT contract deployed at:", address(fundNFT));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
