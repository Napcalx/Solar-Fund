# FundNFT Smart Contract - README

This README provides step-by-step instructions on how to deploy, verify, and interact with the `FundNFT` contract. The contract is based on the ERC1155 token standard and allows users to create funds, buy NFTs, and manage metadata. 

This guide uses [Foundry](https://getfoundry.sh/), a fast and flexible Ethereum development tool.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Contract Overview](#contract-overview)
3. [Deploying the Contract](#deploying-the-contract)
4. [Verifying the Contract](#verifying-the-contract)
5. [Interacting with the Contract](#interacting-with-the-contract)
6. [Contract Functions](#contract-functions)
7. [Events](#events)
8. [Testing the Contract](#testing-the-contract)

---

## Prerequisites

Before deploying the contract, ensure you have the following setup:

- **Foundry**: Install Foundry by running:
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```
  
- **Metamask**: A wallet to interact with the Ethereum network.

- **Infura or Alchemy API Key**: For connecting to Ethereum networks like Rinkeby, Goerli, or Mainnet.

---

## Contract Overview

The `FundNFT` contract implements an ERC1155 token that allows the owner to create funds, mint NFTs for each fund, and let users purchase NFTs for 0.05 ETH. It also supports metadata management and withdrawals for the collected ETH.

### Key Features:
- **Create funds**: The owner can create a new fund and mint a set number of NFTs.
- **Buy NFTs**: Users can purchase NFTs for 0.05 ETH.
- **Metadata management**: Allows changing the metadata URI for each fund.
- **Withdraw funds**: The contract owner can withdraw collected funds (ETH).

---

## Deploying the Contract

### 1. Initialize a Foundry Project

If you haven't already initialized a Foundry project, do so by running:

```bash
forge init fund-nft
cd fund-nft
```

This will create a project structure with the necessary files.

### 2. Install Dependencies

Install the OpenZeppelin contracts and other dependencies:

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

### 3. Add the Contract

Create the contract in the `src` directory as `FundNFT.sol`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {IERC1155Receiver, IERC165} from "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

// Contract implementation goes here...
```

### 4. Create a Deployment Script

In the `script` directory, create a file called `DeployFundNFT.s.sol` with the following content:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FundNFT} from "../src/FundNFT.sol";
import {Script} from "forge-std/Script";

contract DeployFundNFT is Script {
    function run() public {
        vm.startBroadcast();

        string memory initialBaseURI = "https://mybaseuri.com/fund1/";
        FundNFT fundNFT = new FundNFT(initialBaseURI);
        
        console.log("FundNFT deployed to:", address(fundNFT));
        
        vm.stopBroadcast();
    }
}
```

### 5. Deploy the Contract

Use Foundry to deploy the contract. Run the following command:

```bash
forge script script/DeployFundNFT.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

Replace `<your_rpc_url>` with the URL from your Infura or Alchemy account, and `<your_private_key>` with your wallet’s private key.

---

## Verifying the Contract

### 1. Verify the Contract on Etherscan

Once the contract is deployed, you can verify it on Etherscan (or any other block explorer). You need to use the `forge-verify` plugin:

1. Install the `forge-verify` plugin:
   ```bash
   forge install foundry-rs/forge-verify
   ```

2. Add your Etherscan API key to `foundry.toml`:
   ```toml
   [profile]
   etherscan_api_key = "your_etherscan_api_key"
   ```

3. Verify the contract using the following command:
   ```bash
   forge verify-contract <contract_address> src/FundNFT.sol:<FundNFT> --etherscan-api-key <your_etherscan_api_key>
   ```

---

## Interacting with the Contract

### 1. Use the Foundry Console

You can interact with the deployed contract using the Foundry console. Start the console with:

```bash
forge console --rpc-url <your_rpc_url>
```

Once connected, you can interact with your contract like this:

```solidity
FundNFT fundNFT = FundNFT(<contract_address>);
```

### 2. Interacting with Functions

#### Create a Fund:
```solidity
fundNFT.createFund(1000, "https://mybaseuri.com/fund2/");
```

#### Buy an NFT:
```solidity
fundNFT.buyNFT(1, { value: 0.05 ether });
```

#### Withdraw Funds:
```solidity
fundNFT.withdrawFunds();
```

#### Set Base URI:
```solidity
fundNFT.setBaseURI(1, "https://newbaseuri.com/fund1/");
```

#### Get Fund Details:
```solidity
(uint256 tokenId, uint256 totalSupply, uint256 availableSupply, string memory baseURI) = fundNFT.getFundDetails(1);
```

---

## Contract Functions

### 1. `createFund(uint256 nftSupply, string memory fundBaseURI)`

- **Purpose**: Create a new fund with a specified number of NFTs and a base URI.
- **Permissions**: Only the owner can call this function.

### 2. `buyNFT(uint256 fundId)`

- **Purpose**: Allows users to buy an NFT from a fund by sending 0.05 ETH.
- **Permissions**: Public, anyone can call this function.

### 3. `withdrawFunds()`

- **Purpose**: Allows the owner to withdraw ETH collected from NFT sales.
- **Permissions**: Only the owner can call this function.

### 4. `setBaseURI(uint256 fundId, string memory newBaseURI)`

- **Purpose**: Set a new base URI for the fund's metadata.
- **Permissions**: Only the owner can call this function.

### 5. `constructMetadataURL(uint256 fundId, uint256 tokenId)`

- **Purpose**: Constructs the metadata URL based on the fund ID and token ID.
- **Permissions**: Public, anyone can call this function.

---

## Events

### 1. `FundCreated(uint256 fundId, uint256 tokenId, uint256 totalSupply, string baseURI)`
- **Emitted when**: A new fund is created.
  
### 2. `NFTPurchased(address buyer, uint256 fundId, uint256 tokenId, uint256 amount)`
- **Emitted when**: An NFT is purchased.

---

## Testing the Contract

You can write and run tests using Foundry.

### 1. Writing Tests

Create a test in the `test` directory, for example, `FundNFTTest.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FundNFT} from "../src/FundNFT.sol";
import {Test} from "forge-std/Test";

contract FundNFTTest is Test {
    FundNFT fundNFT;
    
    function setUp() public {
        fundNFT = new FundNFT("https://mybaseuri.com/");
    }

    function testCreateFund() public {
        uint256 fundId = fundNFT.createFund(1000, "https://mybaseuri.com/fund1/");
        assertEq(fundId, 1);
    }

    function testBuyNFT() public {
        fundNFT.createFund(1000, "https://mybaseuri.com/fund1/");
        fundNFT.buyNFT{value: 0.05 ether}(1);
    }

    function testWithdrawFunds() public {
        fundNFT.createFund(1000, "https://mybaseuri.com/fund1/");
        fundNFT.buyNFT{value: 0.05 ether}(1);
        fundNFT.withdrawFunds();
    }
}
```

### 2. Running Tests

To run tests, execute:

```bash
forge test
```

This will compile and run the tests defined in the `test` directory.

---

This concludes the README for deploying, verifying, and interacting with the `FundNFT` contract using Foundry.