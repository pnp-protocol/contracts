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
        pnpFactory = new PNPFactory("https://api.perplexity.markets/{id}");

        // Fund users with USDC
        usdc.transfer(marketCreator, 100000 * 1e6);
        usdc.transfer(liquidityProvider, 100000 * 1e6);
        usdc.transfer(trader1, 100000 * 1e6);
        usdc.transfer(trader2, 100000 * 1e6);
        usdc.transfer(trader3, 100000 * 1e6);

        // Fund users with USDT
        usdt.transfer(marketCreator, 100000 * 1e6);
        usdt.transfer(liquidityProvider, 100000 * 1e6);

        // Fund users with DAI
        dai.transfer(marketCreator, 100000 * 1e18);
        dai.transfer(liquidityProvider, 100000 * 1e18);

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
        bytes32 marketId = pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );

        // Verify market creation
        assertTrue(pnpFactory.isMarketCreated(marketId));
        assertEq(pnpFactory.marketQuestion(marketId), MARKET_QUESTION);
        assertEq(pnpFactory.marketEndTime(marketId), MARKET_END_TIME);
        assertEq(pnpFactory.collateralToken(marketId), address(usdc));
        
        // Verify initial liquidity was split between YES and NO tokens
        uint256 yesTokenId = pnpFactory.getYesTokenId(marketId);
        uint256 noTokenId = pnpFactory.getNoTokenId(marketId);
        
        assertEq(pnpFactory.balanceOf(marketCreator, yesTokenId), INITIAL_LIQUIDITY * 1e12); // Scaled to 18 decimals
        assertEq(pnpFactory.balanceOf(marketCreator, noTokenId), INITIAL_LIQUIDITY * 1e12); // Scaled to 18 decimals
        
        vm.stopPrank();
    }

    function test_createPredictionMarket_withDifferentCollateral() public {
        vm.startPrank(marketCreator);
        
        // Create market with USDT (6 decimals)
        bytes32 marketId1 = pnpFactory.createPredictionMarket(
            5000 * 1e6, // 5k USDT
            address(usdt),
            "Will BTC reach $100k in 2024?",
            MARKET_END_TIME
        );
        
        // Create market with DAI (18 decimals)
        bytes32 marketId2 = pnpFactory.createPredictionMarket(
            2000 * 1e18, // 2k DAI
            address(dai),
            "Will SOL reach $200 in 2024?",
            MARKET_END_TIME + 30 days
        );
        
        // Verify markets were created
        assertTrue(pnpFactory.isMarketCreated(marketId1));
        assertTrue(pnpFactory.isMarketCreated(marketId2));
        
        // Verify reserves are correctly scaled
        assertEq(pnpFactory.marketReserve(marketId1), 5000 * 1e18); // USDT scaled to 18 decimals
        assertEq(pnpFactory.marketReserve(marketId2), 2000 * 1e18); // DAI already 18 decimals
        
        vm.stopPrank();
    }

    function test_createPredictionMarket_reverts() public {
        vm.startPrank(marketCreator);
        
        // Test invalid end time
        vm.expectRevert(abi.encodeWithSelector(
            PNPFactory.InvalidMarketEndTime.selector, 
            marketCreator, 
            block.timestamp - 1
        ));
        pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            block.timestamp - 1 // Past time
        );
        
        // Test zero collateral
        vm.expectRevert("Collateral must not be zero address");
        pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(0),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        
        // Test odd liquidity
        vm.expectRevert("Invalid liquidity");
        pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY + 1, // Odd number
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        
        vm.stopPrank();
    }

    function test_mintDecisionTokens() public {
        // First create a market
        vm.startPrank(marketCreator);
        conditionId = pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        uint256 noTokenId = pnpFactory.getNoTokenId(conditionId);
        
        // Provide liquidity by minting YES tokens
        vm.startPrank(liquidityProvider);
        uint256 mintAmount = 5000 * 1e6; // 5k USDC
        
        pnpFactory.mintDecisionTokens(conditionId, mintAmount, yesTokenId);
        
        // Verify tokens were minted
        uint256 yesTokensMinted = pnpFactory.balanceOf(liquidityProvider, yesTokenId);
        assertGt(yesTokensMinted, 0);
        
        // Verify reserve increased
        uint256 initialReserve = INITIAL_LIQUIDITY * 1e12; // Scaled to 18 decimals
        uint256 newReserve = pnpFactory.marketReserve(conditionId);
        assertGt(newReserve, initialReserve);
        
        // Mint NO tokens
        pnpFactory.mintDecisionTokens(conditionId, mintAmount, noTokenId);
        uint256 noTokensMinted = pnpFactory.balanceOf(liquidityProvider, noTokenId);
        assertGt(noTokensMinted, 0);
        
        vm.stopPrank();
    }

    function test_mintDecisionTokens_reverts() public {
        // First create a market
        vm.startPrank(marketCreator);
        conditionId = pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        uint256 noTokenId = pnpFactory.getNoTokenId(conditionId);
        
        // Test minting after market end time
        vm.warp(MARKET_END_TIME + 1);
        
        vm.startPrank(trader1);
        vm.expectRevert("Market trading stopped");
        pnpFactory.mintDecisionTokens(conditionId, 1000 * 1e6, yesTokenId);
        vm.stopPrank();
        
        // Test invalid token ID
        vm.warp(MARKET_END_TIME - 1); // Reset time
        
        vm.startPrank(trader1);
        vm.expectRevert(abi.encodeWithSelector(
            PNPFactory.InvalidTokenId.selector,
            trader1,
            12345
        ));
        pnpFactory.mintDecisionTokens(conditionId, 1000 * 1e6, 12345); // Invalid token ID
        vm.stopPrank();
    }

    function test_burnDecisionTokens() public {
        // First create a market and mint some tokens
        vm.startPrank(marketCreator);
        conditionId = pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        uint256 noTokenId = pnpFactory.getNoTokenId(conditionId);
        
        // Mint some YES tokens to burn
        vm.startPrank(liquidityProvider);
        uint256 mintAmount = 5000 * 1e6; // 5k USDC
        pnpFactory.mintDecisionTokens(conditionId, mintAmount, yesTokenId);
        uint256 yesTokensMinted = pnpFactory.balanceOf(liquidityProvider, yesTokenId);
        
        // Burn half of the minted tokens
        uint256 burnAmount = yesTokensMinted / 2;
        uint256 collateralReceived = pnpFactory.burnDecisionTokens(conditionId, yesTokenId, burnAmount);
        
        // Verify tokens were burned and collateral received
        assertEq(pnpFactory.balanceOf(liquidityProvider, yesTokenId), yesTokensMinted - burnAmount);
        assertGt(collateralReceived, 0);
        
        // Verify reserve decreased
        uint256 reserveAfterMint = pnpFactory.marketReserve(conditionId);
        pnpFactory.burnDecisionTokens(conditionId, yesTokenId, burnAmount);
        uint256 reserveAfterBurn = pnpFactory.marketReserve(conditionId);
        assertLt(reserveAfterBurn, reserveAfterMint);
        
        vm.stopPrank();
    }

    function test_burnDecisionTokens_reverts() public {
        // First create a market
        vm.startPrank(marketCreator);
        conditionId = pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        
        // Test burning after market end time
        vm.warp(MARKET_END_TIME + 1);
        
        vm.startPrank(marketCreator);
        vm.expectRevert("Market trading stopped");
        pnpFactory.burnDecisionTokens(conditionId, yesTokenId, 1000 * 1e18);
        vm.stopPrank();
        
        // Test burning more than balance
        vm.warp(MARKET_END_TIME - 1); // Reset time
        
        vm.startPrank(trader1);
        vm.expectRevert("Insufficient balance");
        pnpFactory.burnDecisionTokens(conditionId, yesTokenId, 1000 * 1e18);
        vm.stopPrank();
    }

    function test_settleAndRedeemMarket() public {
        // Create market and simulate trading
        vm.startPrank(marketCreator);
        conditionId = pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        uint256 noTokenId = pnpFactory.getNoTokenId(conditionId);
        
        // Simulate trading activity
        vm.startPrank(trader1);
        pnpFactory.mintDecisionTokens(conditionId, 2000 * 1e6, yesTokenId);
        vm.stopPrank();
        
        vm.startPrank(trader2);
        pnpFactory.mintDecisionTokens(conditionId, 3000 * 1e6, noTokenId);
        vm.stopPrank();
        
        vm.startPrank(trader3);
        pnpFactory.mintDecisionTokens(conditionId, 1000 * 1e6, yesTokenId);
        vm.stopPrank();
        
        // Fast forward to after market end time
        vm.warp(MARKET_END_TIME + 1);
        
        // Settle market with YES as winning outcome
        vm.startPrank(marketCreator);
        uint256 winningTokenId = pnpFactory.settleMarket(conditionId, yesTokenId);
        assertEq(winningTokenId, yesTokenId);
        assertTrue(pnpFactory.marketSettled(conditionId));
        assertEq(pnpFactory.winningTokenId(conditionId), yesTokenId);
        vm.stopPrank();
        
        // Redeem positions
        uint256 trader1YesBalance = pnpFactory.balanceOf(trader1, yesTokenId);
        uint256 trader3YesBalance = pnpFactory.balanceOf(trader3, yesTokenId);
        
        uint256 trader1Before = usdc.balanceOf(trader1);
        uint256 trader3Before = usdc.balanceOf(trader3);
        
        vm.startPrank(trader1);
        uint256 redeemed1 = pnpFactory.redeemPosition(conditionId);
        assertGt(redeemed1, 0);
        assertEq(usdc.balanceOf(trader1), trader1Before + redeemed1);
        vm.stopPrank();
        
        vm.startPrank(trader3);
        uint256 redeemed3 = pnpFactory.redeemPosition(conditionId);
        assertGt(redeemed3, 0);
        assertEq(usdc.balanceOf(trader3), trader3Before + redeemed3);
        vm.stopPrank();
        
        // Verify NO token holders can't redeem
        vm.startPrank(trader2);
        vm.expectRevert("No winning tokens to redeem");
        pnpFactory.redeemPosition(conditionId);
        vm.stopPrank();
    }

    function test_settleMarket_reverts() public {
        // Create market
        vm.startPrank(marketCreator);
        conditionId = pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        
        // Try to settle before end time
        vm.expectRevert("Market ain't finished yet");
        pnpFactory.settleMarket(conditionId, yesTokenId);
        
        // Fast forward to after market end time
        vm.warp(MARKET_END_TIME + 1);
        
        // Settle once
        pnpFactory.settleMarket(conditionId, yesTokenId);
        
        // Try to settle again
        vm.expectRevert("Market already settled brother");
        pnpFactory.settleMarket(conditionId, yesTokenId);
    }

    function test_redeemPosition_reverts() public {
        // Create market
        vm.startPrank(marketCreator);
        conditionId = pnpFactory.createPredictionMarket(
            INITIAL_LIQUIDITY,
            address(usdc),
            MARKET_QUESTION,
            MARKET_END_TIME
        );
        vm.stopPrank();

        uint256 yesTokenId = pnpFactory.getYesTokenId(conditionId);
        
        // Try to redeem before settlement
        vm.startPrank(marketCreator);
        vm.expectRevert("Market not settled");
        pnpFactory.redeemPosition(conditionId);
        vm.stopPrank();
        
        // Fast forward and settle
        vm.warp(MARKET_END_TIME + 1);
        pnpFactory.settleMarket(conditionId, yesTokenId);
        
        // Try to redeem with no winning tokens
        vm.startPrank(trader1);
        vm.expectRevert("No winning tokens to redeem");
        pnpFactory.redeemPosition(conditionId);
        vm.stopPrank();
    }

    function test_adminFunctions() public {
        // Test fee change
        uint256 newFee = 200; // 2%
        
        vm.startPrank(trader1);
        vm.expectRevert();
        pnpFactory.setTakeFee(newFee);
        vm.stopPrank();
        
        vm.prank(pnpFactory.owner());
        pnpFactory.setTakeFee(newFee);
        assertEq(pnpFactory.TAKE_FEE(), newFee);
    }
}