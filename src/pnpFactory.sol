// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ██████╗░███╗░░██╗██████╗░  ██████╗░██████╗░░█████╗░████████╗░█████╗░░█████╗░░█████╗░██╗░░░░░
// ██╔══██╗████╗░██║██╔══██╗  ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██║░░░░░
// ██████╔╝██╔██╗██║██████╔╝  ██████╔╝██████╔╝██║░░██║░░░██║░░░██║░░██║██║░░╚═╝██║░░██║██║░░░░░
// ██╔═══╝░██║╚████║██╔═══╝░  ██╔═══╝░██╔══██╗██║░░██║░░░██║░░░██║░░██║██║░░██╗██║░░██║██║░░░░░
// ██║░░░░░██║░╚███║██║░░░░░  ██║░░░░░██║░░██║╚█████╔╝░░░██║░░░╚█████╔╝╚█████╔╝╚█████╔╝███████╗
// ╚═╝░░░░░╚═╝░░╚══╝╚═╝░░░░░  ╚═╝░░░░░╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░░╚════╝░░╚════╝░░╚════╝░╚══════╝

// oz imports
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// bonding curve
import {PythagoreanBondingCurve} from "./libraries/PythagoreanBondingCurve.sol";

contract PNPFactory is ERC1155Supply, Ownable, ReentrancyGuard {

    /// @dev market question
    mapping ( bytes32 => string) public marketQuestion;

    /// @dev end time for the market ( compared to block.timestamp )
    mapping ( bytes32 => uint256) public marketEndTime;

    /// @dev true if market exists
    mapping(bytes32 => bool) public isMarketCreated;

    /// @dev Checked when redeeming and set when settling a market
    mapping(bytes32 => bool) public marketSettled;

    // Mapping to track market reserves for each conditionId
    /// @dev marketReserve is scaled to 18 Decimals nmw the collateral
    mapping(bytes32 => uint256) public marketReserve;

    /// @dev Usually USDC or USDT
    mapping(bytes32 => address) public collateralToken;

    /// @dev uint256(keccak256(abi.encodePacked(conditionId, "YES" | "NO" )));
    mapping(bytes32 => uint256) public winningTokenId;

    
    /// @dev YES | NO tokens are scaled with 18 decimals
    uint256 constant DECISION_TOKEN_DECIMALS = 18;

    /// @dev Charged when minting
    /// @dev Fees goes to winning token holders
    /// @dev To become LP, buy both YES and NO tokens to be eligible for claimable fees
    uint256 public TAKE_FEE = 100; // take 1% fees ( in bps )

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PNP_MarketCreated(bytes32 indexed conditionId, address indexed marketCreator);
    event PNP_DecisionTokensMinted(bytes32 indexed conditionId, uint256 tokenId, address indexed minter, uint256 amount);
    event PNP_DecisionTokenBurned(bytes32 indexed conditionId, uint256 tokenId, address indexed burner, uint256 amount);
    event PNP_PositionRedeemed(address indexed user, bytes32 indexed conditionId, uint256 amount);
    event PNP_MarketSettled(bytes32 indexed conditionId, uint256 winningTokenId, address indexed user);


    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidMarketEndTime(address marketCreator, uint256 endTime);
    error MarketTradingStopped();
    error InvalidAddress(address addr);
    error InvalidTokenId(address addr, uint256 tokenId);

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

    /// @param _initialLiquidity : initial liquidity in `_marketParams[0]` denomination
    /// @param _collateralToken : collateral token used for market 
    /// @dev need to approve this contract of _collateral

    // _collateral is USDT/USDC for now
    // perplexity markets only binary markets for now [ change bonding curve for multioutcomes support ]
    // other params
    // string _question 
    // YES and NO for now only
    // uint256 end time
    function createPredictionMarket(
        uint256 _initialLiquidity,
        address _collateralToken,
        string memory _question,
        uint256 _endTime
    ) external nonReentrant returns (bytes32) {
        // need to split IL to outcome1 outcome2 YES NO for now
        require(_initialLiquidity % 2 == 0 && _initialLiquidity != 0, "Invalid liquidity");

        // fuck u address 0 useless bitch
        require(_collateralToken != address(0), "Collateral must not be zero address");

        // valid endTime for market
        if (_endTime <= block.timestamp) {
            revert InvalidMarketEndTime(msg.sender, _endTime);
        }

        // Get collateral token decimals
        uint256 collateralDecimals = IERC20Metadata(_collateralToken).decimals();

        // Scale initial liquidity to 18 decimals consistently
        uint256 scaledLiquidity = scaleTo18Decimals(_initialLiquidity, collateralDecimals);

        // Transfer the actual token amount (unscaled) to this contract
        IERC20Metadata(_collateralToken).transferFrom(msg.sender, address(this), _initialLiquidity);

        bytes32 conditionId = keccak256(abi.encodePacked(_question, _endTime));
        require(!isMarketCreated[conditionId], "Market already created");

        // Store market parameters with scaled liquidity
        marketQuestion[conditionId] = _question;
        marketEndTime[conditionId] = _endTime;
        marketReserve[conditionId] = scaledLiquidity; // Store scaled liquidity
        collateralToken[conditionId] = _collateralToken;

        uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));

        // Mint tokens with scaled amounts
        _mint(msg.sender, yesTokenId, scaledLiquidity, "");
        _mint(msg.sender, noTokenId, scaledLiquidity, "");

        emit PNP_MarketCreated(conditionId, msg.sender);
        return conditionId;
    }


    function mintDecisionTokens(bytes32 conditionId, uint256 collateralAmount, uint256 tokenIdToMint)
        public
        nonReentrant
    {
        require(collateralAmount > 0, "Invalid collateral amount");
        require(isMarketCreated[conditionId], "Market doesn't exist");
        require(block.timestamp <= marketEndTime[conditionId], "Market trading stopped");

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
        } else {
            revert InvalidTokenId(msg.sender, tokenIdToMint);
        }

        // Transfer unscaled amount
        IERC20(collateralToken[conditionId]).transferFrom(msg.sender, address(this), collateralAmount);
        // Update reserve with scaled amount
        marketReserve[conditionId] = scaledReserve + scaledFullAmount;

        // Mint decision tokens (already in 18 decimals)
        _mint(msg.sender, tokenIdToMint, tokensToMint, "");

        emit PNP_DecisionTokensMinted(conditionId, tokenIdToMint, msg.sender, tokensToMint);
    }

    function burnDecisionTokens(bytes32 conditionId, uint256 tokenIdToBurn, uint256 tokensToBurn)
        public
        nonReentrant
        returns (uint256)
    {
        require(isMarketCreated[conditionId], "Market doesn't exist");
        require(block.timestamp <= marketEndTime[conditionId], "Market trading stopped");
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

        emit PNP_DecisionTokenBurned(conditionId, tokenIdToBurn, msg.sender, tokensToBurn);
        return unscaledReserve;
    }

    // Function to settle price markets
    // called by script only
    function settleMarket(bytes32 conditionId, uint256 _winningTokenId) public returns (uint256) {
        require(block.timestamp > marketEndTime[conditionId], "Market ain't finished yet");
        require(!marketSettled[conditionId], "Market already settled brother");

        uint256 settledWinningTokenId = _winningTokenId;
        
        // Store the winning token ID and mark the market as settled
        winningTokenId[conditionId] = settledWinningTokenId;
        marketSettled[conditionId] = true;
        emit PNP_MarketSettled(conditionId, settledWinningTokenId, msg.sender);
        return settledWinningTokenId;
    }

    
    // Function to redeem position
    function redeemPosition(bytes32 conditionId) public returns (uint256) {
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

        emit PNP_PositionRedeemed(msg.sender, conditionId, reserveToRedeem);
        return reserveToRedeem;
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setTakeFee(uint256 _takeFee) external onlyOwner {
        TAKE_FEE = _takeFee;
    }

    /*//////////////////////////////////////////////////////////////
                               PUBLIC GETTERS
    //////////////////////////////////////////////////////////////*/

    function getMarketEndTime(bytes32 conditionId) public view returns (uint256) {
        return marketEndTime[conditionId];
    }

    function getYesTokenId(bytes32 conditionId) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(conditionId, "YES")));
    }

    function getNoTokenId(bytes32 conditionId) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(conditionId, "NO")));
    }

    function scaleTo18Decimals(uint256 amount, uint256 tokenDecimals) internal pure returns (uint256) {
        return (amount * 10 ** 18) / 10 ** tokenDecimals;
    }

    function scaleFrom18Decimals(uint256 amount, uint256 tokenDecimals) internal pure returns (uint256) {
        return (amount * 10 ** tokenDecimals) / 10 ** 18;
    }

}


