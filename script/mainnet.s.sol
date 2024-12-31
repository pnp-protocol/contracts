// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PNPFactory} from "../src/pnpFactory.sol";
import {PriceModule} from "../src/PriceModule.sol";
import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";

contract MainnetScript is Script {
    // PNPFactory deployed address on mainnet
    address constant FACTORY_ADDRESS = 0x28c876BF878C3549adddAE5659Ff59B95Cb2C77f;

    function setUp() public {}

    function run() public {
        // Retrieve the private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Get reference to existing PNPFactory
        PNPFactory factory = PNPFactory(FACTORY_ADDRESS);

        // Deploy PriceModule
        PriceModule priceModule = new PriceModule();
        
        // // Set PriceModule in factory with moduleId 0
        // factory.setModuleAddress(0, address(priceModule));
        
        // vm.stopBroadcast();

        // // Log the deployed addresses
        console2.log("PriceModule deployed at:", address(priceModule));
        // console2.log("Module set in factory at:", FACTORY_ADDRESS);
    }
}