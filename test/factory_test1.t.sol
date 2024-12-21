// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {PNPFactory} from "../src/PNPFactory.sol";



contract FactoryTest is Test {

    PNPFactory public factory;

    function setUp() public {
        factory = new PNPFactory("bro");
    }

    function test_factoryDeployment() public {
        address addr = address(factory);
        assertNotEq(addr, address(0));
        console2.log("factory address: ");
        console2.log(address(addr));
    }

    function test_erc1155Compliance() public {
        // interface id of erc-1155 is 0xd9b67a26
        bool compliant = factory.supportsInterface(0xd9b67a26);
        assertEq(compliant, true);
        if(compliant) {
            console2.log("factory supports erc-1155");
        }
    }

    function test_marketCreation() public {
        
    }





}