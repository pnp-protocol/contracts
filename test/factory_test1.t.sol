// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";
import {PNPFactory} from "../src/PNPFactory.sol";
import {PythagoreanBondingCurve} from "../src/libraries/PythagoreanBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITruthModule} from "../src/interfaces/ITruthModule.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {PriceModule} from "../src/PriceModule.sol";

contract FactoryTest is Test {

    uint256 public baseMainnetFork;
    PNPFactory public factory;
    PriceModule public truthModule;
    
    address public collateralToken = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC 
    address public bettingToken = 0x4200000000000000000000000000000000000006; // ETH 
    address public pool = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    // can be any token denominated Pool
    // ETH/USDT price

    address richUSDC = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A;
    address alice;
    address bob;
    address eve;

    function setUp() public {

        baseMainnetFork = vm.createFork("https://base-mainnet.public.blastapi.io");
        vm.selectFork(baseMainnetFork);

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        eve = makeAddr("eve");

        vm.startPrank(eve); // eve is the factory admin
        factory = new PNPFactory("bro");
        truthModule = new PriceModule();
        factory.setModuleAddress(0, address(truthModule));
        vm.stopPrank();
        
    
        vm.startPrank(richUSDC);
        IERC20(collateralToken).transfer(alice,5000*10**6);
        IERC20(collateralToken).transfer(bob,5000*10**6);
        IERC20(collateralToken).transfer(eve,5000*10**6);
        vm.stopPrank();
    }

    function test_factoryDeployment() public {
        address addr = address(factory);
        assertNotEq(addr, address(0));
        console2.log("factory address: ");
        console2.log(address(addr));
    }

    function test_PriceModuleDeployment() public {

    }

    function test_PriceModule() public {

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
        // alice wants to create a market 
        // he wants to bet on price of ETH to be at a greater price 15 blocks later

        // he provides iitial liquidity of 100 USDC
        vm.startPrank(alice);
        IERC20(collateralToken).approve(address(factory), 100*10**6);

        // now he calls our contract with config params
        address tokenInQuestion = bettingToken; // eth  
        uint256 initialLiquidity = 100*10**6; // 100 usdc
        uint8 moduleId = 0; // price module
        
        uint256[] memory marketParams = new uint256[](2);
        marketParams[0] = block.timestamp + 15; // 15 blocks later

        // fetch current price from pool and bet a 2% increase 
        uint256 currPrice = truthModule.getPrice(IUniswapV3Pool(pool));
        uint256 targetPrice = currPrice + currPrice * 2 / 100;
        marketParams[1] = targetPrice;

        uint256 gasStart = gasleft();
        bytes32 conditionId = factory.createPredictionMarket(initialLiquidity, tokenInQuestion, moduleId, collateralToken, marketParams, pool);
        uint256 gasSpent = gasStart - gasleft();
        console2.log("Prediction market created with conditionId: ", conditionId);
        console2.log("Total gas spent in creating the market: ", gasSpent);
        vm.stopPrank();

        // we assert the mappings for the market 
        assertEq(factory.moduleTypeUsed[conditionId], moduleId);
        assertEq(factory.marketParams[conditionId][0], block.timestamp + 15);
        assertEq(factory.marketParams[conditionId][1], targetPrice); 
        assertEq(factory.marketSettled[conditionId], false);
        assertEq(factory.marketReserve[conditionId], initialLiquidity);
        assertEq(factory.winningTokenId[conditionId],0);

        // check YES NO token balances of alice   

        
    }

    function test_buyingDecisionTokens() public {}

    function test_sellingDecisionTokens() public {}

    function test_tradingAfterExpiration() public {}

    function test_settleIncentives() public {}

    function test_redeemPosition() public {}





}