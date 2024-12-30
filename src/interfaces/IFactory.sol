// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFactory {
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

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function createPredictionMarket(
        uint256 _initialLiquidity,
        address _tokenInQuestion,
        uint8 _moduleId,
        address _collateralToken,
        uint256[] memory _marketParams,
        address _pool
    ) external returns (bytes32);

    function mintDecisionTokens(bytes32 conditionId, uint256 tokenIdToMint, uint256 tokensToMint) external;

    function burnDecisionTokens(bytes32 conditionId, uint256 tokenIdToBurn, uint256 tokensToBurn) external;

    function settleMarket(bytes32 conditionId) external;

    function redeemPosition(bytes32 conditionId, uint256 amount) external;

    // View functions--Mappings
    function moduleTypeUsed(bytes32 conditionId) external view returns (uint8);
    function moduleAddress(uint8 moduleId) external view returns (address);
    function marketParams(bytes32 conditionId) external view returns (uint256[] memory);
    function marketSettled(bytes32 conditionId) external view returns (bool);
    function marketReserve(bytes32 conditionId) external view returns (uint256);
    function collateralToken(bytes32 conditionId) external view returns (address);
    function winningTokenId(bytes32 conditionId) external view returns (uint256);
    function conditionIdToPool(bytes32 conditionId) external view returns (address);
}