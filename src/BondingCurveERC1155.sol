// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BondingCurveERC1155 is ERC1155Supply, Ownable {
    // Base price for each token ID in wei
    mapping(uint256 => uint256) public basePrice;
    
    // Bonding curve coefficient (1.5 = 150%)
    uint256 public constant CURVE_COEFFICIENT = 150;
    
    constructor(string memory uri) ERC1155(uri) Ownable(msg.sender) {}
    
    // Calculate price based on current supply
    function getPrice(uint256 tokenId, uint256 amount) public view returns (uint256) {
        uint256 currentSupply = totalSupply(tokenId);
        uint256 baseTokenPrice = basePrice[tokenId];
        
        if (baseTokenPrice == 0) revert("Token ID not initialized");
        
        uint256 totalPrice = 0;
        
        // Calculate price for each token based on increasing supply
        for (uint256 i = 0; i < amount; i++) {
            uint256 currentPrice = (baseTokenPrice * (CURVE_COEFFICIENT + currentSupply + i)) / 100;
            totalPrice += currentPrice;
        }
        
        return totalPrice;
    }
    
    // Initialize base price for a token ID
    function setBasePrice(uint256 tokenId, uint256 price) external onlyOwner {
        basePrice[tokenId] = price;
    }
    
    // Mint tokens with bonding curve pricing
    function mint(uint256 tokenId, uint256 amount) external payable {
        uint256 price = getPrice(tokenId, amount);
        require(msg.value >= price, "Insufficient payment");
        
        _mint(msg.sender, tokenId, amount, "");
        
        // Refund excess payment
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }
    
    // Withdraw contract balance
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}
