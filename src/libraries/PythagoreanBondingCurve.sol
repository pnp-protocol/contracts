// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;


// ██████╗░░░░  ██████╗░░█████╗░███╗░░██╗██████╗░██╗███╗░░██╗░██████╗░
// ██╔══██╗░░░  ██╔══██╗██╔══██╗████╗░██║██╔══██╗██║████╗░██║██╔════╝░
// ██████╔╝░░░  ██████╦╝██║░░██║██╔██╗██║██║░░██║██║██╔██╗██║██║░░██╗░
// ██╔═══╝░░░░  ██╔══██╗██║░░██║██║╚████║██║░░██║██║██║╚████║██║░░╚██╗
// ██║░░░░░██╗  ██████╦╝╚█████╔╝██║░╚███║██████╔╝██║██║░╚███║╚██████╔╝
// ╚═╝░░░░░╚═╝  ╚═════╝░░╚═══���╝░╚═╝░░╚══╝╚═════╝░╚═╝╚═╝░░╚══╝░╚═════╝░

// ░█████╗░██╗░░░██╗██████╗░██╗░░░██╗███████╗
// ██╔══██╗██║░░░██║██╔══██╗██║░░░██║██╔════╝
// ██║░░╚═╝██║░░░██║██████╔╝╚██╗░██╔╝█████╗░░
// ██║░░██╗██║░░░██║██╔══██╗░╚████╔╝░██╔══╝░░
// ╚█████╔╝╚██████╔╝██║░░██║░░╚██╔╝░░███████╗
// ░╚════╝░░╚═════╝░╚═╝░░╚═╝░░░╚═╝░░░╚══════╝



library PythagoreanBondingCurve {

    // Each existing prediction market must have the following market params in a struct 
    // r : total reserve in collateral against that market
    // s(yes) : supplies of conditionId YES
    // s(no) : supplies of conditionId NO

    /// @dev Returns additional number of tokens to mint of token A (a)
    function getTokensToMint(uint256 r, uint256 a, uint256 b, uint256 l) public pure returns (uint256 tokenToMint) {

        // Calculate the number of tokens to mint based on the bonding curve formula
        // according to <https://blog.obyte.org/introducing-prophet-prediction-markets-based-on-bonding-curves-3716651db344>

        // Ensure we don't divide by zero
        require(a * a + b * b > 0, "Invalid token supplies");
        require(l > 0, "Reserve to add must be positive");
        
        // Calculate the constant c = r² / (a² + b²)
        // This represents the "price" constant in the bonding curve
        uint256 c = (r * r) / (a * a + b * b);
        
        // Calculate new total reserve after adding l
        uint256 newR = r + l;
        
        // Using the Pythagorean formula:
        // For token supply s: c = r² / (s² + b²)
        // Rearranging to solve for new supply:
        // s = sqrt((newR² / c) - b²)
        uint256 newSupplySquared = (newR * newR) / c - (b * b);
        
        // Calculate the square root to get the new total supply
        uint256 newSupply = sqrt(newSupplySquared);
        
        // The amount to mint is the difference between new supply and current supply
        tokenToMint = newSupply - a;
        
        return tokenToMint;
    }

    /// @dev Called when burning decision tokens
    /// @dev Returns the amount of reserve to be transferred back
    /// @param tokensToBurn amount of tokens to burn of token A 
    /// @param a current supply of token A
    /// @param b current supply of token B
    /// @param r current reserve
    function getReserveToRelease(uint256 r, uint256 a, uint256 b, uint256 tokensToBurn) public returns (uint256 reserveToRelease) {
        
    }

    /// @dev Returns price of token A in terms of collateral token 
    function getPrice(uint256 r, uint256 a, uint256 b, uint256 l) public pure returns (uint256 price) {
        uint256 c = (r * r) / (a * a + b * b);

        // first calculate previous c 
        // Calculate new total reserve after adding l
        uint256 newR = r + l;

        // Using the Pythagorean formula:
        // For token supply s: c = r² / (s² + b²)
        // Rearranging to solve for new supply:
        // s = sqrt((newR² / c) - b²)
        uint256 newSupplySquared = (newR * newR) / c - (b * b);

        uint256 newPriceSquared = (c * newSupplySquared) /
            (newSupplySquared + b * b);

        uint256 newPrice = sqrt(newPriceSquared);

        return newPrice;
    }

    // Helper function to calculate square root
    // Babylonian square root function  
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }   
        return y;
    }
}
