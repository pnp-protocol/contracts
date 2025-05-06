// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFactory {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PNP_MarketCreated(bytes32 indexed conditionId, address indexed marketCreator);
    event PNP_DecisionTokensMinted(
        bytes32 indexed conditionId, uint256 tokenId, address indexed minter, uint256 amount
    );
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
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createPredictionMarket(
        uint256 _initialLiquidity,
        address _collateralToken,
        string memory _question,
        uint256 _endTime
    ) external returns (bytes32);

    function mintDecisionTokens(bytes32 conditionId, uint256 collateralAmount, uint256 tokenIdToMint)
        external
        returns (uint256);

    function burnDecisionTokens(bytes32 conditionId, uint256 tokenIdToBurn, uint256 tokensToBurn)
        external
        returns (uint256);

    function settleMarket(bytes32 conditionId, uint256 _winningTokenId) external returns (uint256);

    function redeemPosition(bytes32 conditionId) external returns (uint256);

    function setTakeFee(uint256 _takeFee) external;

    /*//////////////////////////////////////////////////////////////
                               PUBLIC GETTERS
    //////////////////////////////////////////////////////////////*/

    function getMarketEndTime(bytes32 conditionId) external view returns (uint256);
    function getYesTokenId(bytes32 conditionId) external pure returns (uint256);
    function getNoTokenId(bytes32 conditionId) external pure returns (uint256);

    // Mapping view functions
    function marketQuestion(bytes32 conditionId) external view returns (string memory);
    function marketEndTime(bytes32 conditionId) external view returns (uint256);
    function isMarketCreated(bytes32 conditionId) external view returns (bool);
    function marketSettled(bytes32 conditionId) external view returns (bool);
    function marketReserve(bytes32 conditionId) external view returns (uint256);
    function collateralToken(bytes32 conditionId) external view returns (address);
    function winningTokenId(bytes32 conditionId) external view returns (uint256);
    function TAKE_FEE() external view returns (uint256);
}
