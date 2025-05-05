// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Script} from "forge-std/Script.sol";
// import {PNPFactory} from "../src/pnpFactory.sol";
// import {IFactory} from "../src/interfaces/IFactory.sol";
// import {PriceModule} from "../src/PriceModule.sol";
// import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";


// contract SMAScript is Script {
//     function setUp() public {}

//     function run() public {
//         uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
//         address deployerAddr = vm.addr(deployerKey);
//         console2.log("Deployer address:", deployerAddr);

//         address factoryAddr = address(0xeD687976873D5194b5aE6315F2c54b32AfE2456d);
//         address priceModuleAddr = address(0x51242F79e60e380125DE602b17E792c8eE2bcAae);

//         console2.log("Factory address:", factoryAddr);
//         console2.log("PriceModule address:", priceModuleAddr);

//         vm.startBroadcast(deployerKey);

//         try IFactory(factoryAddr).setModuleAddress(0, priceModuleAddr) {
//             console2.log("Successfully set module address");
//         } catch Error(string memory reason) {
//             console2.log("Failed to set module address:", reason);
//         }

//         vm.stopBroadcast();
//     }
// }
