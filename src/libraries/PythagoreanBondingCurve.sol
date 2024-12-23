// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

// ██████╗░░░░  ██████╗░░█████╗░███╗░░██╗██████╗░██╗███╗░░██╗░██████╗░
// ██╔══██╗░░░  ██╔══██╗██╔══██╗████╗░██║██╔══██╗██║████╗░██║██╔════╝░
// ██████╔╝░░░  ██████╦╝██║░░██║██╔██╗██║██║░░██║██║██╔██╗██║██║░░██╗░
// ██╔═══╝░░░░  ██╔══██╗██║░░██║██║╚████║██║░░██║██║██║╚████║██║░░╚██╗
// ██║░░░░░██╗  ██████╦╝╚█████╔╝██║░╚███║██████╔╝██║██║░╚███║╚██████╔╝
// ╚═╝░░░░░╚═╝  ╚═════╝░░╚═══�������╝░╚═╝░░╚══╝╚═════╝░╚═╝╚═╝░░╚══╝░╚═════╝░

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
    function getTokensToMint(
        uint256 r,
        uint256 a,
        uint256 b,
        uint256 l
    ) public pure returns (uint256 tokenToMint) {
        // Ensure we don't divide by zero and have valid inputs
        require(a > 0 && b > 0, "Token supplies must be positive");
        require(l > 0, "Reserve to add must be positive");
        require(r > 0, "Initial reserve must be positive");

        uint256 SCALE = 1e18;

        // Calculate squares first
        uint256 r_squared = (r * r) / SCALE;
        uint256 a_squared = (a * a) / SCALE;
        uint256 b_squared = (b * b) / SCALE;
        uint256 denominator = a_squared + b_squared;

        require(denominator > 0, "Invalid denominator");

        // Calculate the constant c = r² / (a² + b²)
        uint256 c = (r_squared * SCALE) / denominator;
        require(c > 0, "Invalid price constant");

        // Calculate new total reserve after adding l
        uint256 new_r = r + l;
        uint256 new_r_squared = (new_r * new_r) / SCALE;

        // Using the Pythagorean formula:
        // For token supply s: c = r² / (s² + b²)
        // Rearranging to solve for new supply:
        // s = sqrt((newR² / c) - b²)
        // c = r² / (a² + b²)

        // Calculate (newR² * (a² + b²)) / r²
        uint256 temp = (new_r_squared * denominator) / r_squared; // denominator = a_squared + b_squared;

        // Subtract b² to get new_supply_squared
        require(temp > b_squared, "Invalid square calculation");
        uint256 new_supply_squared = temp - b_squared;

        // Calculate the new supply with proper scaling
        uint256 new_supply = sqrt(new_supply_squared * SCALE);
        require(new_supply > a, "No new tokens to mint");

        // The amount to mint is the difference between new supply and current supply
        tokenToMint = new_supply - a;

        return tokenToMint;
    }

    /// @dev Called when burning decision tokens
    /// @dev Returns the amount of reserve to be transferred back
    /// @param tokensToBurn amount of tokens to burn of token A
    /// @param a current supply of token A
    /// @param b current supply of token B
    /// @param r current reserve
    function getReserveToRelease(
        uint256 r,
        uint256 a,
        uint256 b,
        uint256 tokensToBurn
    ) public pure returns (uint256 reserveToRelease) {
        // Ensure we don't divide by zero
        require(a * a + b * b > 0, "Invalid token supplies");
        require(tokensToBurn > 0, "Must burn positive amount");
        require(tokensToBurn <= a, "Cannot burn more than supply");

        uint256 SCALE = 1e18;

        // Calculate the constant c = r² / (a² + b²)
        uint256 c = (r * r) / ((a * a + b * b) / SCALE);

        // Calculate new supply after burning
        uint256 newSupply = a - tokensToBurn;

        // Calculate current reserve based on current supplies
        uint256 currentReserveSquared = c * ((a * a + b * b) / SCALE);

        // Calculate new reserve based on new supplies
        uint256 newReserveSquared = c * ((newSupply * newSupply + b * b) / SCALE);

        // The reserve to release is the difference between current and new reserves
        uint256 currentReserve = sqrt(currentReserveSquared * SCALE);
        uint256 newReserve = sqrt(newReserveSquared * SCALE);

        reserveToRelease = currentReserve - newReserve;

        return reserveToRelease;
    }

    /// @dev Returns price of token A in terms of collateral token
    function getPrice(
        uint256 r,
        uint256 a,
        uint256 b
    ) public pure returns (uint256 price) {
        // Ensure we don't divide by zero
        require(a * a + b * b > 0, "Invalid token supplies");

        uint256 SCALE = 1e18;

        // Calculate the constant c = r² / (a² + b²)
        uint256 c = (r * r) / ((a * a + b * b) / SCALE);

        // The price is determined by the derivative of the bonding curve
        // For Pythagorean curve: price = c * a / sqrt(a² + b²)
        uint256 denominator = sqrt((a * a + b * b) / SCALE);
        require(denominator > 0, "Invalid denominator");

        price = (c * a) / denominator;

        return price;
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
