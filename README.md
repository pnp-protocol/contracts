----- Design of pnp smart contracts -----

=== Deployment Summary of Price Markets ===
  PNPFactory: 0xd40B3EbcA13E63e72D03d07C2e6a84D00aA035C2
  PriceModule: 0xbB19494C2454E205DBF24Ce441127e5C38e5FD5A




- stick a diagram of modular design here and link to how it works docs
### PNP-Factory.sol
#### erc1155 part
This contract inherits ERC1155 token standard from openzeppelin with vanilla implementation.
We write the burn function according to our market logic allowing people
to burn their holdings for the collateral.

#### registry part
This contracts acts as a registry for all the truth modules contracts in existence.
A function to add a new truth module is provided to the factory contract and is `onlyOwner` protected.
Anyone can request to add a new truth module contract by submitting the contract following the ITruthModule.sol interface in our discord and we will add it to the registry after security review.
`addNewTruthModule(address _truthModule) returns(uint8 moduleId);`

#### PredictionMarketCreation part
This contract is used to create prediction market for any given token in 
question and is public therefore market creation is permissionless.
The market creator has to provide some initial liquidity for the market in
any ERC20 collateral. We prefer using USDT/USDC as collateral but it is to one's wish.
`Will price of $HTUAH go below $0.0000006? Yes/No`
Market creator can infact create a market with $HTUAH as collateral.
chaos
it's just a permissionless tool to express sentiments backed with value.
`createPredictionMarket(uint256 _initialLiquidity, address _tokenInQuestion, uint8 _moduleId, uint256[] _marketParams) returns (bytes32 conditionId);
important to note that the first param of _marketParams of all markets should be the collateral token address and the second param should be the endTimestamp of the market.

this function does the following things : 
- we check that _initialLiquidity is a multiple of 2 and != 0.
- no check for _moduleId because we have a few rn.
- we check that _marketParams[0] is != address(0) and _marketParams[1] is > now.

- creates a bytes32 conditionId from tokenInQuestion, moduleId and msg.sender. we also emit this at the end of the function through an event called `pnpMarketCreated`.
- we initialize several mappings with the conditionId as key like 
`mapping(bytes32 => uint8) public moduleTypeUsed;` , 
- think of a mech to create two new ERC1155 tokenIds for the market representing YES and NO tokens. we also need to emit an event emiting both the tokenIds.
- we transfer the _initialLiquidity to the market contract and update some variable to account that half tokens are staked at YES and half are staked at NO. this variables are updated whenever someone mints YES or NO.
- we store bytes32=> uint256[] marketParams 

#### Minting and Burning YES and NO tokens part
We define two functions to mint and burn YES and NO tokens.
`mintDecisionTokens(bytes32 conditionId,
uint256 collateralAmount,
uint256 tokenIdToMint
)`
`burnDecisionTokens(bytes32 conditionId,
uint256 tokenIdToBurn)`

we check the following things in `mintDecisionTokens()` :
- the market is not expired from the marketParams mapping.
- check that the tokenIdToMint corresponds to the conditionId. (think how to do this)
- we get the number of tokens to mint from a library function which accepts some finentich state variables about the market like value staked against YES and NO tokens and the total reserve against the market and the constant c which is calculated by another function from the library.
- we then mint the ERC1155 corresponding tokens and then emit the event `marketDecisionMinted` with `(bytes32 conditionId, uint256 tokenId, address minter, uint256 amount)`.

`burnDecisionTokens(bytes32 conditionId,
uint256 tokenIdToBurn)`
- we check that the market is not expired from the marketParams mapping.
- code the burn mechanism in the library.

#### Market Execution part
- when a market is created and the marketCreator is minted equal YES and NO tokens according to the initial liquidity,
the market is open for anyone to buy/sell YES and NO tokens on the bonding curve.
- We are using the Pythagorean Bonding Curve for each market. So create a mapping for conditionId to uint256[] 
holding state variables for the market. So that we can fetch this and pass on to the bonding curve library contract to mint or burn appropriate amount of tokens.
- If the market is settled (another state variable for this)
settled and expired have different meanings. 
- We have another function called `settleMarket` which can only be called by the corresponding truth module contract address.
- When the market is settled and we get the correct truth from the Module, users can not call mint or burn decision tokens anymore. Holders of all tokens can only call
`redeemDecisionTokens` function which rewards all the holders of the current correct ERC1155 tokenId provided by the module contract.


## Pythagorean Bonding Curve part
This contract will have these functions only :

`getTokensToMint()
r : total reserve
a : curr supply of token to mint
b : curr supply of other token 
l : reserve to be added  
returns ( uint256 tokenToMint) 


## Market Settlement part
whoever calls settle() will be eligible for a certain portion X of the reserve.


 
- registry part
- PredictionMarket Creation part 
- Minting and Burning YES and NO tokens part
- Market settlement part
- redeeming the decision tokens
- bonding curve part





- test for minting yes tokens after market creation 
- test for minting after ending market
- test for settling market 
- tesr for redeeming decision tokens