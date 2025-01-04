// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Test, console2, Vm} from "../lib/forge-std/src/Test.sol";
// import {PNPFactory} from "../src/pnpFactory.sol";
// import {PythagoreanBondingCurve} from "../src/libraries/PythagoreanBondingCurve.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
// import {ITruthModule} from "../src/interfaces/ITruthModule.sol";
// import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// import {PriceModule} from "../src/PriceModule.sol";

// contract FactoryTest is Test {
//     uint256 public baseMainnetFork;
//     PNPFactory public factory;
//     PriceModule public truthModule;

//     address public collateralToken = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
//     address public bettingToken = 0x4200000000000000000000000000000000000006; // ETH
//     address public pool = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
//     // can be any token denominated Pool
//     // ETH/USDT price

//     address richUSDC = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A;
//     address alice;
//     address bob;
//     address eve;

//     function setUp() public {
//         baseMainnetFork = vm.createFork("https://base-mainnet.public.blastapi.io");
//         vm.selectFork(baseMainnetFork);

//         alice = makeAddr("alice");
//         bob = makeAddr("bob");
//         eve = makeAddr("eve");

//         vm.startPrank(eve); // eve is the factory admin
//         factory = new PNPFactory("bro");
//         truthModule = new PriceModule();
//         factory.setModuleAddress(0, address(truthModule));
//         vm.stopPrank();

//         vm.startPrank(richUSDC);
//         IERC20(collateralToken).transfer(alice, 5000 * 10 ** 6);
//         IERC20(collateralToken).transfer(bob, 5000 * 10 ** 6);
//         IERC20(collateralToken).transfer(eve, 5000 * 10 ** 6);
//         vm.stopPrank();
//     }

//     function test_factoryDeployment() public {
//         address addr = address(factory);
//         assertNotEq(addr, address(0));
//         console2.log("factory address: ");
//         console2.log(address(addr));
//     }

//     function test_PriceModuleDeployment() public {}

//     function test_PriceModule() public {}

//     function test_erc1155Compliance() public {
//         // interface id of erc-1155 is 0xd9b67a26
//         bool compliant = factory.supportsInterface(0xd9b67a26);
//         assertEq(compliant, true);
//         if (compliant) {
//             console2.log("factory supports erc-1155");
//         }
//     }

//     function test_marketCreation() public {
//         // alice wants to create a market
//         // he wants to bet on price of ETH to be at a greater price 15 blocks later
//         // 2% increase to be specific

//         // he provides iitial liquidity of 100 USDC
//         vm.startPrank(alice);
//         IERC20(collateralToken).approve(address(factory), 100 * 10 ** 6);

//         // now he calls our contract with config params
//         address tokenInQuestion = bettingToken; // eth
//         uint256 initialLiquidity = 100 * 10 ** 6;
//         uint256 collateralDecimals = IERC20Metadata(collateralToken).decimals();
//         uint256 scaledInitialLiquidity = (initialLiquidity * 10 ** 18) / 10 ** collateralDecimals;

//         uint256[] memory marketParams = new uint256[](2);
//         marketParams[0] = block.timestamp + 15; // 15 blocks later

//         // fetch current price from pool and bet a 2% increase
//         uint256 currPrice = truthModule.getPriceInUSDC(bettingToken);
//         console2.log("Current price of ETH, we will make a 2% increase bet on it", currPrice);
//         uint256 targetPrice = currPrice + currPrice * 2 / 100;
//         marketParams[1] = targetPrice;

//         uint256 gasStart = gasleft();
//         bytes32 conditionId =
//             factory.createPredictionMarket(initialLiquidity, tokenInQuestion, 0, collateralToken, marketParams);
//         uint256 gasSpent = gasStart - gasleft();
//         // console2.log("Prediction market created with conditionId: ");
//         // console2.log(conditionId);
//         console2.log("Total gas spent in creating the market: ", gasSpent);
//         vm.stopPrank();

//         // we assert the mappings for the market
//         assertEq(factory.moduleTypeUsed(conditionId), 0);

//         // Scale the assertions according to decimals
//         uint256 scaledTargetPrice = (targetPrice * 10 ** 18) / 10 ** collateralDecimals;

//         assertEq(factory.marketParams(conditionId, 0), block.timestamp + 15);
//         assertEq(factory.marketParams(conditionId, 1), targetPrice);
//         assertEq(factory.marketSettled(conditionId), false);
//         assertEq(factory.marketReserve(conditionId), scaledInitialLiquidity);
//         assertEq(factory.winningTokenId(conditionId), 0);

//         // check YES NO token balances of alice
//         uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
//         uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));

//         assertEq(factory.balanceOf(alice, yesTokenId), scaledInitialLiquidity);
//         assertEq(factory.balanceOf(alice, noTokenId), scaledInitialLiquidity);
//         console2.log("alice now has a total of ", scaledInitialLiquidity, " YES and NO tokens");

