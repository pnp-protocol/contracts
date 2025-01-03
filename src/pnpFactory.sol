// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// oz imports
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// bonding curve
import {PythagoreanBondingCurve} from "./libraries/PythagoreanBondingCurve.sol";

// interfaces
import {ITruthModule} from "./interfaces/ITruthModule.sol";

contract PNPFactory is ERC1155Supply, Ownable, ReentrancyGuard {
    // State variables

    /// @dev Maps conditionId of a market to the truth module used
    mapping(bytes32 => uint8) public moduleTypeUsed;

    /// @dev Maps moduleId to the corresponding truth module address
    mapping(uint8 => address) public moduleAddress;

    /// @dev Maps conditionId of a market to the market parameters
    mapping(bytes32 => uint256[]) public marketParams;

    mapping(bytes32 => bool) public marketSettled;

    // Mapping to track market reserves for each conditionId
    mapping(bytes32 => uint256) public marketReserve;

    mapping(bytes32 => address) public collateralToken;

    mapping(bytes32 => uint256) public winningTokenId;

    mapping(bytes32 => address) public conditionIdToPool;

    uint256 constant DECISION_TOKEN_DECIMALS = 18;

    uint256 public  TAKE_FEE = 100; // take 1% fees ( in bps )

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PnpMarketCreated(bytes32 indexed conditionId, address indexed marketCreator);
    event DecisionTokensMinted(bytes32 indexed conditionId, uint256 tokenId, address indexed minter, uint256 amount);
    event DecisionTokenBurned(bytes32 indexed conditionId, uint256 tokenId, address indexed burner, uint256 amount);
    event PositionRedeemed(address indexed user, bytes32 indexed conditionId, uint256 amount);
    event MarketSettled(bytes32 indexed conditionId, uint256 winningTokenId, address indexed user);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidMarketEndTime(address marketCreator, uint256 endTime);
    error MarketTradingStopped();
    error InvalidAddress(address addr);
    error InvalidTokenId(address  addr, uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(string memory uri) ERC1155(uri) Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                               PUBLIC FUNCTIONS
                             - createPredictionMarket
                             - mintDecisionTokens
                             - burnDecisionTokens
                             - settleMarket
                             - redeemPosition
    //////////////////////////////////////////////////////////////*/

    // @TODO : Change marketParams to a struct later as per needs
    /// @param _marketParams[0] : Market end timestamp
    /// @param _marketParams[1] : target price for `_tokenInQuestion`
    /// @param _initialLiquidity : initial liquidity in `_marketParams[0]` denomination
    /// @param _tokenInQuestion : address of the token in question
    /// every general market can be linked to a token performance
    /// @param _moduleId : id of the truth module
    /// @dev moduleId 0 for token volatality settlement
    /// @dev need to approve this contract of _collateral

    // _collateral is USDT/USDC for now
    function createPredictionMarket(
        uint256 _initialLiquidity,
        address _tokenInQuestion,
        uint8 _moduleId,
        address _collateralToken,
        uint256[] memory _marketParams,
        address _pool
    ) external nonReentrant returns (bytes32) {
        require(_initialLiquidity % 2 == 0 && _initialLiquidity != 0, "Invalid liquidity");

        require(_collateralToken != address(0), "Collateral must not be zero address");
        if (_marketParams[0] <= block.timestamp) {
            revert InvalidMarketEndTime(msg.sender, _marketParams[0]);
        }

        // Get collateral token decimals
        uint256 collateralDecimals = IERC20Metadata(_collateralToken).decimals();

        // Scale initial liquidity to 18 decimals consistently
        uint256 scaledLiquidity = scaleTo18Decimals(_initialLiquidity, collateralDecimals);

        // Transfer the actual token amount (unscaled)
        IERC20Metadata(_collateralToken).transferFrom(msg.sender, address(this), _initialLiquidity);

        bytes32 conditionId = keccak256(abi.encodePacked(_tokenInQuestion, _marketParams));

        // Store market parameters with scaled liquidity
        moduleTypeUsed[conditionId] = _moduleId;
        marketParams[conditionId] = _marketParams;
        marketSettled[conditionId] = false;
        marketReserve[conditionId] = scaledLiquidity; // Store scaled liquidity
        collateralToken[conditionId] = _collateralToken;
        conditionIdToPool[conditionId] = _pool;

        uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));

        // Mint tokens with scaled amounts
        _mint(msg.sender, yesTokenId, scaledLiquidity, "");
        _mint(msg.sender, noTokenId, scaledLiquidity, "");

        emit PnpMarketCreated(conditionId, msg.sender);
        return conditionId;
    }

    function scaleTo18Decimals(uint256 amount, uint256 tokenDecimals) internal pure returns (uint256) {
        return (amount * 10 ** 18) / 10 ** tokenDecimals;
    }

    function scaleFrom18Decimals(uint256 amount, uint256 tokenDecimals) internal pure returns (uint256) {
        return (amount * 10 ** tokenDecimals) / 10 ** 18;
    }

    function mintDecisionTokens(bytes32 conditionId, uint256 collateralAmount, uint256 tokenIdToMint)
        public
        nonReentrant
    {
        require(collateralAmount > 0, "Invalid collateral amount");       
        if (block.timestamp > marketParams[conditionId][0]) {
            revert MarketTradingStopped();
        }

        uint256 collateralDecimals = IERC20Metadata(collateralToken[conditionId]).decimals();

        // Scale collateral amount to 18 decimals
        uint256 scaledFullAmount = scaleTo18Decimals(collateralAmount, collateralDecimals);

        // Calculate fee and scale it
        uint256 amountAfterFee = (collateralAmount * (10000 - TAKE_FEE)) / 10000;
        uint256 scaledAmount = scaleTo18Decimals(amountAfterFee, collateralDecimals);

        uint256 scaledReserve = marketReserve[conditionId];

        uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));

        uint256 yesSupply = totalSupply(yesTokenId);
        uint256 noSupply = totalSupply(noTokenId);

        uint256 tokensToMint;
        if (tokenIdToMint == yesTokenId) {
            tokensToMint = PythagoreanBondingCurve.getTokensToMint(scaledReserve, yesSupply, noSupply, scaledAmount);
        } else if (tokenIdToMint == noTokenId) {
            tokensToMint = PythagoreanBondingCurve.getTokensToMint(scaledReserve, noSupply, yesSupply, scaledAmount);
        }
        else {
            revert InvalidTokenId(msg.sender,tokenIdToMint);
        }

        // Transfer unscaled amount
        IERC20(collateralToken[conditionId]).transferFrom(msg.sender, address(this), collateralAmount);

        // Update reserve with scaled amount
        marketReserve[conditionId] = scaledReserve + scaledFullAmount;

        // Mint decision tokens (already in 18 decimals)
        _mint(msg.sender, tokenIdToMint, tokensToMint, "");

        emit DecisionTokensMinted(conditionId, tokenIdToMint, msg.sender, tokensToMint);
    }

    function burnDecisionTokens(bytes32 conditionId, uint256 tokenIdToBurn, uint256 tokensToBurn) public nonReentrant {
        if (block.timestamp > marketParams[conditionId][0]) {
            revert MarketTradingStopped();
        }
        require(tokensToBurn > 0, "Invalid amount");

        require(balanceOf(msg.sender, tokenIdToBurn) >= tokensToBurn, "Insufficient balance");

        uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));

        uint256 yesSupply = totalSupply(yesTokenId);
        uint256 noSupply = totalSupply(noTokenId);

        uint256 scaledReserve = marketReserve[conditionId];

        uint256 reserveToRelease;
        if (tokenIdToBurn == yesTokenId) {
            reserveToRelease =
                PythagoreanBondingCurve.getReserveToRelease(scaledReserve, yesSupply, noSupply, tokensToBurn);
        } else {
            reserveToRelease =
                PythagoreanBondingCurve.getReserveToRelease(scaledReserve, noSupply, yesSupply, tokensToBurn);
        }

        // Scale down reserve before transfer
        uint256 collateralDecimals = IERC20Metadata(collateralToken[conditionId]).decimals();
        uint256 unscaledReserve = scaleFrom18Decimals(reserveToRelease, collateralDecimals);

        // Burn tokens first (safety first!)
        _burn(msg.sender, tokenIdToBurn, tokensToBurn);

        // Update scaled reserve
        marketReserve[conditionId] = scaledReserve - reserveToRelease;

        // Transfer unscaled amount
        IERC20(collateralToken[conditionId]).transfer(msg.sender, unscaledReserve);

        emit DecisionTokenBurned(conditionId, tokenIdToBurn, msg.sender, tokensToBurn);
    }

    // Function to settle the market
    function settleMarket(bytes32 conditionId) public returns (uint256) {
        require(!marketSettled[conditionId], "Market already settled brother");

        // Derive the module address
        address moduleAddr = moduleAddress[moduleTypeUsed[conditionId]];

        // Call the settle function from the ITruthModule interface
        // @TODO : Add a return check if fetching uniV3 Pool fails
        uint256 settledWinningTokenId =
            ITruthModule(moduleAddr).settle(conditionId, marketParams[conditionId][1], conditionIdToPool[conditionId]);

        // Store the winning token ID and mark the market as settled
        winningTokenId[conditionId] = settledWinningTokenId;
        marketSettled[conditionId] = true;
        emit MarketSettled(conditionId, settledWinningTokenId, msg.sender);
        return settledWinningTokenId;    
    }

    // Function to redeem position
    function redeemPosition(bytes32 conditionId) public {
        require(marketSettled[conditionId], "Market not settled");

        uint256 userBalance = balanceOf(msg.sender, winningTokenId[conditionId]);
        require(userBalance > 0, "No winning tokens to redeem");

        uint256 totalSupplyWinningToken = totalSupply(winningTokenId[conditionId]);

        // Both userBalance and marketReserve are in 18 decimals
        uint256 scaledReserveToRedeem = (userBalance * marketReserve[conditionId]) / totalSupplyWinningToken;
        require(scaledReserveToRedeem > 0, "No reserves to redeem");

        // Scale down to collateral token decimals before transfer
        uint256 collateralDecimals = IERC20Metadata(collateralToken[conditionId]).decimals();
        uint256 reserveToRedeem = scaleFrom18Decimals(scaledReserveToRedeem, collateralDecimals);

        IERC20(collateralToken[conditionId]).transfer(msg.sender, reserveToRedeem);

        emit PositionRedeemed(msg.sender, conditionId, reserveToRedeem);
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Function to set module addresses, restricted to the contract owner
    function setModuleAddress(uint8 moduleType, address moduleAddr) external onlyOwner {
        require(moduleAddr != address(0), "Invalid address");
        require(moduleAddress[moduleType] == address(0), "Module already set");
        moduleAddress[moduleType] = moduleAddr;
    }

    function setTakeFee(uint256 _takeFee) external onlyOwner {
        TAKE_FEE = _takeFee;
    }

    

}

// @TODO : Add comprehensive validation for all market parameters
// @TODO : Consider implementing a timelock or multi-sig for critical parameter changes
