// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITruthModule} from"./interfaces/ITruthModule.sol";

// for uniswap V3 Pools
contract PriceModule is ITruthModule {

    // Function to settle the market
    function settle(bytes32 conditionId, uint256[] memory _marketParams) external override returns (bytes32 winnin) {
        //  _winningTokenId = keccak256(abi.encodePacked(conditionId, _marketParams[0])); // Example logic

        return _winningTokenId;
    }

}