//         vm.startPrank(bob);
//         // bob wants to buy $100 worth of yes tokens
//         console2.log("now bob wants to buy $100 worth of yes tokens");
//         console2.log("previous Balance of yes tokens of bob: ", factory.balanceOf(bob, yesTokenId));
//         IERC20(collateralToken).approve(address(factory), 100 * 10 ** 6);
//         uint256 prevBalance = IERC20(collateralToken).balanceOf(address(factory));
//         factory.mintDecisionTokens(conditionId, 100 * 10 ** 6, yesTokenId);
//         uint256 bobYesBalance = factory.balanceOf(bob, yesTokenId);
//         console2.log("current YES token balance of bob after minting $100 worth of tokens:", bobYesBalance);
//         assertEq(IERC20(collateralToken).balanceOf(address(factory)) - prevBalance, 100 * 10 ** 6);
//         vm.stopPrank();

//         // console log out the price of YES and NO tokens
//         uint256 marketReserve = factory.marketReserve(conditionId);
//         uint256 priceOfYes = PythagoreanBondingCurve.getPrice(
//             marketReserve, factory.totalSupply(yesTokenId), factory.totalSupply(noTokenId)
//         );
//         uint256 priceOfNo = PythagoreanBondingCurve.getPrice(
//             marketReserve, factory.totalSupply(noTokenId), factory.totalSupply(yesTokenId)
//         );
//         console2.log("Price of YES token (in 18 decimals): ", priceOfYes);
//         console2.log("Price of NO token (in 18 decimals): ", priceOfNo);

//         // eve want to buy $75 worth of no tokens
//         vm.startPrank(eve);
//         IERC20(collateralToken).approve(address(factory), 75 * 10 ** 6);
//         uint256 prevBalance1 = IERC20(collateralToken).balanceOf(address(factory));
//         factory.mintDecisionTokens(conditionId, 75 * 10 ** 6, noTokenId);
//         uint256 eveNoBalance = factory.balanceOf(eve, noTokenId);
//         console2.log("NO token balance of eve (in 18 decimals): ", eveNoBalance);
//         assertEq(IERC20(collateralToken).balanceOf(address(factory)) - prevBalance1, 75 * 10 ** 6);
//         vm.stopPrank();

//         uint256 totalYesSupply = factory.totalSupply(yesTokenId);
//         uint256 totalNoSupply = factory.totalSupply(noTokenId);

//         console2.log("Total supply of YES token (in 18 decimals): ", totalYesSupply);
//         console2.log("Total supply of NO token (in 18 decimals): ", totalNoSupply);

//         marketReserve = factory.marketReserve(conditionId);
//         priceOfYes = PythagoreanBondingCurve.getPrice(
//             marketReserve, factory.totalSupply(yesTokenId), factory.totalSupply(noTokenId)
//         );
//         priceOfYes = PythagoreanBondingCurve.getPrice(
//             marketReserve, factory.totalSupply(yesTokenId), factory.totalSupply(noTokenId)
//         );
//         console2.log("Price of YES token (in 18 decimals): ", priceOfYes);
//         console2.log("Price of NO token (in 18 decimals): ", priceOfNo);

//         // at the end
//         // totalSupply of YES * price of yes + totalSupply of NO * price of no = marketReserve
//         // let's assert these
//         uint256 SCALE = 1e18;

//         uint256 priceYes = PythagoreanBondingCurve.getPrice(marketReserve, totalYesSupply, totalNoSupply);
//         uint256 priceNo = PythagoreanBondingCurve.getPrice(marketReserve, totalNoSupply, totalYesSupply);

//         uint256 a = (totalYesSupply * priceYes) / SCALE; // Divide by SCALE since price is in 18 decimals
//         uint256 b = (totalNoSupply * priceNo) / SCALE; // Divide by SCALE since price is in 18 decimals

//         console2.log(a + b);
//         console2.log(marketReserve);

//         // roll the block by 20 blocks
//         // test whether we get a revert on calling mint and burn function
//         // create an address called settler which calls the settle() function
//         // check the winningTokenId
//         // make attempts to redeem the positions

//         console2.log("now let's settle the market ");
//         vm.roll(20);

//         address settler = makeAddr("settler");
//         vm.startPrank(settler);
//         uint256 answerTokenId = factory.settleMarket(conditionId);
//         console2.log("The current price of the asset is:", truthModule.getPriceInUSDC(bettingToken));
//         console2.log("target price for the asset was:", marketParams[1]);
//         vm.stopPrank();

//         console2.log("answerTokenId: ", answerTokenId);
//         if (answerTokenId == uint256(keccak256(abi.encodePacked(conditionId, "YES")))) {
//             console2.log("The answer is YES");
//         } else if (answerTokenId == uint256(keccak256(abi.encodePacked(conditionId, "NO")))) {
//             console2.log("The answer is NO");
//         }
//     }

//     function test_buyingDecisionTokens() public {}

//     function test_sellingDecisionTokens() public {}

//     function test_tradingAfterExpiration() public {}

//     function test_settleIncentives() public {}

//     function test_redeemPosition() public {}
// }
