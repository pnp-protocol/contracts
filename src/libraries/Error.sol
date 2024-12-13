// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

library Error {
    error InsufficientFunds(uint256 available, uint256 required);
    error InvalidAddress(address addr);
    error InvalidAmount(uint256 amount);
    error Unauthorized();

    // Add more custom error messages as needed
}