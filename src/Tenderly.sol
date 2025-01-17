// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Market {
    // Public mappings
    mapping(bytes32 => string) public marketQuestions;
    mapping(bytes32 => address) public settlerIds;

    constructor() payable {}

    // Event declaration
    event MarketCreated(address indexed creator, bytes32 conditionId, string question);

    function createMarket(string memory question, string memory username) public returns (bytes32) {
        // Create conditionId by hashing the packed encoding of question and username
        bytes32 conditionId = keccak256(abi.encodePacked(question, username));
        
        // Store the question and settler (msg.sender) for this conditionId
        marketQuestions[conditionId] = question;
        settlerIds[conditionId] = msg.sender;

        // Emit the MarketCreated event
        emit MarketCreated(msg.sender, conditionId, question);

        return conditionId;
    }
}