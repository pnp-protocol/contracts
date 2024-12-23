import math

def getTokensToMint(r: float, a: float, b: float, l: float) -> float:
    """
    Calculate the number of tokens to mint based on the Pythagorean bonding curve equation
    R = c * sqrt(a^2 + b^2)
    
    Args:
        r: Current reserve amount
        a: Current supply of token A (the one being minted)
        b: Current supply of token B
        l: Amount of liquidity being added
    
    Returns:
        Amount of tokens to mint
    """
    # First calculate c (the constant) from current state
    # c = r^2 / (a^2 + b^2)
    if a == 0 and b == 0:
        # Initial state, set c directly from first liquidity
        c = l
    else:
        c = r / math.sqrt(a * a + b * b)
    
    # Calculate new reserve after adding liquidity
    new_r = r + l
    
    # Using the equation R = c * sqrt(a_new^2 + b^2)
    # where a_new = a + tokens_to_mint
    # Solve for tokens_to_mint:
    # new_r = c * sqrt((a + tokens_to_mint)^2 + b^2)
    # (new_r/c)^2 = (a + tokens_to_mint)^2 + b^2
    # tokens_to_mint = sqrt((new_r/c)^2 - b^2) - a
    
    tokens_to_mint = math.sqrt((new_r/c) * (new_r/c) - b * b) - a
    return tokens_to_mint

def getPrice(r: float, a: float, b: float) -> float:
    """
    Calculate the current price of token A based on the bonding curve
    Price is the derivative of the reserve with respect to token supply
    
    Args:
        r: Current reserve amount
        a: Current supply of token A
        b: Current supply of token B
    
    Returns:
        Current price of token A
    """
    # From R = c * sqrt(a^2 + b^2)
    # First calculate c = R/sqrt(a^2 + b^2)
    c = r / math.sqrt(a * a + b * b)
    
    # Price is dR/da = c * a/sqrt(a^2 + b^2)
    # Substituting c = R/sqrt(a^2 + b^2)
    # Price = R * a/(a^2 + b^2)
    price = r * a / (a * a + b * b)
    return price

def check_invariant(r: float, a: float, b: float):
    """Helper function to check and print the invariant"""
    price_a = getPrice(r, a, b)
    price_b = getPrice(r, b, a)
    print(f"\nChecking invariant:")
    print(f"Total reserve = {r}")
    print(f"YES supply = {a}, YES price = {price_a:.6f}")
    print(f"NO supply = {b}, NO price = {price_b:.6f}")
    print(f"YES value = {a * price_a:.6f}")
    print(f"NO value = {b * price_b:.6f}")
    print(f"Total value = {a * price_a + b * price_b:.6f}")
    assert abs(r - (a * price_a + b * price_b)) < 1e-10, "Reserve does not match sum of token values"
    print("✓ Invariant holds\n")
    return price_a, price_b

if __name__ == "__main__":
    print("Case 1: Initial State")
    print("=====================")
    r = 100
    a = 100  # YES tokens
    b = 100  # NO tokens
    check_invariant(r, a, b)

    print("Case 2: Bob buys YES tokens")
    print("===========================")
    l = 100  # Bob adds 100 dollars
    tokens_to_mint = getTokensToMint(r, a, b, l)
    print(f"Bob gets {tokens_to_mint:.6f} YES tokens for {l} dollars")
    
    # Update state
    r = r + l
    a = a + tokens_to_mint
    check_invariant(r, a, b)

    print("Case 3: Eve buys NO tokens")
    print("==========================")
    l = 75  # Eve adds 75 dollars
    tokens_to_mint = getTokensToMint(r, b, a, l)  # Note: b and a swapped for NO tokens
    print(f"Eve gets {tokens_to_mint:.6f} NO tokens for {l} dollars")
    
    # Update state
    r = r + l
    b = b + tokens_to_mint
    check_invariant(r, a, b)