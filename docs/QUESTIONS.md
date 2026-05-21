## Contract Calls Knowledge

1.  Using [https://polygon-rpc.com/](https://polygon-rpc.com/) RPC node as a service, write the code and RPC call to obtain `totalSupply` of the [MANA token](https://polygonscan.com/token/0xa1c57f48f0deb89f569dfbe6e2b7f46d33606fd4) issued on the Polygon (MATIC) blockchain. You may consider using the ERC-20 ABI for your solution. 

** _You may approach the above natively or with a library such as [Ethereum.rb](https://github.com/EthWorks/ethereum.rb), [web3js](https://web3js.readthedocs.io/en/v1.7.1/), or [ethers](https://docs.ethers.io/v5/)_
    

## DEX event logs

1.  Using the [Etherscan](https://etherscan.io/) block explorer, find a list of recent swaps for the following [USDC/ETH pool on Uniswap V2](https://v2.info.uniswap.org/pair/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc)? Provide a screenshot for your response. 
    
1.  [https://etherscan.io/tx/0x5e555836bacad83ac3989dc1ec9600800c7796d19d706f007844dfc45e9703ac/](https://etherscan.io/tx/0x5e555836bacad83ac3989dc1ec9600800c7796d19d706f007844dfc45e9703ac/) is a swap transaction on a Uniswap V2 pool. One of the associated swaps here is a trade from 1.15481 ETH to $3,184.35. Determine in the block explorer where that raw number is coming from and how it is being derived. (You may use screenshot to show your answers)
    
 1.  Quickswap, a DEX on Polygon (MATIC) allows users to swap two assets as a trade. For every swap transaction that is recorded on the blockchain, a swap event is emitted and stored in the network with this hash ID `0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822`. Write the RPC API call to get all the swap events that were emitted for the block [#26444465](https://polygonscan.com/block/26444465). Use [https://polygon-rpc.com/](https://polygon-rpc.com/) RPC node as a service.
    
1.  When using the Quickswap DEX, we noticed that the price impact is -42.09% when we increase the size of the trade. What does price impact mean, why is it important, the math behind the price impact. Include as many details as you can to support your explanation.

## Scoring Guide

Submissions will be evaluated based on the following criteria:

* Usage of RPC API to obtain the answers
* Write code if necessary in any language you are familiar with alongside RPC calls
* Understanding of value decoding/encoding
* Any additional elaboration to your answers to make a case that you understand how these DeFi protocol works underlying

