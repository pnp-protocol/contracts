# PNPFactory Prediction Market Design Overview

## Introduction

These set of smart contracts allows users to create, participate in, and settle binary prediction markets based on real-world events. 
It leverages a unique Pythagorean Bonding Curve mechanism for automated market making and uses ERC-1155 tokens to represent outcome shares (YES/NO tokens).

## Core Concepts

1.  **Market Creation**: Anyone can create a new prediction market by providing an initial liquidity amount in a specified ERC20 collateral token (like USDC or USDT), defining the market question, and setting an end time. The initial liquidity provider receives the first set of YES and NO outcome tokens.
2.  **Collateral & Scaling**: The system uses a designated ERC20 token as collateral. All internal calculations involving reserves and token supplies are scaled to 18 decimals to ensure consistent precision, regardless of the collateral token's decimals. Helper functions (`scaleTo18Decimals`, `scaleFrom18Decimals`) manage this conversion.
3.  **Outcome Tokens (ERC-1155)**: Each market has two corresponding outcome tokens (YES and NO) implemented as ERC-1155 tokens. The `tokenId` for each is deterministically generated based on the market's unique `conditionId` and the outcome ("YES" or "NO").
4.  **Pythagorean Bonding Curve**: The heart of the market maker. It dynamically calculates the number of outcome tokens to mint when collateral is added, or the amount of collateral to return when outcome tokens are burned. The curve maintains a relationship between the total collateral reserve (R) and the supplies of YES (a) and NO (b) tokens, implicitly following \( R = c \sqrt{a^2 + b^2} \), where *c* is a constant derived from initial conditions. This ensures liquidity and determines prices based on supply and demand.
5.  **Minting & Burning**: Users can buy (mint) specific outcome tokens by providing collateral or sell (burn) their outcome tokens to receive collateral back. The `PythagoreanBondingCurve` library calculates the exact amounts for these operations. A small `TAKE_FEE` is applied during minting, contributing to the market's reserve pool, which ultimately benefits the holders of the winning outcome token.
6.  **Market Settlement**: Once the market's end time is reached, an authorized owner settles the market by specifying the winning outcome token's ID.
7.  **Redeeming Winnings**: Holders of the winning outcome token can redeem their tokens after settlement. They receive a proportional share of the final market reserve (including collected fees) based on their holdings of the winning token.

## `PNPFactory.sol` Key Functions

This contract manages the lifecycle of prediction markets.

```solidity
/// @notice Creates a new binary prediction market.
/// @param _initialLiquidity Initial collateral provided by the creator.
/// @param _collateralToken The ERC20 token used as collateral.
/// @param _question The text of the prediction market question.
/// @param _endTime The timestamp when market trading ends and settlement can occur.
/// @return conditionId A unique identifier for the created market.
function createPredictionMarket(
    uint256 _initialLiquidity,
    address _collateralToken,
    string memory _question,
    uint256 _endTime
) external nonReentrant returns (bytes32);

/// @notice Mints a specific outcome token (YES or NO) in exchange for collateral.
/// @param conditionId The unique identifier of the market.
/// @param collateralAmount The amount of collateral provided by the minter.
/// @param tokenIdToMint The ID of the outcome token (YES or NO) to mint.
function mintDecisionTokens(
    bytes32 conditionId,
    uint256 collateralAmount,
    uint256 tokenIdToMint
) public nonReentrant;

/// @notice Burns a specific outcome token (YES or NO) to receive collateral back.
/// @param conditionId The unique identifier of the market.
/// @param tokenIdToBurn The ID of the outcome token (YES or NO) to burn.
/// @param tokensToBurn The amount of the outcome token to burn.
/// @return The amount of collateral returned to the user.
function burnDecisionTokens(
    bytes32 conditionId,
    uint256 tokenIdToBurn,
    uint256 tokensToBurn
) public nonReentrant returns (uint256);

/// @notice Settles a market after its end time (Owner restricted).
/// @param conditionId The unique identifier of the market to settle.
/// @param _winningTokenId The ID of the outcome token determined to be the winner.
/// @return The winning token ID.
function settleMarket(
    bytes32 conditionId,
    uint256 _winningTokenId
) external onlyOwner returns (uint256);

/// @notice Allows users to redeem their holdings of the winning token for collateral after settlement.
/// @param conditionId The unique identifier of the settled market.
/// @return The amount of collateral redeemed by the user.
function redeemPosition(
    bytes32 conditionId
) public nonReentrant returns (uint256);

/// @notice Updates the fee charged on minting operations (Owner restricted).
/// @param _takeFee The new fee in basis points (e.g., 100 = 1%).
function setTakeFee(uint256 _takeFee) external onlyOwner;
```

## `PNPFactory.sol` Key Events

Events emitted by the contract to log significant actions.

```solidity
/// @notice Emitted when a new market is successfully created.
event PNP_MarketCreated(bytes32 indexed conditionId, address indexed marketCreator);

/// @notice Emitted when outcome tokens are minted.
event PNP_DecisionTokensMinted(bytes32 indexed conditionId, uint256 tokenId, address indexed minter, uint256 amount);

/// @notice Emitted when outcome tokens are burned.
event PNP_DecisionTokenBurned(bytes32 indexed conditionId, uint256 tokenId, address indexed burner, uint256 amount);

/// @notice Emitted when a user successfully redeems winning tokens.
event PNP_PositionRedeemed(address indexed user, bytes32 indexed conditionId, uint256 amount);

/// @notice Emitted when a market is settled by the owner.
event PNP_MarketSettled(bytes32 indexed conditionId, uint256 winningTokenId, address indexed user);

/// @notice Emitted when the minting fee is updated by the owner.
event PNP_TakeFeeUpdated(uint256 newTakeFee);
```

## `PythagoreanBondingCurve.sol` Library

This library provides the mathematical foundation for the automated market maker.

*   `getTokensToMint(r, a, b, l)`: Calculates how many tokens of outcome 'a' should be minted for providing 'l' amount of collateral, given current reserve 'r' and supplies 'a' and 'b'.
*   `getReserveToRelease(r, a, b, tokensToBurn)`: Calculates how much collateral 'r' should be returned for burning 'tokensToBurn' amount of outcome 'a', given supplies 'a' and 'b'.
*   `getPrice(r, a, b)`: Calculates the current instantaneous price of outcome token 'a' based on the reserve 'r' and supplies 'a' and 'b'.

This system provides a robust and decentralized platform for creating and participating in prediction markets.


## BASE SEPOLIA DEPLOYMENT

Chain 84532

PNPFactory deployed to: 0xB137dD28892Da8C0c6Aa93EB93f1Cf618bEB5CF2
Owner (deployer): 0xaF2E9429B2E8643dDA80844D8a08Dc9f630640bc

Minimum deposit while market creation + Minimum required liquidity for buying YES/NO  will be : 1 USDC 
( slightly greater than this )
