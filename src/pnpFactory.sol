// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// oz imports
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// bonding curve 
import {PythagoreanBondingCurve} from "./libraries/PythagoreanBondingCurve.sol";

abstract contract PNPFactory is ERC1155Supply, Ownable, ReentrancyGuard {

    // State variables

    /// @dev Maps conditionId of a market to the truth module used
    mapping(bytes32 => uint8) public moduleTypeUsed;

    /// @dev Maps conditionId of a market to the market parameters
    mapping(bytes32 => uint256[]) public marketParams;

    mapping(bytes32 => bool) public marketSettled;

    // Mapping to track market reserves for each conditionId
    mapping(bytes32 => uint256) public marketReserve;

    mapping(bytes32 => address) public collateralToken;

    // Events
    event PnpMarketCreated(bytes32 indexed conditionId);
    event MarketDecisionMinted(bytes32 indexed conditionId, uint256 tokenId, address indexed minter, uint256 amount);

    constructor() ERC1155Supply("httpxfs://api.example.com/metadata/{id}") {}


    // @TODO : Change marketParams to a struct later as per needs
    /// @param _marketParams[0] : Market end timestamp
    /// @param _marketParams[1] : target price for `_tokenInQuestion`
    /// @param _initialLiquidity : initial liquidity in `_marketParams[0]` denomination
    /// @param _tokenInQuestion : address of the token in question 
    /// every general market can be linked to a token performance
    /// @param _moduleId : id of the truth module
    /// @dev moduleId 0 for token volatality settlement
    function createPredictionMarket(
        uint256 _initialLiquidity,
        address _tokenInQuestion,
        uint8 _moduleId,
        address _collateral,
        uint256[] memory _marketParams
    ) public nonReentrant returns (bytes32 conditionId) {
        require(_initialLiquidity % 2 == 0 && _initialLiquidity != 0, "Invalid liquidity");
        require(_collateral != address(0), "Collateral must not be zero address");
        require(_marketParams[0] > block.timestamp, "Market end time must be in the future");

        // Create conditionId based on market parameters
        conditionId = keccak256(abi.encodePacked(_tokenInQuestion, _marketParams));

        // Transfer initial liquidity from sender to contract
        IERC20(_collateral).transferFrom(msg.sender, address(this), _initialLiquidity);

        // Update market reserve with the transferred liquidity
        marketReserve[conditionId] = _initialLiquidity;

        // Initialize market parameters with the new conditionId
        marketParams[conditionId] = _marketParams;

        // Store the module type used for this market
        moduleTypeUsed[conditionId] = _moduleId;

        collateralToken[conditionId] = _collateral;

        // Derive token IDs for YES and NO
        bytes32 yesTokenId = keccak256(abi.encodePacked(conditionId, "YES"));
        bytes32 noTokenId = keccak256(abi.encodePacked(conditionId, "NO"));

        // Mint YES and NO tokens to the sender
        _mint(msg.sender, yesTokenId, _initialLiquidity / 2, ""); // Mint YES tokens
        _mint(msg.sender, noTokenId, _initialLiquidity / 2, ""); // Mint NO tokens

        emit PnpMarketCreated(conditionId); // Emit event for market creation
    }

    // Function to mint decision tokens
    function mintDecisionTokens(bytes32 conditionId, uint256 collateralAmount, uint256 tokenIdToMint) public nonReentrant {
        require(block.timestamp < marketParams[conditionId][0], "Market has expired");
        
        uint256 r = marketReserve[conditionId];
        uint256 a = totalSupply(tokenIdToMint);
        uint256 b = totalSupply(tokenIdToMint == keccak256(abi.encodePacked(conditionId, "YES")) ? keccak256(abi.encodePacked(conditionId, "NO")) : keccak256(abi.encodePacked(conditionId, "YES")));

        uint256 tokensToMint = PythagoreanBondingCurve.getTokensToMint(r, a, b, collateralAmount);

        // Transfer collateralAmount from msg.sender to the contract
        IERC20(collateralToken[conditionId]).transferFrom(msg.sender, address(this), collateralAmount);

        // Mint the respective number of tokens to msg.sender
        _mint(msg.sender, tokenIdToMint, tokensToMint, "");

        emit MarketDecisionMinted(conditionId, tokenIdToMint, msg.sender, collateralAmount);
    }

    // Function to burn decision tokens
    function burnDecisionTokens(bytes32 conditionId, uint256 tokenIdToBurn) public nonReentrant {
        
    }

    // Additional functions for market execution and settling...
}
