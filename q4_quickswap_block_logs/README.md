# Q4 — All Quickswap `Swap` events in Polygon block #26444465

## The RPC call

Quickswap is a Uniswap V2 fork. Every pair contract emits the same `Swap`
event, with the same topic0:

```
topic0 = keccak256("Swap(address,uint256,uint256,uint256,uint256,address)")
       = 0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822
```

To pull every Swap emitted in a specific block, we use `eth_getLogs` with
a one-block range and a single-element topic filter:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getLogs",
  "params": [
    {
      "fromBlock": "0x19382b1",
      "toBlock":   "0x19382b1",
      "topics":    ["0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822"]
    }
  ]
}
```

`0x19382b1` is decimal `26_444_465` — `eth_getLogs` requires hex-encoded
block numbers. The filter says: *give me every log in this single block
whose first indexed topic is the V2 Swap signature, regardless of which
contract emitted it.*

Run with:

```
bundle install
ruby q4_quickswap_block_logs/solve.rb
```

The script defaults to `polygon-bor-rpc.publicnode.com`. Set
`POLYGON_RPC_URL` in `.env` (same slot Q1 uses) to point at a keyed
`polygon-rpc.com` URL via Ankr.

## The result

A single `Swap` event fires in this block:

```
pool address: 0xadbf1854e5883eb8aa7baf50705338739e558e5b
tx hash:      0x3483fd0fa5d38905e28245ca9ca87b0ab331a104c509e3d239be8f1e5337c01b
log index:    91
topics[1] (sender): 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
topics[2] (to):     0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
amount0In:  0
amount1In:  4487488303473224
amount0Out: 8713302115784607036
amount1Out: 0
```

Only one V2-style Swap log fired in this block. `eth_getLogs` returns
every match in the range — it does not paginate or sample — so one
result means one swap actually happened, not that the filter
suppressed others.

## Identifying the pool

A pool address alone doesn't tell you what's being traded. We make three
follow-up `eth_call`s to learn:

| Selector       | Method                  | Result                                              |
| -------------- | ----------------------- | --------------------------------------------------- |
| `0xc45a0155`   | `factory()`             | `0x5757371414417b8c6caad45baef941abc7d3ab32`        |
| `0x0dfe1681`   | `token0()`              | `0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270` (WMATIC) |
| `0xd21220a7`   | `token1()`              | `0x7ceb23fd6bc0add59e62ac25578270cff1b9f619` (WETH)   |

`factory() = 0x5757…3Ab32` is the **QuickSwap V2 Factory**, so this is
unambiguously a Quickswap pool — not Sushi, not some other V2 clone. And
`token0 = WMATIC`, `token1 = WETH`, both 18 decimals on Polygon.

## Decoding the trade

The event `data` is the ABI encoding of four `uint256` words, in order
`amount0In, amount1In, amount0Out, amount1Out`. Split into 64-char
chunks, parse each as base-16, then scale by the token's decimals:

| Field        | Token   | Decimals | Base units                      | Human          |
| ------------ | ------- | -------- | ------------------------------- | -------------- |
| amount0In    | WMATIC  | 18       | 0                               | 0              |
| amount1In    | WETH    | 18       | 4,487,488,303,473,224           | **0.004487 WETH** |
| amount0Out   | WMATIC  | 18       | 8,713,302,115,784,607,036       | **8.713302 WMATIC** |
| amount1Out   | WETH    | 18       | 0                               | 0              |

So the swap was **0.004487 WETH in → 8.713302 WMATIC out** — i.e. someone
buying MATIC with a small amount of ETH.

The `sender` and `to` on the event are both `0xa5e0…78ff`, which is the
**QuickSwap V2 Router** itself (calling its own `factory()` returns the
QuickSwap V2 Factory `0x5757…3Ab32`, and it exposes `WETH() = WMATIC` —
both are giveaway signatures of a `UniswapV2Router02` clone). That's the
Q2 architecture in action: an EOA called the Router, the Router pulled
the user's WETH into the pool and invoked `pair.swap(amount0Out,
amount1Out, to=Router, …)`, and the Router then forwarded the WMATIC
out to the user. So this is a standard retail swap fronted by the
Router, *not* a direct-to-pool call. The retail-via-Router pattern is
exactly what makes the Q2 pool's Transactions tab look sparse for
Uniswap V2 on mainnet.

## Why this RPC pattern matters

`eth_getLogs` is the workhorse for **off-chain indexing of on-chain
events**. Every DEX aggregator, analytics dashboard, and price oracle
ultimately reduces to:

1. Pick the topic(s) you care about (here, the V2 Swap signature).
2. Walk the chain block-by-block (or in batches), calling `eth_getLogs`
   for each range.
3. Decode the returned logs into the application's domain.

The same call extended across a wider block range (e.g.
`fromBlock = 0x19382b1`, `toBlock = 0x19382b1 + 10_000`) is exactly how
an indexer like The Graph builds its Quickswap subgraph. Public RPC
providers usually cap the range (1k–10k blocks typically) to keep
responses bounded.

## Why not a library?

The Ruby gem `eth.rb` (or `ethers.js` / `web3.py`) would collapse this
to roughly:

```ruby
client.eth_getLogs(
  fromBlock: 26_444_465,
  toBlock:   26_444_465,
  topics:    [Eth::Util.keccak256("Swap(address,uint256,uint256,uint256,uint256,address)")]
)
```

…and pre-decode each log into a struct. Doing it raw makes the topic
hashing, the hex block-number requirement, and the four-word ABI layout
of the event `data` all visible in code.
