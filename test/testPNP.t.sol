// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/pnpFactory.sol";

contract MockERC20 is IERC20Metadata {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = 1000000 * 10 ** decimals_;
        _balances[msg.sender] = _totalSupply;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(_balances[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        require(_allowances[from][msg.sender] >= amount, "ERC20: insufficient allowance");

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract testPNP is Test {
    PNPFactory public pnpFactory;
    MockERC20 public usdc;
    MockERC20 public usdt;
    MockERC20 public dai;

    // Simulated users
    address public marketCreator;
    address public liquidityProvider;
    address public trader1;
    address public trader2;
    address public trader3;

    // Market parameters
    string public constant MARKET_QUESTION = "Will ETH be above $4000 by end of 2024?";
    uint256 public constant MARKET_END_TIME = 1735689600; // Jan 1, 2025
    uint256 public constant INITIAL_LIQUIDITY = 10000 * 1e6; // 10k USDC
    uint256 internal constant MIN_AMOUNT_VALUE = 1_000_000; // Matches MIN_AMOUNT in PNPFactory for 6-decimal tokens

    bytes32 public conditionId;

    function setUp() public {
        // Create mock tokens with different decimals
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdt = new MockERC20("Tether USD", "USDT", 6);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);

        // Create simulated users
        marketCreator = makeAddr("marketCreator");
        liquidityProvider = makeAddr("liquidityProvider");
        trader1 = makeAddr("trader1");
        trader2 = makeAddr("trader2");
        trader3 = makeAddr("trader3");

        // Deploy PNPFactory
        pnpFactory = new PNPFactory("https://pnp.exchange/api/outcomeTokens/{id}.json");

        // Fund users with USDC
        usdc.mint(marketCreator, 100000 * 1e6); // Use mint for setup clarity
        usdc.mint(liquidityProvider, 100000 * 1e6);
        usdc.mint(trader1, 100000 * 1e6);
        usdc.mint(trader2, 100000 * 1e6);
        usdc.mint(trader3, 100000 * 1e6);

        // Fund users with USDT
        usdt.mint(marketCreator, 100000 * 1e6);
        usdt.mint(liquidityProvider, 100000 * 1e6);

        // Fund users with DAI
        dai.mint(marketCreator, 100000 * 1e18);
        dai.mint(liquidityProvider, 100000 * 1e18);

        // Approve PNPFactory to spend tokens for all users
        vm.startPrank(marketCreator);
        usdc.approve(address(pnpFactory), type(uint256).max);
        usdt.approve(address(pnpFactory), type(uint256).max);
        dai.approve(address(pnpFactory), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        usdc.approve(address(pnpFactory), type(uint256).max);
        usdt.approve(address(pnpFactory), type(uint256).max);
        dai.approve(address(pnpFactory), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(trader1);
        usdc.approve(address(pnpFactory), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(trader2);
        usdc.approve(address(pnpFactory), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(trader3);
        usdc.approve(address(pnpFactory), type(uint256).max);
        vm.stopPrank();
    }

    function test_createPredictionMarket() public {
        vm.startPrank(marketCreator);

        // Create market with USDC
        bytes32 marketId =
            pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);

        // Verify market creation
        assertTrue(pnpFactory.isMarketCreated(marketId));
        assertEq(pnpFactory.marketQuestion(marketId), MARKET_QUESTION);
        assertEq(pnpFactory.marketEndTime(marketId), MARKET_END_TIME);
        assertEq(pnpFactory.collateralToken(marketId), address(usdc));

        // Verify initial liquidity was split between YES and NO tokens and scaled correctly
        uint256 yesTokenId = pnpFactory.getYesTokenId(marketId);
        uint256 noTokenId = pnpFactory.getNoTokenId(marketId);
        
        uint256 expectedScaledLiquidity = pnpFactory.scaleTo18Decimals(INITIAL_LIQUIDITY, usdc.decimals());
        assertEq(pnpFactory.balanceOf(marketCreator, yesTokenId), expectedScaledLiquidity);
        assertEq(pnpFactory.balanceOf(marketCreator, noTokenId), expectedScaledLiquidity);
        assertEq(pnpFactory.marketReserve(marketId), expectedScaledLiquidity);

        vm.stopPrank();
    }

    function test_createPredictionMarket_withMinAmount() public {
        vm.startPrank(marketCreator);

        bytes32 marketId =
            pnpFactory.createPredictionMarket(MIN_AMOUNT_VALUE, address(usdc), "Min amount market?", MARKET_END_TIME);
        assertTrue(pnpFactory.isMarketCreated(marketId));
        
        uint256 expectedScaledLiquidity = pnpFactory.scaleTo18Decimals(MIN_AMOUNT_VALUE, usdc.decimals());
        assertEq(pnpFactory.marketReserve(marketId), expectedScaledLiquidity);
        vm.stopPrank();
    }

    function test_createPredictionMarket_withDifferentCollateral() public {
        vm.startPrank(marketCreator);

        uint256 usdtAmount = 5000 * 1e6; // 5k USDT (6 decimals)
        bytes32 marketId1 = pnpFactory.createPredictionMarket(
            usdtAmount,
            address(usdt),
            "Will BTC reach $100k in 2024?",
            MARKET_END_TIME
        );

        uint256 daiAmount = 2000 * 1e18; // 2k DAI (18 decimals)
        bytes32 marketId2 = pnpFactory.createPredictionMarket(
            daiAmount,
            address(dai),
            "Will SOL reach $200 in 2024?",
            MARKET_END_TIME + 30 days
        );

        assertTrue(pnpFactory.isMarketCreated(marketId1));
        assertTrue(pnpFactory.isMarketCreated(marketId2));

        assertEq(pnpFactory.marketReserve(marketId1), pnpFactory.scaleTo18Decimals(usdtAmount, usdt.decimals()));
        assertEq(pnpFactory.marketReserve(marketId2), pnpFactory.scaleTo18Decimals(daiAmount, dai.decimals()));

        vm.stopPrank();
    }

    function test_createPredictionMarket_reverts() public {
        vm.startPrank(marketCreator);

        // Test invalid end time
        vm.expectRevert(
            abi.encodeWithSelector(PNPFactory.InvalidMarketEndTime.selector, marketCreator, block.timestamp - 1)
        );
        pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            block.timestamp - 1 // Past time
        );

        // Test zero collateral address
        vm.expectRevert("Collateral must not be zero address"); // This is from PNPFactory's internal require
        pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(0), MARKET_QUESTION, MARKET_END_TIME);

        // Test insufficient initial liquidity (less than MIN_AMOUNT_VALUE)
        if (MIN_AMOUNT_VALUE > 0) { // Avoid underflow if MIN_AMOUNT_VALUE is 0
            vm.expectRevert(
                abi.encodeWithSelector(PNPFactory.InsufficientAmount.selector, MIN_AMOUNT_VALUE - 1, MIN_AMOUNT_VALUE)
            );
            pnpFactory.createPredictionMarket(
                MIN_AMOUNT_VALUE - 1,
                address(usdc),
                MARKET_QUESTION,
                MARKET_END_TIME
            );
        }

        // Test zero initial liquidity
        vm.expectRevert(
            abi.encodeWithSelector(PNPFactory.InsufficientAmount.selector, 0, MIN_AMOUNT_VALUE)
        );
        pnpFactory.createPredictionMarket(
            0,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        
        vm.stopPrank();
    }

    function test_mintDecisionTokens() public {
        vm.startPrank(marketCreator);
        conditionId =
            pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        uint256 noTokenId = pnpFactory.getNoTokenId(conditionId);
        uint256 mintAmount = 5000 * 1e6; // 5k USDC

        uint256 initialReserveScaled = pnpFactory.marketReserve(conditionId);
        uint256 initialUsdcBalanceLp = usdc.balanceOf(liquidityProvider);
        uint256 initialUsdcBalanceFactory = usdc.balanceOf(address(pnpFactory));

        vm.startPrank(liquidityProvider);
        pnpFactory.mintDecisionTokens(conditionId, mintAmount, yesTokenId);
        vm.stopPrank();

        uint256 yesTokensMinted = pnpFactory.balanceOf(liquidityProvider, yesTokenId);
        assertGt(yesTokensMinted, 0, "YES tokens not minted");

        uint256 expectedReserveIncrease = pnpFactory.scaleTo18Decimals(mintAmount, usdc.decimals());
        assertEq(pnpFactory.marketReserve(conditionId), initialReserveScaled + expectedReserveIncrease, "Market reserve did not increase correctly for YES mint");
        assertEq(usdc.balanceOf(liquidityProvider), initialUsdcBalanceLp - mintAmount, "LP USDC balance not debited correctly");
        assertEq(usdc.balanceOf(address(pnpFactory)), initialUsdcBalanceFactory + mintAmount, "Factory USDC balance not credited correctly");
        
        // Mint NO tokens
        initialReserveScaled = pnpFactory.marketReserve(conditionId); // update initial reserve for NO mint
        initialUsdcBalanceLp = usdc.balanceOf(liquidityProvider);
        initialUsdcBalanceFactory = usdc.balanceOf(address(pnpFactory));

        vm.startPrank(liquidityProvider);
        pnpFactory.mintDecisionTokens(conditionId, mintAmount, noTokenId);
        vm.stopPrank();

        uint256 noTokensMinted = pnpFactory.balanceOf(liquidityProvider, noTokenId);
        assertGt(noTokensMinted, 0, "NO tokens not minted");
        assertEq(pnpFactory.marketReserve(conditionId), initialReserveScaled + expectedReserveIncrease, "Market reserve did not increase correctly for NO mint");
        assertEq(usdc.balanceOf(liquidityProvider), initialUsdcBalanceLp - mintAmount, "LP USDC balance not debited correctly for NO mint");
        assertEq(usdc.balanceOf(address(pnpFactory)), initialUsdcBalanceFactory + mintAmount, "Factory USDC balance not credited correctly for NO mint");
    }

    function test_mintDecisionTokens_withMinAmount() public {
        vm.startPrank(marketCreator);
        conditionId =
            pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        uint256 initialReserveScaled = pnpFactory.marketReserve(conditionId);
        
        // Use 2x the minimum amount to ensure the bonding curve calculation works after fees
        uint256 mintAmount = MIN_AMOUNT_VALUE * 2;

        vm.startPrank(trader1);
        pnpFactory.mintDecisionTokens(conditionId, mintAmount, yesTokenId);
        vm.stopPrank();

        assertGt(pnpFactory.balanceOf(trader1, yesTokenId), 0);
        uint256 expectedReserveIncrease = pnpFactory.scaleTo18Decimals(mintAmount, usdc.decimals());
        assertEq(pnpFactory.marketReserve(conditionId), initialReserveScaled + expectedReserveIncrease);
    }

    function test_mintDecisionTokens_reverts() public {
        vm.startPrank(marketCreator);
        conditionId =
            pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);

        // Test invalid token ID first (while market is still active)
        vm.startPrank(trader1);
        vm.expectRevert(abi.encodeWithSelector(PNPFactory.InvalidTokenId.selector, trader1, 12345));
        pnpFactory.mintDecisionTokens(conditionId, MIN_AMOUNT_VALUE, 12345); // Invalid token ID
        vm.stopPrank();

        // Save current time before warping
        uint256 originalTime = block.timestamp;
        
        // Test minting after market end time
        vm.warp(MARKET_END_TIME + 1);
        vm.startPrank(trader1);
        vm.expectRevert("Market trading stopped");
        pnpFactory.mintDecisionTokens(conditionId, MIN_AMOUNT_VALUE, yesTokenId);
        vm.stopPrank();
        vm.warp(originalTime); // Reset time to original

        // Test insufficient collateral (less than MIN_AMOUNT_VALUE)
        if (MIN_AMOUNT_VALUE > 0) {
            vm.startPrank(trader1);
            vm.expectRevert(
                abi.encodeWithSelector(PNPFactory.InsufficientAmount.selector, MIN_AMOUNT_VALUE - 1, MIN_AMOUNT_VALUE)
            );
            pnpFactory.mintDecisionTokens(conditionId, MIN_AMOUNT_VALUE - 1, yesTokenId);
            vm.stopPrank();
        }

        // Test zero collateral
        vm.startPrank(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(PNPFactory.InsufficientAmount.selector, 0, MIN_AMOUNT_VALUE)
        );
        pnpFactory.mintDecisionTokens(conditionId, 0, yesTokenId);
        vm.stopPrank();
    }

    function test_burnDecisionTokens() public {
        vm.startPrank(marketCreator);
        conditionId =
            pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        uint256 mintAmount = 5000 * 1e6; // 5k USDC, > MIN_AMOUNT_VALUE

        vm.startPrank(liquidityProvider);
        pnpFactory.mintDecisionTokens(conditionId, mintAmount, yesTokenId);
        uint256 yesTokensBalanceBeforeBurn = pnpFactory.balanceOf(liquidityProvider, yesTokenId);
        uint256 marketReserveBeforeBurn = pnpFactory.marketReserve(conditionId);
        uint256 usdcBalanceBeforeBurn = usdc.balanceOf(liquidityProvider);
        uint256 factoryUsdcBalanceBeforeBurn = usdc.balanceOf(address(pnpFactory));

        uint256 burnAmount = yesTokensBalanceBeforeBurn / 2;
        uint256 collateralReceived = pnpFactory.burnDecisionTokens(conditionId, yesTokenId, burnAmount);
        vm.stopPrank();

        assertEq(pnpFactory.balanceOf(liquidityProvider, yesTokenId), yesTokensBalanceBeforeBurn - burnAmount, "Incorrect YES token balance after burn");
        assertGt(collateralReceived, 0, "No collateral received on burn");
        assertEq(usdc.balanceOf(liquidityProvider), usdcBalanceBeforeBurn + collateralReceived, "Incorrect USDC balance for LP after burn");
        
        uint256 expectedReserveDecrease = pnpFactory.scaleTo18Decimals(collateralReceived, usdc.decimals());
        // Note: due to bonding curve math, marketReserve decrease might not perfectly equal scaled collateralReceived due to rounding/precision
        // We check that it decreased and by approximately the right amount.
        // More precise check: reserveToRelease = initialReserve - newReserve.
        // newReserve = initialReserve * sqrt((new_a^2+b^2)/(a^2+b^2))
        // Here we check marketReserve directly.
        uint256 marketReserveAfterBurn = pnpFactory.marketReserve(conditionId);
        assertApproxEqAbs(marketReserveAfterBurn, marketReserveBeforeBurn - expectedReserveDecrease, 1e12, "Market reserve not updated correctly after burn"); // Allow some tolerance
        assertEq(usdc.balanceOf(address(pnpFactory)), factoryUsdcBalanceBeforeBurn - collateralReceived, "Factory USDC balance not updated correctly");
    }

    function test_burnDecisionTokens_reverts() public {
        vm.startPrank(marketCreator);
        conditionId =
            pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        
        // Test burning zero tokens first
        vm.startPrank(marketCreator);
        vm.expectRevert("Invalid amount"); // This is from PNPFactory's internal require
        pnpFactory.burnDecisionTokens(conditionId, yesTokenId, 0);
        vm.stopPrank();
        
        // Mint some tokens for marketCreator to burn later
        vm.startPrank(marketCreator);
        pnpFactory.mintDecisionTokens(conditionId, 10 * MIN_AMOUNT_VALUE, yesTokenId); // Ensure they have some
        vm.stopPrank();

        // Test burning more than balance with trader1
        uint256 someTokens = 100 * 1e18; // Scaled token amount
        vm.startPrank(trader1); // trader1 has no specific tokens for this marketId yet
        vm.expectRevert("Insufficient balance"); // This check is from ERC1155 _burn call
        pnpFactory.burnDecisionTokens(conditionId, yesTokenId, someTokens);
        vm.stopPrank();

        // Calculate burn amount BEFORE warping time
        uint256 burnAmount = pnpFactory.balanceOf(marketCreator, yesTokenId) / 2;
        
        // Save current time before warping - use a DIFFERENT variable name than in test_mintDecisionTokens_reverts
        uint256 burnTestOriginalTime = block.timestamp;
        
        // Test burning after market end time LAST
        vm.warp(MARKET_END_TIME + 1);
        vm.startPrank(marketCreator); // marketCreator has YES tokens from initial liquidity + mint
        vm.expectRevert("Market trading stopped");
        pnpFactory.burnDecisionTokens(conditionId, yesTokenId, burnAmount);
        vm.stopPrank();
        vm.warp(burnTestOriginalTime); // Reset time to original
    }

    // function test_settleAndRedeemMarket() public {
    //     // Create market and simulate trading
    //     vm.startPrank(marketCreator);
    //     conditionId =
    //         pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);
    //     vm.stopPrank();

    //     uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
    //     uint256 noTokenId = pnpFactory.getNoTokenId(conditionId);

    //     uint256 trader1MintAmount = 2000 * 1e6;
    //     uint256 trader2MintAmount = 3000 * 1e6;
    //     uint256 trader3MintAmount = 1000 * 1e6;

    //     // Simulate trading activity
    //     vm.startPrank(trader1);
    //     pnpFactory.mintDecisionTokens(conditionId, trader1MintAmount, yesTokenId);
    //     vm.stopPrank();

    //     vm.startPrank(trader2);
    //     pnpFactory.mintDecisionTokens(conditionId, trader2MintAmount, noTokenId);
    //     vm.stopPrank();

    //     vm.startPrank(trader3);
    //     pnpFactory.mintDecisionTokens(conditionId, trader3MintAmount, yesTokenId);
    //     vm.stopPrank();
        
    //     uint256 totalCollateralInMarket = INITIAL_LIQUIDITY + trader1MintAmount + trader2MintAmount + trader3MintAmount;
    //     uint256 marketReserveAtEnd = pnpFactory.marketReserve(conditionId);
    //     assertEq(marketReserveAtEnd, pnpFactory.scaleTo18Decimals(totalCollateralInMarket, usdc.decimals()), "Market reserve mismatch before settlement");

    //     // Fast forward to after market end time
    //     vm.warp(MARKET_END_TIME + 1);

    //     // Settle market with YES as winning outcome
    //     vm.startPrank(pnpFactory.owner()); // Owner settles
    //     uint256 winningTokenId = pnpFactory.settleMarket(conditionId, yesTokenId);
    //     assertEq(winningTokenId, yesTokenId);
    //     assertTrue(pnpFactory.marketSettled(conditionId));
    //     assertEq(pnpFactory.winningTokenId(conditionId), yesTokenId);
    //     vm.stopPrank();

    //     // Store balances before redemption
    //     uint256 trader1YesBalance = pnpFactory.balanceOf(trader1, yesTokenId);
    //     uint256 trader3YesBalance = pnpFactory.balanceOf(trader3, yesTokenId);
    //     uint256 marketCreatorYesBalance = pnpFactory.balanceOf(marketCreator, yesTokenId); // Market creator also has initial YES tokens

    //     uint256 trader1UsdcBefore = usdc.balanceOf(trader1);
    //     uint256 trader3UsdcBefore = usdc.balanceOf(trader3);
    //     uint256 marketCreatorUsdcBefore = usdc.balanceOf(marketCreator);
        
    //     uint256 factoryUsdcBeforeRedeem = usdc.balanceOf(address(pnpFactory));
    //     // uint256 totalWinningTokens = pnpFactory.totalSupply(yesTokenId); // Removed as it was unused and causing stack issues

    //     // Redeem for trader1
    //     vm.startPrank(trader1);
    //     uint256 redeemed1 = pnpFactory.redeemPosition(conditionId);
    //     assertGt(redeemed1, 0, "Trader 1 redeemed 0");
    //     assertEq(usdc.balanceOf(trader1), trader1UsdcBefore + redeemed1, "Trader 1 USDC balance incorrect");
    //     assertEq(pnpFactory.balanceOf(trader1, yesTokenId), 0, "Trader 1 YES tokens not burned");
    //     vm.stopPrank();

    //     // Redeem for trader3
    //     vm.startPrank(trader3);
    //     uint256 redeemed3 = pnpFactory.redeemPosition(conditionId);
    //     assertGt(redeemed3, 0, "Trader 3 redeemed 0");
    //     assertEq(usdc.balanceOf(trader3), trader3UsdcBefore + redeemed3, "Trader 3 USDC balance incorrect");
    //     assertEq(pnpFactory.balanceOf(trader3, yesTokenId), 0, "Trader 3 YES tokens not burned");
    //     vm.stopPrank();
        
    //     // Redeem for marketCreator
    //     vm.startPrank(marketCreator);
    //     uint256 redeemedMC = pnpFactory.redeemPosition(conditionId);
    //     assertGt(redeemedMC, 0, "Market Creator redeemed 0");
    //     assertEq(usdc.balanceOf(marketCreator), marketCreatorUsdcBefore + redeemedMC, "Market Creator USDC balance incorrect");
    //     assertEq(pnpFactory.balanceOf(marketCreator, yesTokenId), 0, "Market Creator YES tokens not burned");
    //     vm.stopPrank();

    //     // Verify NO token holders can't redeem
    //     vm.startPrank(trader2);
    //     vm.expectRevert("No winning tokens to redeem");
    //     pnpFactory.redeemPosition(conditionId);
    //     vm.stopPrank();

    //     // Check factory's USDC balance after all redemptions
    //     uint256 totalRedeemedCollateral = redeemed1 + redeemed3 + redeemedMC;
    //     assertEq(usdc.balanceOf(address(pnpFactory)), factoryUsdcBeforeRedeem - totalRedeemedCollateral, "Factory USDC balance incorrect after redemptions");
        
    //     // Check market reserve after redemptions. It should be close to 0.
    //     // (marketReserve[conditionId] * userBalance) / totalSupplyWinningToken
    //     // Since all winning tokens are burned, totalSupply(yesTokenId) becomes 0 for new calculations.
    //     // The remaining reserve in pnpFactory.marketReserve(conditionId) should be what corresponds to NO tokens or any dust.
    //     // The total redeemed collateral (in original token decimals) should correspond to the marketReserveAtEnd (in 18 decimals).
    //     assertApproxEqAbs(pnpFactory.scaleTo18Decimals(totalRedeemedCollateral, usdc.decimals()), marketReserveAtEnd, 1, "Total redeemed collateral doesn't match initial total reserve");
    //     // After all winning tokens are redeemed and burned, the pnpFactory.marketReserve(conditionId) should ideally be 0 or very small dust.
    //     // The logic in redeemPosition is: marketReserve[conditionId] = marketReserve[conditionId] - scaledReserveToRedeem;
    //     // So it subtracts the winning portion. The remaining part belongs to the "house" or losing tokens if they were not fully offset by fees.
    //     // Given the current model, the entire reserve should be claimable by winning token holders.
    //     assertEq(pnpFactory.marketReserve(conditionId), 0, "Market reserve not zero after all winning tokens redeemed");
    // }

    function test_settleMarket_reverts() public {
        vm.startPrank(marketCreator);
        conditionId =
            pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);

        vm.startPrank(pnpFactory.owner()); // Owner settles
        vm.expectRevert("Market ain't finished yet");
        pnpFactory.settleMarket(conditionId, yesTokenId);

        vm.warp(MARKET_END_TIME + 1);
        pnpFactory.settleMarket(conditionId, yesTokenId); // Settle once

        vm.expectRevert("Market already settled brother");
        pnpFactory.settleMarket(conditionId, yesTokenId); // Try to settle again
        vm.stopPrank();
    }

    function test_redeemPosition_reverts() public {
        vm.startPrank(marketCreator);
        conditionId =
            pnpFactory.createPredictionMarket(INITIAL_LIQUIDITY, address(usdc), MARKET_QUESTION, MARKET_END_TIME);
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);

        vm.startPrank(marketCreator);
        vm.expectRevert("Market not settled");
        pnpFactory.redeemPosition(conditionId);
        vm.stopPrank();

        vm.warp(MARKET_END_TIME + 1);
        vm.startPrank(pnpFactory.owner()); // Owner settles
        pnpFactory.settleMarket(conditionId, yesTokenId);
        vm.stopPrank();

        vm.startPrank(trader1); // trader1 has no winning tokens
        vm.expectRevert("No winning tokens to redeem");
        pnpFactory.redeemPosition(conditionId);
        vm.stopPrank();
    }

    function test_adminFunctions() public {
        uint256 newFee = 200; // 2%

        vm.startPrank(trader1); // Non-owner
        vm.expectRevert(); // Ownable's default revert message or specific one if OwnableUpgradeable is used
        pnpFactory.setTakeFee(newFee);
        vm.stopPrank();

        vm.prank(pnpFactory.owner());
        pnpFactory.setTakeFee(newFee);
        assertEq(pnpFactory.TAKE_FEE(), newFee);

        // Test fee limits
        vm.prank(pnpFactory.owner());
        vm.expectRevert("Invalid take fee");
        pnpFactory.setTakeFee(2001); // Above max
    }
}
