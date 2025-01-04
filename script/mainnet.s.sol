// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PNPFactory} from "../src/pnpFactory.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {PriceModule} from "../src/PriceModule.sol";
import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";

contract MainnetScript is Script {
    function setUp() public {}

    function run() public {
        // Initialize deployer
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerKey);
        console2.log("Deployer address:", deployerAddr);

        vm.startBroadcast(deployerKey);

        // Deploy PNPFactory
        PNPFactory factory = new PNPFactory("pnpFactory");
        console2.log("PNPFactory deployed at:", address(factory));

        // Deploy PriceModule
        PriceModule priceModule = new PriceModule();
        console2.log("PriceModule deployed at:", address(priceModule));

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("PNPFactory:", address(factory));
        console2.log("PriceModule:", address(priceModule));
        console2.log("========================\n");
    }
}
