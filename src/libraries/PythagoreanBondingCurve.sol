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
    function getTokensToMint(uint256 r, uint256 a, uint256 b, uint256 l) public pure returns (uint256 tokenToMint) {
        require(r > 0 && l > 0, "Invalid reserves");

        uint256 SCALE = 1e18;

        // Scale down inputs to prevent overflow
        uint256 r_scaled = r / SCALE;
        uint256 a_scaled = a / SCALE;
        uint256 b_scaled = b / SCALE;
        uint256 l_scaled = l / SCALE;

        // Calculate new reserve
        uint256 new_r_scaled = r_scaled + l_scaled;

        // Calculate constant c = r/sqrt(a² + b²)
        uint256 supply_squared = a_scaled * a_scaled + b_scaled * b_scaled;
        require(supply_squared > 0, "Invalid supplies");

        // Calculate new tokens maintaining the bonding curve equation
        // R = c * sqrt(a² + b²)
        uint256 new_supply_squared = (new_r_scaled * new_r_scaled * supply_squared) / (r_scaled * r_scaled);
        require(new_supply_squared > b_scaled * b_scaled, "Invalid result");

        uint256 new_supply = sqrt(new_supply_squared - b_scaled * b_scaled);
        require(new_supply > a_scaled, "No tokens to mint");

        // Scale back up and return
        tokenToMint = (new_supply - a_scaled) * SCALE;

        return tokenToMint;
    }

    /// @dev Called when burning decision tokens
    /// @dev Returns the amount of reserve to be transferred back
    /// @param tokensToBurn amount of tokens to burn of token A
    /// @param a current supply of token A
    /// @param b current supply of token B
    /// @param r current reserve
    function getReserveToRelease(uint256 r, uint256 a, uint256 b, uint256 tokensToBurn)
        public
        pure
        returns (uint256 reserveToRelease)
    {
        // Ensure we don't divide by zero
        require(a * a + b * b > 0, "Invalid token supplies");
        require(tokensToBurn > 0, "Must burn positive amount");
        require(tokensToBurn <= a, "Cannot burn more than supply");

        uint256 SCALE = 1e18;

        // Calculate new supply after burning
        uint256 new_a = a - tokensToBurn;

        // Using R = c * sqrt(a² + b²)
        // Where c = R/sqrt(a² + b²)
        // Therefore, new_reserve = r * sqrt(new_a² + b²)/sqrt(a² + b²)

        uint256 old_supply_squared = a * a + b * b;
        uint256 new_supply_squared = new_a * new_a + b * b;

        // Calculate new_reserve with proper scaling
        uint256 new_reserve = (r * sqrt(new_supply_squared * SCALE)) / sqrt(old_supply_squared * SCALE);

        reserveToRelease = r - new_reserve;
        return reserveToRelease;
    }

    /// @dev Returns price of token A in terms of collateral token
    function getPrice(uint256 r, uint256 a, uint256 b) public pure returns (uint256 price) {
        uint256 SCALE = 1e18;
        uint256 r_scaled = r / SCALE;
        uint256 a_scaled = a / SCALE;
        uint256 b_scaled = b / SCALE;

        // price = r * a / (a² + b²)
        // To prevent overflow:
        // 1. First calculate a² + b²
        // 2. Then do r * a with proper scaling
        // 3. Finally divide by denominator

        uint256 den = a_scaled * a_scaled + b_scaled * b_scaled;

        // We multiply by SCALE to maintain precision in the final result
        price = (r_scaled * a_scaled * SCALE) / den;

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
