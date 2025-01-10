// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";
import {PNPFactory} from "../src/pnpFactory.sol";
import {PythagoreanBondingCurve} from "../src/libraries/PythagoreanBondingCurve.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestTwitter is Test {

    address public alice;
    address public bob;
    address public ansem;

    uint256 public baseMainnetFork;
    PNPFactory public factory;

    address public base_usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address richUSDC = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A;
    address twitterMarketsSettler = 0xC8b8fa405e62c956eF9Ae963d44C27c38A18936c;

    function setUp() public {
        baseMainnetFork = vm.createFork("");
        vm.selectFork(baseMainnetFork);
        factory = new PNPFactory("pnp-markets");

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        ansem = makeAddr("kol");

        // fund alice bob and ansem 5000 USDC 
        vm.startPrank(richUSDC);
        IERC20(base_usdc).transfer(alice, 5000 * 10 ** 6);
        IERC20(base_usdc).transfer(bob, 5000 * 10 ** 6);
        IERC20(base_usdc).transfer(ansem, 5000 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(alice);
        // alice approves factory to spend 100 USDC
        IERC20(base_usdc).approve(address(factory), 100 * 10 ** 6);
        vm.stopPrank();
    }

    // +ve case
    function test_createTwitterMarketWithCorrectParams() public {
        string memory question = "Will Donald Trump buy Greenland by end of January 2025?";
        string memory settlerId = "@realDonaldTrump";
        uint256 endTime = block.timestamp + 86400; 

        vm.startPrank(alice);

        // alice approves factory to spend 100 USDC
        IERC20(base_usdc).approve(address(factory), 100 * 10 ** 6);
        uint256 gasStart = gasleft();
        bytes32 conditionId = factory.createTwitterMarket(question, settlerId, endTime, base_usdc, 100 * 10 ** 6);
        uint256 gasSpent = gasStart - gasleft();
        console2.log("Total gas spent in creating the market: ", gasSpent);
        vm.stopPrank();

        assertEq(factory.isTwitterMarket(conditionId), true);
        assertEq(factory.twitterQuestion(conditionId), question);
        assertEq(factory.twitterSettlerId(conditionId), settlerId);
        assertEq(factory.twitterEndTime(conditionId), endTime);
        assertEq(factory.collateralToken(conditionId), base_usdc);
        assertEq(factory.marketReserve(conditionId), 100 * 10 ** 18);
    }

    // -ve case 
    function test_createTwitterMarketWithIncorrectParams() public {
        string memory question = "Will Donald Trump buy Greenland by end of January 2025?";
        string memory settlerId = "@realDonaldTrump";
        uint256 endTime = block.timestamp;

        vm.startPrank(alice);

        // alice approves factory to spend 100 USDC
        IERC20(base_usdc).approve(address(factory), 100 * 10 ** 6);
        uint256 gasStart = gasleft();
        vm.expectRevert(); // @todo add error parameters
        bytes32 conditionId = factory.createTwitterMarket(question, settlerId, endTime, base_usdc, 100 * 10 ** 6);
        vm.stopPrank();
    }

    // -ve case
    function test_createTwitterMarketWithZeroLiquidity() public {
        string memory question = "Will Donald Trump buy Greenland by end of January 2025?";
        string memory settlerId = "@realDonaldTrump";
        uint256 endTime = block.timestamp + 86400;

        vm.startPrank(alice);

        // alice approves factory to spend 100 USDC
        IERC20(base_usdc).approve(address(factory), 100 * 10 ** 6);
        vm.expectRevert(); // @todo add error parameters
        bytes32 conditionId = factory.createTwitterMarket(question, settlerId, endTime, base_usdc, 0);
        vm.stopPrank();
    }

    // -ve case
    function test_createTwitterMarketWithZeroCollateralToken() public {
        string memory question = "Will Donald Trump buy Greenland by end of January 2025?";
        string memory settlerId = "@realDonaldTrump";
        uint256 endTime = block.timestamp + 86400;

        vm.startPrank(alice);

        // alice approves factory to spend 100 USDC
        IERC20(base_usdc).approve(address(factory), 100 * 10 ** 6);
        vm.expectRevert(); // @todo add error parameters
        bytes32 conditionId = factory.createTwitterMarket(question, settlerId, endTime, address(0), 100 * 10 ** 6);
        vm.stopPrank();
    }

    // +ve case
    function test_buyDecisionTokens() public {

        // create market get conditonId
        string memory question = "Will Donald Trump buy Greenland by end of January 2025?";
        string memory settlerId = "@realDonaldTrump";
        uint256 endTime = block.timestamp + 86400; 
        vm.startPrank(alice);
        IERC20(base_usdc).approve(address(factory), 100 * 10 ** 6);
        uint256 gasStart = gasleft();
        bytes32 conditionId = factory.createTwitterMarket(question, settlerId, endTime, base_usdc, 100 * 10 ** 6);
        uint256 gasSpent = gasStart - gasleft();
        console2.log("Total gas spent in creating the market: ", gasSpent);
        vm.stopPrank();

        // now ansem will buy 100 USDC worth of NO tokens
        vm.startPrank(ansem);
        uint256 noTokenId = factory.getNoTokenId(conditionId);
        gasStart = gasleft();
        IERC20(base_usdc).approve(address(factory), 100 * 10 ** 6);
        factory.mintDecisionTokens(conditionId, 100 * 10 ** 6, noTokenId);
        gasSpent = gasStart - gasleft();
        console2.log("Total gas spent in minting NO tokens: ", gasSpent);
        vm.stopPrank();

        // let's check price of each YES and NO tokens 
        uint256 marketReserve = factory.marketReserve(conditionId); 
        uint256 yesTokenId = factory.getYesTokenId(conditionId);

        uint256 yesSupply = factory.totalSupply(yesTokenId);
        uint256 noSupply = factory.totalSupply(noTokenId);

        uint256 yesPrice = PythagoreanBondingCurve.getPrice(marketReserve, yesSupply, noSupply);
        uint256 noPrice = PythagoreanBondingCurve.getPrice(marketReserve, noSupply, yesSupply);

        console2.log("YES price: ", yesPrice);
        console2.log("NO price: ", noPrice);
    }

    // @TODO write negative cases for buying and burning decision tokens

    function test_settleMarket() public {

        // create market get conditonId
        string memory question = "Will Donald Trump buy Greenland by end of January 2025?";
        string memory settlerId = "@realDonaldTrump";
        uint256 endTime = block.timestamp + 15; 
        vm.startPrank(alice);
        IERC20(base_usdc).approve(address(factory), 100 * 10 ** 6);
        uint256 gasStart = gasleft();
        bytes32 conditionId = factory.createTwitterMarket(question, settlerId, endTime, base_usdc, 100 * 10 ** 6);
        uint256 gasSpent = gasStart - gasleft();
        console2.log("Total gas spent in creating the market: ", gasSpent);
        vm.stopPrank();

        // uint256 curr = block.timestamp;
        // vm.roll(curr + 16);
        // vm.startPrank(twitterMarketsSettler);
        // console2.log("current block number: ", block.timestamp);
        // console2.log("market was created at", endTime);
        // uint256 yesTokenId = factory.getYesTokenId(conditionId);
        // factory.settleTwitterMarket(conditionId, yesTokenId);
        // vm.stopPrank();

        // assertEq(factory.marketSettled(conditionId), true);

    }




}