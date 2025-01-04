// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ██████╗░███╗░░██╗██████╗░  ██████╗░██████╗░░█████╗░████████╗░█████╗░░█████╗░░█████╗░██╗░░░░░
// ██╔══██╗████╗░██║██╔══██╗  ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██║░░░░░
// ██████╔╝██╔██╗██║██████╔╝  ██████╔╝██████╔╝██║░░██║░░░██║░░░██║░░██║██║░░╚═╝██║░░██║██║░░░░░
// ██╔═══╝░██║╚████║██╔═══╝░  ██╔═══╝░██╔══██╗██║░░██║░░░██║░░░██║░░██║██║░░██╗██║░░██║██║░░░░░
// ██║░░░░░██║░╚███║██║░░░░░  ██║░░░░░██║░░██║╚█████╔╝░░░██║░░░╚█████╔╝╚█████╔╝╚█████╔╝███████╗
// ╚═╝░░░░░╚═╝░░╚══╝╚═╝░░░░░  ╚═╝░░░░░╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░░╚════╝░░╚════╝░░╚════╝░╚══════╝

// ███╗░░░███╗░█████╗░██████╗░██╗░░░██╗██╗░░░░░███████╗  ░░░░░░  ░░███╗░░
// ████╗░████║██╔══██╗██╔══██╗██║░░░██║██║░░░░░██╔════╝  ░░░░░░  ░████║░░
// ██╔████╔██║██║░░██║██║░░██║██║░░░██║██║░░░░░█████╗░░  █████╗  ██╔██║░░
// ██║╚██╔╝██║██║░░██║██║░░██║██║░░░██║██║░░░░░██╔══╝░░  ╚════╝  ╚═╝██║░░
// ██║░╚═╝░██║╚█████╔╝██████╔╝╚██████╔╝███████╗███████╗  ░░░░░░  ███████╗
// ╚═╝░░░░░╚═╝░╚════╝░╚═════╝░░╚═════╝░╚══════╝╚══════╝  ░░░░░░  ╚══════╝

import {ITruthModule} from "./interfaces/ITruthModule.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// for Uniswap V3 Pools
// For market questions like:
// Will token [X] reach [Y] by the end of [Z]?

interface INANIPriceChecker {
    function checkPrice(address token) external returns(uint256,string memory);
}

contract PriceModule is ITruthModule {

    address constant private NANI_PriceChecker = 0x0000000000cDC1F8d393415455E382c30FBc0a84 ;
    // Function to fetch the price of a token from Uniswap V3 Pool
    // gives price of `token` in USDC through NANI'S ctc
    function getPriceInUSDC(address token) public  returns (uint256 price) {
        (price, ) = INANIPriceChecker(NANI_PriceChecker).checkPrice(token);         
    }

    // Function to settle the market
    function settle(bytes32 conditionId, address token, uint256 targetPrice) external  override returns (uint256) {
        // Get current price from the pool
        uint256 currentPrice = getPriceInUSDC(token);

        // Construct token IDs using keccak256
        uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));

        // Compare with target price from marketParams
        // marketParams[1] is the target price
        if (currentPrice >= targetPrice) {
            return yesTokenId; // YES token wins
        } else {
            return noTokenId; // NO token wins
        }
    }
}
