// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ██████╗░███╗░░██╗██████╗░  ██████╗░██████╗░░█████╗░████████╗░█████╗░░█████╗░░█████╗░██╗░░░░░
// ██╔══██╗████╗░██║██╔══██╗  ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██║░░░░░
// ██████╔╝██╔██╗██║██████╔╝  ██████╔╝██████╔╝██║░░██║░░░██║░░░██║░░██║██║░░╚═╝██║░░██║██║░░░░░
// ██╔═══╝░██║╚████║██╔═══╝░  ██╔═══╝░██╔══██╗██║░░██║░░░██║░░░██║░░██║██║░░██╗██║░░██║██║░░░░░
// ██║░░░░░██║░╚███║██║░░░░░  ██║░░░░░██║░░██║╚█████╔╝░░░██║░░░╚█████╔╝╚█████╔╝╚█████╔╝███████╗
// ╚═╝░░░░░╚═╝░░╚══╝╚═╝░░░░░  ╚═╝░░░░░╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░░╚════╝░░╚════╝░░╚════╝░╚══════╝

import {ITruthModule} from "./interfaces/ITruthModule.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// for uniswap V3 Pools
contract PriceModule is ITruthModule {

    // Function to set settling time for a market
    function setSettlingTime(bytes32 conditionId, uint256 _settlingTime) external {
        require(_settlingTime > block.timestamp, "Settling time must be in future");
    }

    // Function to fetch the price of a token from Uniswap V3 Pool
    // gives price of B in terms of A 
    function getPrice(IUniswapV3Pool pool) public view returns (uint256 price) {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        
        // Ensure the price is not zero
        require(sqrtPriceX96 > 0, "Invalid price");
        
        // For ETH/USDC pool:
        // 1. Square the sqrtPriceX96
        uint256 numerator = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        //console2.log("priceX192:", numerator);

        // 2. Convert from Q192 to Q96 format
        uint256 denominator = 1 << 192;

        //console2.log("basePrice:", denominator);

        // 3. Adjust for decimals (ETH/USDC)
        // USDC has 6 decimals, ETH has 18 decimals
        // We need to multiply by 10^6 (USDC decimals)
        price = (numerator * 10 ** 12) / denominator;

        //console2.log("Price:", price);

        // Basic sanity check
        //assertTrue(price > 0, "Price should be greater than 0");

        // // ETH price should be roughly between 1000-5000 USDC
        // assertTrue(price >= 1000e6 && price <= 5000e6, "Price outside reasonable range");
   
        return price;
    }

    // Function to settle the market
    function settle(
        bytes32 conditionId,
        uint256 targetPrice,
        address poolAddress
    ) external override returns (uint256 winningTokenId) {
        // Your existing settlement logic
        winningTokenId = uint256(
            keccak256(abi.encodePacked(conditionId, "YES"))
        );
    }
}
