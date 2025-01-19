// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";
import {PythagoreanBondingCurve} from "../src/libraries/PythagoreanBondingCurve.sol";
import {PNPFactory} from "../src/pnpFactory.sol";
import {ITruthModule} from "../src/interfaces/ITruthModule.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Dummy ERC20 token for testing
contract collateralERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract bettingERC20 is ERC20{
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }   
}

// Dummy Price Module contract for testing
contract DummyPriceModule is ITruthModule {
    function settle(bytes32 conditionId, address tokenInQuestion, uint256 targetPrice)
        external
        returns (uint256 winningTokenId)
    {
        // Always return YES token ID for testing purposes
        return uint256(keccak256(abi.encodePacked(conditionId, "YES")));
    }
}

contract TestPriceMarkets is Test {
    PNPFactory public factory;
    DummyPriceModule public priceModule;
    collateralERC20 public collateralToken;
    bettingERC20 public bettingToken;
    
    address public alice;
    address public bob;
    address public admin;
    
    bytes32 public conditionId;
    uint256 public yesTokenId;
    uint256 public noTokenId;
    uint256 public marketEndTime;
    uint256 public targetPrice;

    function setUp() public {
        // Setup addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        admin = makeAddr("admin");
        
        vm.startPrank(admin);
        
        // Deploy tokens
        collateralToken = new collateralERC20("USDC", "USDC");
        bettingToken = new bettingERC20("Wrapped ETH", "WETH");
        
        // Deploy contracts
        factory = new PNPFactory("pnp-markets");
        priceModule = new DummyPriceModule();
        factory.setModuleAddress(0, address(priceModule));
        
        // Fund addresses with collateral token
        collateralToken.transfer(alice, 5000 * 10 ** 18);
        collateralToken.transfer(bob, 5000 * 10 ** 18);
        
        // Create market parameters
        marketEndTime = block.timestamp + 7 days;
        targetPrice = 2500 * 10 ** 18;
        uint256[] memory marketParams = new uint256[](2);
        marketParams[0] = marketEndTime;
        marketParams[1] = targetPrice;
        
        // Approve spending
        collateralToken.approve(address(factory), 1000 * 10 ** 18);
        
        // Create market with correct parameter order:
        // _initialLiquidity, _tokenInQuestion, _moduleId, _collateralToken, _marketParams
        conditionId = factory.createPredictionMarket(
            1000 * 10 ** 18, // _initialLiquidity
            address(bettingToken), // _tokenInQuestion (WETH)
            0, // _moduleId for price module
            address(collateralToken), // _collateralToken
            marketParams // _marketParams [expiry, targetPrice]
        );
        
        // Store token IDs
        yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));
        
        vm.stopPrank();
    }

    function test_marketCreated1() public {
        assertTrue(factory.balanceOf(admin, yesTokenId) > 0, "Admin should have YES tokens");
        assertTrue(factory.balanceOf(admin, noTokenId) > 0, "Admin should have NO tokens");
    }

    // test whether the mappings that are created during market creation are correct
    function test_marketParamsSet() public {
        // Check moduleTypeUsed mapping
        assertEq(factory.moduleTypeUsed(conditionId), 0, "Incorrect module type");
        
        // Check moduleAddress mapping
        assertEq(factory.moduleAddress(0), address(priceModule), "Incorrect module address");
        
        // Check marketParams mapping
        assertEq(factory.getMarketEndTime(conditionId), marketEndTime, "Incorrect market end time");
        assertEq(factory.getMarketTargetPrice(conditionId), targetPrice, "Incorrect target price");
        
        // Check collateralToken mapping
        assertEq(factory.collateralToken(conditionId), address(collateralToken), "Incorrect collateral token");
        
        // Check tokenInQuestion mapping
        assertEq(factory.tokenInQuestion(conditionId), address(bettingToken), "Incorrect token in question");
        
        // Check market is not settled
        assertFalse(factory.marketSettled(conditionId), "Market should not be settled");
    }

    // let alice and bob trade and write assertions for it
    function test_tradeInMarket() public {
        // Alice buys YES tokens
        vm.startPrank(alice);
        collateralToken.approve(address(factory), 100 * 10 ** 18);
        factory.mintDecisionTokens(conditionId, 100 * 10 ** 18, yesTokenId);
        vm.stopPrank();
        
        // Bob buys NO tokens
        vm.startPrank(bob);
        collateralToken.approve(address(factory), 200 * 10 ** 18);
        factory.mintDecisionTokens(conditionId,200 * 10 ** 18, noTokenId);
        vm.stopPrank();
        
        // Assert balances
        assertTrue(factory.balanceOf(alice, yesTokenId) > 0, "Alice should have YES tokens");
        assertTrue(factory.balanceOf(bob, noTokenId) > 0, "Bob should have NO tokens");
        
        // Assert market reserve increased
        assertTrue(factory.marketReserve(conditionId) > 1000 * 10 ** 18, "Market reserve should increase");
    }

    // make bob try a buy and sell trade and the call should
    // revert you can use vm.expectRevert();
    function test_revertsAfterExpiry() public {
        // Warp time to after expiry
        vm.warp(marketEndTime + 1);
        
        vm.startPrank(bob);
        collateralToken.approve(address(factory), 100 * 10 ** 18);
        
        // Attempt to buy after expiry should revert
        vm.expectRevert("Market trading stopped");
        factory.mintDecisionTokens(conditionId, 100 * 10 ** 18, yesTokenId);
        
        vm.stopPrank();
    }

    function test_settleMarket() public {
        // Warp time to after expiry
        vm.warp(marketEndTime + 1);
        
        // Settle market
        uint256 winningTokenId = factory.settleMarket(conditionId);
        
        // Assert settlement
        assertTrue(factory.marketSettled(conditionId), "Market should be settled");
        assertEq(winningTokenId, yesTokenId, "YES should be winning token");
        assertEq(factory.winningTokenId(conditionId), yesTokenId, "Incorrect winning token stored");
    }
}