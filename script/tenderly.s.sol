// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Market} from "../src/Tenderly.sol";
import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";

contract TenderlyScript is Script {
    function setUp() public {}

    function run() public {
        // Initialize deployer
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerKey);
        console2.log("Deployer address:", deployerAddr);

        vm.startBroadcast(deployerKey);

        // Deploy Market contract
        Market market = new Market();

        console2.log("Market contract deployed at:", address(market));

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("Market contract deployed at:", address(market));
        console2.log("========================\n");
    }
}
