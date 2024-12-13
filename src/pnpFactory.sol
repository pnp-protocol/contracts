// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";




contract PNPFactory is ERC1155, Ownable, ReentrancyGuard {
    // State variables
    mapping(bytes32 => uint8) public moduleTypeUsed;
    mapping(bytes32 => uint256[]) public marketParams;
    mapping(bytes32 => bool) public marketSettled;

    // Events
    event PnpMarketCreated(bytes32 indexed conditionId);
    event MarketDecisionMinted(bytes32 indexed conditionId, uint256 tokenId, address indexed minter, uint256 amount);

    constructor() ERC1155("https://api.example.com/metadata/{id}") {}

    // Function to create a prediction market
    function createPredictionMarket(
        uint256 _initialLiquidity,
        address _tokenInQuestion,
        uint8 _moduleId,
        uint256[] memory _marketParams
    ) public nonReentrant returns (bytes32 conditionId) {
        require(_initialLiquidity % 2 == 0 && _initialLiquidity != 0, "Invalid liquidity");
        require(_marketParams[0] != address(0), "Collateral must not be zero address");
        require(_marketParams[1] > block.timestamp, "Market end time must be in the future");

        // Create conditionId
        conditionId = keccak256(abi.encodePacked(_tokenInQuestion, _moduleId, msg.sender));
        emit PnpMarketCreated(conditionId);

        // Initialize market parameters
        marketParams[conditionId] = _marketParams;
        // Additional logic for token minting and liquidity transfer...
    }

    // Function to mint decision tokens
    function mintDecisionTokens(bytes32 conditionId, uint256 collateralAmount, uint256 tokenIdToMint) public nonReentrant {
        // Logic for minting tokens...
        emit MarketDecisionMinted(conditionId, tokenIdToMint, msg.sender, collateralAmount);
    }

    // Function to burn decision tokens
    function burnDecisionTokens(bytes32 conditionId, uint256 tokenIdToBurn) public nonReentrant {
        // Logic for burning tokens...
    }

    // Additional functions for market execution and settling...
}
