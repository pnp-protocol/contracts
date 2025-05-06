// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PNPFactory} from "../src/pnpFactory.sol";

contract DeployPNPFactoryScript is Script {
    function run() external {
        // Load the private key from the .env file
        string memory privateKey = vm.envString("PRIVATE_KEY");
        if (bytes(privateKey).length == 0) {
            revert("PRIVATE_KEY not set in .env file");
        }
        console.log("Private key loaded:", bytes(privateKey).length > 0);
        uint256 deployerPrivateKey = vm.parseUint(privateKey);

        // Start broadcasting transactions using the loaded private key
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the PNPFactory contract
        // Replace "YOUR_ERC1155_METADATA_URI" with your actual metadata URI
        PNPFactory pnpFactory = new PNPFactory("https://pnp.exchange/api/outcomeTokens/{id}.json");

        // Stop broadcasting
        vm.stopBroadcast();

        // Log the deployed contract address
        console.log("PNPFactory deployed to:", address(pnpFactory));
        console.log("Owner (deployer):", pnpFactory.owner());
    }
}
