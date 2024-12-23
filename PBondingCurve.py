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
    if a == 0 and b == 0:
        c = l
    else:
        c = r / math.sqrt(a * a + b * b)
    
    # Calculate new reserve after adding liquidity
    new_r = r + l
    
    tokens_to_mint = math.sqrt((new_r/c) * (new_r/c) - b * b) - a
    return tokens_to_mint

def getReserveToRelease(r: float, a: float, b: float, tokens_to_burn: float) -> float:
    """
    Calculate the amount of reserve to release when burning tokens
    
    Args:
        r: Current reserve amount
        a: Current supply of token A (the one being burned)
        b: Current supply of token B
        tokens_to_burn: Number of A tokens to burn
    
    Returns:
        Amount of reserve to release
    """
    assert tokens_to_burn <= a, "Cannot burn more tokens than supply"
    assert tokens_to_burn > 0, "Must burn positive amount"
    
    # Calculate c from current state
    c = r / math.sqrt(a * a + b * b)
    
    # Calculate new supply after burning
    new_a = a - tokens_to_burn
    
    # Calculate current and new reserves
    current_reserve = r
    new_reserve = c * math.sqrt(new_a * new_a + b * b)
    
    # Amount to release is the difference
    return current_reserve - new_reserve

def getPrice(r: float, a: float, b: float) -> float:
    """
    Calculate the current price of token A based on the bonding curve
    Price is the derivative of the reserve with respect to token supply
    """
    c = r / math.sqrt(a * a + b * b)
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

    print("Case 4: Bob burns half his YES tokens")
    print("====================================")
    # Calculate Bob's position
    bob_yes_tokens = tokens_to_mint  # from Case 2
    tokens_to_burn = bob_yes_tokens / 2
    reserve_to_release = getReserveToRelease(r, a, b, tokens_to_burn)
    print(f"Bob burns {tokens_to_burn:.6f} YES tokens and receives {reserve_to_release:.6f} dollars")
    
    # Update state
    r = r - reserve_to_release
    a = a - tokens_to_burn
    check_invariant(r, a, b)

    print("Case 5: Eve burns all her NO tokens")
    print("===================================")
    # Calculate Eve's position
    eve_no_tokens = tokens_to_mint  # from Case 3
    reserve_to_release = getReserveToRelease(r, b, a, eve_no_tokens)  # Note: b and a swapped for NO tokens
    print(f"Eve burns {eve_no_tokens:.6f} NO tokens and receives {reserve_to_release:.6f} dollars")
    
    # Update state
    r = r - reserve_to_release
    b = b - eve_no_tokens
    check_invariant(r, a, b)