// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ██████╗░███╗░░██╗██████╗░  ██████╗░██████╗░░█████╗░████████╗░█████╗░░█████╗░░█████╗░██╗░░░░░
// ██╔══██╗████╗░██║██╔══██╗  ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██║░░░░░
// ██████╔╝██╔██╗██║██████╔╝  ██████╔╝██████╔╝██║░░██║░░░██║░░░██║░░██║██║░░╚═╝██║░░██║██║░░░░░
// ██╔═══╝░██║╚████║██╔═══╝░  ██╔═══╝░██╔══██╗██║░░██║░░░██║░░░██║░░██║██║░░██╗██║░░██║██║░░��░░
// ██║░░░░░██║░╚███║██║░░░░░  ██║░░░░░██║░░██║╚█████╔╝░░░██║░░░╚█████╔╝╚█████╔╝╚█████╔╝███████╗
// ╚═╝░░░░░╚═╝░░╚══╝╚═╝░░░░░  ╚═╝░░░░░╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░░╚════╝░░╚════╝░░╚════╝░╚══════╝

import {ITruthModule} from "./interfaces/ITruthModule.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// for uniswap V3 Pools
contract PriceModule is ITruthModule {
    // Function to fetch the price of a token from Uniswap V3 Pool
    function getPrice(IUniswapV3Pool pool) public view returns (uint256 price) {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        
        // Ensure the price is not zero
        require(sqrtPriceX96 > 0, "Invalid price");
        
        // For ETH/USDC pool:
        // 1. Square the sqrtPriceX96
        uint256 priceX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        
        // 2. Convert from Q192 to Q96 format
        uint256 basePrice = priceX192 >> 96;
        
        // 3. Adjust for decimals (ETH/USDC)
        // USDC has 6 decimals, ETH has 18 decimals
        // We need to multiply by 10^6 (USDC decimals)
        price = basePrice * 1e6 / (1 << 96);
        
        return price;
    }

    // Function to settle the market
    function settle(
        bytes32 conditionId,
        uint256[] memory _marketParams
    ) external override returns (uint256 winningTokenId) {
        //  _winningTokenId = keccak256(abi.encodePacked(conditionId, _marketParams[0])); // Example logic
        winningTokenId = uint256(
            keccak256(abi.encodePacked(conditionId, "YES"))
        );
        winningTokenId = uint256(
            keccak256(abi.encodePacked(conditionId, "NO"))
        );
    }
}
