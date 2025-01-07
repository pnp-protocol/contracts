// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

interface ITruthModule {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    function settle(bytes32 conditionId, address tokenInQuestion, uint256 targetPrice)
        external
        returns (uint256 winningTokenId);
}
