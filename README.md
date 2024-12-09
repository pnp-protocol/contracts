----- Design of pnp smart contracts -----

### PNP-Factory.sol
#### erc1155 part
This contract inherits ERC1155 token standard from openzeppelin with vanilla implementation.
We write the burn function according to our market logic allowing people
to burn their holdings for the collateral.

#### registry part
This contracts acts as a registry for all the truth modules contracts in existence.
A function to add a new truth module is provided to the factory contract and is `onlyOwner` protected.
Anyone can request to add a new truth module contract by submitting the contract in our discord and we will add it to the registry after security review.
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








