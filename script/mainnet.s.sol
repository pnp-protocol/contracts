// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PNPFactory} from "../src/pnpFactory.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {PriceModule} from "../src/PriceModule.sol";
import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";

contract MainnetScript is Script {
    // PNPFactory deployed address on mainnet
    address constant FACTORY_ADDRESS = 0x28c876BF878C3549adddAE5659Ff59B95Cb2C77f;

    function setUp() public {}

    function run() public {
    }
}