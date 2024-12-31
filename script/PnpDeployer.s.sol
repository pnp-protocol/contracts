// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PNPFactory} from "../src/pnpFactory.sol";
import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";

contract PnpDeployer is Script {
    function setUp() public {}

    function run() public {
        // Retrieve the private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deployer private key:", deployerPrivateKey);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the main contract
        // Replace this URI with your actual metadata URI
        PNPFactory pnpFactory = new PNPFactory("pnp-protocol-V.1.0.0");
        
        vm.stopBroadcast();

        // Log the deployed address
        console2.log("PNPFactory deployed at:", address(pnpFactory));
    }
}
