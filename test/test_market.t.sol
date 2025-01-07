// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";
import {PNPFactory} from "../src/pnpFactory.sol";
import {PythagoreanBondingCurve} from "../src/libraries/PythagoreanBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ITruthModule} from "../src/interfaces/ITruthModule.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {PriceModule} from "../src/PriceModule.sol";

interface INANIPriceChecker {
    function checkPrice(address token) external returns(uint256,string memory);
}

contract TestMarket is Test {

    uint256 public baseMainnetFork;
    PNPFactory public factory;
    PriceModule public truthModule;

    // doing operations on BASE mainnet 
    address public collateralToken = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
    address public bettingToken1 = 0x4200000000000000000000000000000000000006; // ETH
    address public bettingToken2 = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b; // VIRTUALS
    address public NANI_CTC = 0x0000000000cDC1F8d393415455E382c30FBc0a84;

    address richUSDC = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A;
    address alice;
    address bob;
    address eve;

    function setUp() public {

        baseMainnetFork = vm.createFork("https://base-mainnet.g.alchemy.com/v2/krAmbFw5EvIt8P5wg3msfSlCgN4Jt7Fs");
        vm.selectFork(baseMainnetFork);

        // init addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        eve = makeAddr("eve");

        vm.startPrank(eve); // eve is the factory admin
        factory = new PNPFactory("bro");
        truthModule = new PriceModule();
        factory.setModuleAddress(0, address(truthModule));
        vm.stopPrank();

        vm.startPrank(richUSDC);
        IERC20(collateralToken).transfer(alice, 5000 * 10 ** 6);
        IERC20(collateralToken).transfer(bob, 5000 * 10 ** 6);
        IERC20(collateralToken).transfer(eve, 5000 * 10 ** 6);
        vm.stopPrank();

    }

    function test_ctc_price() public {
        // let's check NANI_CTC 
        (uint256 eth_price, string memory strPrice ) = INANIPriceChecker(NANI_CTC).checkPrice(bettingToken1);
        console2.log(eth_price);
        console2.log(strPrice); 

        (uint256 virtual_price, string memory strPrice1 ) = INANIPriceChecker(NANI_CTC).checkPrice(bettingToken2);
        console2.log(virtual_price);
        console2.log(strPrice1);    

        
    }

    function test_create_market() public {

        // alice wants to create a prediction market
        // which bets a 5% increase in virtuals price in the next 15 blocks 

        (uint256 virtual_price, string memory strPrice1 ) = INANIPriceChecker(NANI_CTC).checkPrice(bettingToken2);
        console2.log("Current price of virtuals is :", virtual_price);

        // construct market params
        uint256[] memory marketParams = new uint256[](2);
        marketParams[0] = block.timestamp + 2; // 15 blocks later
        marketParams[1] = virtual_price + virtual_price * 5 / 100; // 5% increase in price 

        // alice creates the market with 10 USDC initial liquidity 
        vm.startPrank(alice);
        IERC20(collateralToken).approve(address(factory), 10 * 10 ** 6);
        uint256 gasStart = gasleft();
        bytes32 conditionId = factory.createPredictionMarket(10*10**6, bettingToken2, 0, collateralToken, marketParams);
        uint256 gasSpent = gasStart - gasleft();
        console2.log("Total gas spent in creating the market: ", gasSpent);
        vm.stopPrank();

        console2.log("Prediction market created with conditionId: ");
        console2.log(uint256(conditionId));

        uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));

        uint256 scaledMarketReserve = factory.marketReserve(conditionId);

        uint256 priceOfYes = PythagoreanBondingCurve.getPrice(
            scaledMarketReserve, factory.totalSupply(yesTokenId), factory.totalSupply(noTokenId)
        );
        uint256 priceOfNo = PythagoreanBondingCurve.getPrice(
            scaledMarketReserve, factory.totalSupply(noTokenId), factory.totalSupply(yesTokenId)
        );

        console2.log("Price of YES token after creating market: ", priceOfYes);
        console2.log("Price of NO token after creating market: ", priceOfNo);

        // we assert the mappings 
        assertEq(factory.moduleTypeUsed(conditionId), 0);
        assertEq(factory.marketParams(conditionId, 0), block.timestamp + 2 );
        assertEq(factory.marketParams(conditionId, 1), marketParams[1]);
        assertEq(factory.marketSettled(conditionId), false);
        assertEq(factory.marketReserve(conditionId), 10 * 10 ** 18);
        assertEq(factory.winningTokenId(conditionId), 0);

        // check YES NO token balances of alice 
        console2.log("YES token balance of ALICE");
        console2.log(factory.balanceOf(alice, yesTokenId));
        console2.log("NO token balance of ALICE");
        console2.log(factory.balanceOf(alice, noTokenId));

        // now bob will buy $69 dollars worth of YES tokens
        vm.startPrank(bob); 
        IERC20(collateralToken).approve(address(factory), 69 * 10 ** 6);
        factory.mintDecisionTokens(conditionId, 69 * 10 ** 6, yesTokenId);
        vm.stopPrank();

        // check YES NO balances of bob
        console2.log("YES token balance of bob");
        console2.log(factory.balanceOf(bob, yesTokenId));
        console2.log("NO token balance of bob");      
        console2.log(factory.balanceOf(bob, noTokenId));

        // check total supplies of YES and NO tokens
        console2.log("Total supply of YES token");
        console2.log(factory.totalSupply(yesTokenId));
        console2.log("Total supply of NO token");
        console2.log(factory.totalSupply(noTokenId));

        // checking prices again 
        scaledMarketReserve = factory.marketReserve(conditionId);
        priceOfYes = PythagoreanBondingCurve.getPrice(
            scaledMarketReserve, factory.totalSupply(yesTokenId), factory.totalSupply(noTokenId)
        );
        priceOfNo = PythagoreanBondingCurve.getPrice(
            scaledMarketReserve, factory.totalSupply(noTokenId), factory.totalSupply(yesTokenId)
        );

        console2.log("Price of YES tokens now ", priceOfYes);
        console2.log("Price of NO tokens now ", priceOfNo);

        // Roll forward 2 blocks and settle the market
        vm.roll(block.number + 2);
        
        // Eve settles the market
        vm.startPrank(eve);
        factory.settleMarket(conditionId);
        vm.stopPrank();

        // Check if market is settled
        assertTrue(factory.marketSettled(conditionId));

        // Get winning token ID
        uint256 winningToken = factory.winningTokenId(conditionId);
        console2.log("Winning token ID:", winningToken);

        // Alice redeems her position
        vm.startPrank(alice);
        uint256 aliceBalanceBefore = IERC20(collateralToken).balanceOf(alice);
        factory.redeemPosition(conditionId);
        uint256 aliceBalanceAfter = IERC20(collateralToken).balanceOf(alice);
        console2.log("Alice's winning amount:", (aliceBalanceAfter - aliceBalanceBefore) / 1e6, "USDC");
        vm.stopPrank();

        // Bob redeems his position
        vm.startPrank(bob);
        uint256 bobBalanceBefore = IERC20(collateralToken).balanceOf(bob);
        factory.redeemPosition(conditionId);
        uint256 bobBalanceAfter = IERC20(collateralToken).balanceOf(bob);
        console2.log("Bob's winning amount:", (bobBalanceAfter - bobBalanceBefore) / 1e6, "USDC");
        vm.stopPrank();
    }





}
