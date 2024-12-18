// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {PriceModule} from "../src/PriceModule.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract PriceModuleTest is Test {
    PriceModule public priceModule;

    uint256 mainnetFork;
    uint256 price;

    // USDC/ETH pool on Base
    address constant USDC_ETH_POOL = 0xd0b53D9277642d899DF5C87A3966A349A798F224;

    function setUp() public {
        // Fork Base network at a specific block
        mainnetFork = vm.createFork(
            "https://base-mainnet.g.alchemy.com/v2/44VAXHBaUMjTDOeGL0wSxN7MqjM5jSP1",
            5_000_000 // Add specific block number here
        );
    }

    function testGetUniswapV3Price() public {
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);
        priceModule = new PriceModule();

        // Verify pool exists
        IUniswapV3Pool pool = IUniswapV3Pool(USDC_ETH_POOL);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        require(sqrtPriceX96 > 0, "Pool not initialized");

        console2.log("sqrtPriceX96:", sqrtPriceX96);
        
        // Get price from Uniswap V3 pool
        uint256 price = priceModule.getPrice(pool);
        console2.log("ETH/USDC Price:", price);

        // Basic sanity check
        assertTrue(price > 0, "Price should be greater than 0");
        
        // ETH price should be roughly between 1000-5000 USDC
        assertTrue(price >= 1000e6 && price <= 5000e6, "Price outside reasonable range");
    }
}
