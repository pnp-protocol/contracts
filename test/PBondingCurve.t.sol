// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";
import {PythagoreanBondingCurve} from "../src/libraries/PythagoreanBondingCurve.sol";

contract PBondingCurveTest is Test {

    function setUp() public {}

    // P.Bonding Curve 
    // r = c * sqrt(a^2 + b^2)
    // r = total reserve in collateral token 
    // a = total supply of YES tokens
    // b = total supply of NO tokens
    // c = fees constant  [ 1% == 100 bps for now ]

    function testGetTokensToMint() public {
        
    }
}