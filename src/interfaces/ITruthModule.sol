// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

interface ITruthModule {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    function settle(bytes32 conditionId, uint256 targetPrice, address pool) external returns (uint256 winningTokenId);
}
