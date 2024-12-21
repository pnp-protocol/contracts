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

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PnpMarketCreated(bytes32 indexed conditionId);
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
        if(_marketParams[0] <= block.timestamp) {
            revert InvalidMarketEndTime(msg.sender, _marketParams[0]);
        }

        // Get collateral token decimals
        uint256 collateralDecimals = IERC20Metadata(_collateralToken).decimals();
        
        // Scale initial liquidity to 18 decimals for consistent math
        // If USDC (6 decimals) sends 100 USDC, this converts to 100 * 10^18
        uint256 scaledLiquidity = (_initialLiquidity * 10**DECISION_TOKEN_DECIMALS) / 10**collateralDecimals;

        // Transfer the actual token amount (unscaled)
        IERC20Metadata(_collateralToken).transferFrom(msg.sender, address(this), _initialLiquidity);
        
        // Generate condition ID
        bytes32 conditionId = keccak256(abi.encodePacked(_tokenInQuestion, _marketParams));

        // Store market parameters
        moduleTypeUsed[conditionId] = _moduleId;
        marketParams[conditionId] = _marketParams;
        marketSettled[conditionId] = false;
        marketReserve[conditionId] = scaledLiquidity; // Store scaled liquidity
        collateralToken[conditionId] = _collateralToken;
        conditionIdToPool[conditionId] = _pool;

        // Derive token IDs for YES and NO
        uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));
        
        // Mint YES and NO tokens using scaled liquidity
        _mint(msg.sender, yesTokenId, scaledLiquidity, ""); // Mint YES tokens
        _mint(msg.sender, noTokenId, scaledLiquidity, ""); // Mint NO tokens

        emit PnpMarketCreated(conditionId); // Emit event for market creation
        return conditionId;
    }

    // Function to mint decision tokens
    function mintDecisionTokens(bytes32 conditionId, uint256 collateralAmount, uint256 tokenIdToMint) public nonReentrant {
        if(block.timestamp > marketParams[conditionId][0]) {
            revert MarketTradingStopped();
        }
        
        // Get collateral token decimals and scale amount
        uint256 collateralDecimals = IERC20Metadata(collateralToken[conditionId]).decimals();
        uint256 scaledAmount = (collateralAmount * 10**DECISION_TOKEN_DECIMALS) / 10**collateralDecimals;

        // Get current scaled reserves and supplies
        uint256 scaledReserve = marketReserve[conditionId];
        
        // Calculate token supplies (already in 18 decimals as we mint them that way)
        uint256 yesTokenId = uint256(keccak256(abi.encodePacked(conditionId, "YES")));
        uint256 noTokenId = uint256(keccak256(abi.encodePacked(conditionId, "NO")));
        
        uint256 yesSupply = totalSupply(yesTokenId);
        uint256 noSupply = totalSupply(noTokenId);

        uint256 tokensToMint;
        if (tokenIdToMint == yesTokenId) {
            tokensToMint = PythagoreanBondingCurve.getTokensToMint(
                scaledReserve,
                yesSupply,
                noSupply,
                scaledAmount
            );
        } else {
            tokensToMint = PythagoreanBondingCurve.getTokensToMint(
                scaledReserve,
                noSupply,
                yesSupply,
                scaledAmount
            );
        }

        // Transfer the actual token amount (unscaled)
        IERC20(collateralToken[conditionId]).transferFrom(msg.sender, address(this), collateralAmount);
        
        // Update scaled reserve
        marketReserve[conditionId] = scaledReserve + scaledAmount;
        
        // Mint the decision tokens (already in 18 decimals)
        _mint(msg.sender, tokenIdToMint, tokensToMint, "");

        emit DecisionTokensMinted(conditionId, tokenIdToMint, msg.sender, collateralAmount);
    }

    // Function to burn decision tokens
    function burnDecisionTokens(bytes32 conditionId, uint256 tokenIdToBurn, uint256 tokensToBurn) public nonReentrant {
        if(block.timestamp > marketParams[conditionId][0]) {
            revert MarketTradingStopped();
        }
        // check if balance of tokenIdToBurn is greater than tokensToBurn
        require(balanceOf(msg.sender, tokenIdToBurn) >= tokensToBurn, "Not enough tokens to burn");

        uint256 r = marketReserve[conditionId];
        uint256 a = totalSupply(tokenIdToBurn);
        uint256 b = totalSupply(tokenIdToBurn == uint256(keccak256(abi.encodePacked(conditionId, "YES"))) ? 
        uint256(keccak256(abi.encodePacked(conditionId, "NO"))) : 
        uint256(keccak256(abi.encodePacked(conditionId, "YES"))));

        uint256 reserveToRelease = PythagoreanBondingCurve.getReserveToRelease(r, a, b, tokenIdToBurn);

        // Burn the respective number of tokens from msg.sender
        _burn(msg.sender, tokenIdToBurn, tokensToBurn);

        // Transfer the reserve to msg.sender
        IERC20(collateralToken[conditionId]).transfer(msg.sender, reserveToRelease);

        // Update market reserve
        marketReserve[conditionId] -= reserveToRelease;

        emit DecisionTokenBurned(conditionId, tokenIdToBurn, msg.sender, tokensToBurn);
               
    }

    // Function to settle the market
    function settleMarket(bytes32 conditionId) public {
        require(!marketSettled[conditionId], "Market already settled brother"); 

        // Derive the module address
        address moduleAddr = moduleAddress[moduleTypeUsed[conditionId]];

        // Call the settle function from the ITruthModule interface
        uint256 settledWinningTokenId = ITruthModule(moduleAddr).settle(conditionId, marketParams[conditionId][1], conditionIdToPool[conditionId]);

        // Store the winning token ID and mark the market as settled
        winningTokenId[conditionId] = settledWinningTokenId;
        marketSettled[conditionId] = true;

        emit MarketSettled(conditionId, settledWinningTokenId, msg.sender);
    }

    // Function to redeem position
    function redeemPosition(bytes32 conditionId) public {
        require(winningTokenId[conditionId] != 0, "Market not settled");
        require(marketSettled[conditionId], "Market not settled");
        
        uint256 userBalance = balanceOf(msg.sender, winningTokenId[conditionId]);
        uint256 totalSupplyWinningToken = totalSupply(winningTokenId[conditionId]);
        
        uint256 reserveToRedeem = (userBalance * marketReserve[conditionId]) / totalSupplyWinningToken;
        
        require(reserveToRedeem > 0, "No reserves to redeem");
        
        IERC20(collateralToken[conditionId]).transfer(msg.sender, reserveToRedeem);

        emit PositionRedeemed(msg.sender, conditionId, reserveToRedeem);
    }

    // Function to set module addresses, restricted to the contract owner
    function setModuleAddress(uint8 moduleType, address moduleAddr) external onlyOwner {
        require(moduleAddr != address(0), "Invalid address");
        moduleAddress[moduleType] = moduleAddr;
    }
}
