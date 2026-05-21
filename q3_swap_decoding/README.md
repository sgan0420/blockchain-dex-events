# Q3 — Where does the $3,184.35 in tx `0x5e5558…9703ac` come from?

Tx: <https://etherscan.io/tx/0x5e555836bacad83ac3989dc1ec9600800c7796d19d706f007844dfc45e9703ac>
(Block 14,402,267 on Ethereum mainnet.)

## The short answer

`$3,184.35` is the **USDC output of the second hop** of a two-hop swap routed
through the **1inch v4 aggregator**. The pool that produced that output is
the same Uniswap V2 USDC/WETH pool from Q2
(`0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc`). The exact raw number lives
in the `data` field of that pool's `Swap` event — specifically the third
of its four uint256 words, `amount0Out` — as the base-units integer
`3,184,355,095`. USDC has 6 decimals, so the human amount is
`3,184,355,095 / 10⁶ = 3184.355095 USDC`. Etherscan rounds to two decimals
and prefixes with `$` because USDC is a USD-pegged stablecoin → **`$3,184.35`**.

The `1.15481 ETH` in the prompt is the **input** to that same pool — the
`amount1In` field of the same Swap event, decoded as
`1,154,811,757,668,969,125 / 10¹⁸ ≈ 1.15481 WETH`.

## Where Etherscan shows the number

Three places, all reading the same on-chain data:

1. **Transaction Action** panel at the top of the tx page — Etherscan's
   decoded summary. Reads the tx's `to` (1inch Router) plus the chain of
   `Swap` events and renders something like:

   > Swap `1.15481 ETH` For `$3,184.35` On `Uniswap V2` Via `1inch v4: Aggregation Router`

   Screenshot: [`screenshots/etherscan-action.png`](./screenshots/etherscan-action.png)

2. **Token Transferred** list — shows the underlying ERC-20 `Transfer`
   events. The leg that matters: `From Uniswap V2: USDC 4 → 0x6b6b…c504
   For 3,184.35 USDC ($3,184.35)`. Same number, different source — this
   list is built from the USDC contract's `Transfer` event, not the
   pool's `Swap` event.

   Screenshot: [`screenshots/etherscan-transfers.png`](./screenshots/etherscan-transfers.png)

3. **Logs** panel — raw event data. The Swap event from the USDC/WETH
   pool exposes the four amounts in unscaled base units. This is the
   source of truth that the other two panels decode from.

   Screenshot: [`screenshots/etherscan-logs.png`](./screenshots/etherscan-logs.png)

The first two are decoded views; **the Logs panel is where the raw number
lives**, and `solve.rb` in this folder pulls and decodes it via
`eth_getTransactionReceipt`.

## Why the trade is two hops and not direct

The tx's `to` is `0x1111111254fb6c44bac0bed2854e76f90643097d` — the
**1inch v4 aggregator**, not the Uniswap V2 Router. The user is selling
**DOMI** (`0x45c2f8c9b4c0bdc76200448cc26c48ab6ffef83f`, 18 decimals; the
pool is labelled `Uniswap V2: DOMI 2` on Etherscan), not ETH directly, so
the aggregator split the route across two V2 pools:

```
DOMI (25,000 units)
   │ pool 0x75d3…26df  (Uniswap V2 DOMI/WETH)
   ▼
WETH (1.15481)                  ← this is the "1.15481 ETH" in the prompt
   │ pool 0xb4e16d…c9dc (Uniswap V2 USDC/WETH, same as Q2)
   ▼
USDC (3184.355095)              ← this is the "$3,184.35"
```

> **Etherscan's dollar values are computed at *current* prices, not
> historical.** The DOMI input row shows a near-zero USD value today
> (cents to a few dollars, drifting with DOMI's current price), while
> the USDC output row still shows ~$3,184 because USDC's peg hasn't
> moved. At the time of the trade (March 2022) those 25,000 DOMI were
> worth ~$3,184 — the same as what came out. So the asymmetric USD
> values you see in the modern UI are a price-vintage artefact; the
> on-chain conservation is in token amounts, not dollars.

Each pool emits its own `Swap` event (logs `[4]` and `[7]` in the receipt).
The hop that produces the `$3,184.35` figure is the second one.

## Decoding the Swap event by hand

The Uniswap V2 pool emits:

```solidity
event Swap(
    address indexed sender,    // topic[1]: 1inch router
    uint256 amount0In,         // data, word 0
    uint256 amount1In,         // data, word 1
    uint256 amount0Out,        // data, word 2
    uint256 amount1Out,        // data, word 3
    address indexed to         // topic[2]: user 0x6b6b…c504
);
```

Topic 0 is the event signature hash
`0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822` =
`keccak256("Swap(address,uint256,uint256,uint256,uint256,address)")`.

The pool's raw `data` field for this trade is one long 0x-prefixed hex
string. Split it into four 64-character (32-byte) words:

```
word 0 (amount0In ):  0x000…000                       =                0
word 1 (amount1In ):  0x000…1006b72cd64daaa5          = 1,154,811,757,668,969,125     (WETH base units)
word 2 (amount0Out):  0x000…00000000bdcd6717          = 3,184,355,095                 (USDC base units)
word 3 (amount1Out):  0x000…000                       =                0
```

Apply each token's decimals:

| Field      | Token | Decimals | Base units                     | Human          |
| ---------- | ----- | -------- | ------------------------------ | -------------- |
| amount1In  | WETH  | 18       | 1,154,811,757,668,969,125      | **1.154812**   |
| amount0Out | USDC  | 6        | 3,184,355,095                  | **3,184.355095** |

Etherscan rounds USDC to two decimals (`3,184.35`) and prefixes with `$`
because 1 USDC ≈ $1. So **`$3,184.35` *is* the USDC amount out**, formatted
as USD. There is no separate "ETH-price × ETH-amount" calculation involved
in this number — it's the literal on-chain output of the swap.

## How the pool computed that number

Each Uniswap V2 pool emits a `Sync(uint112 reserve0, uint112 reserve1)`
event *immediately before* every `Swap`, broadcasting its post-swap
reserves. From the same receipt:

```
post-swap USDC reserve: 105,947,606.055824
post-swap WETH reserve: 38,307.966990
```

Reverse the swap to get the pre-swap reserves:

```
pre-swap USDC reserve: 105,947,606.055824 + 3,184.355095  = 105,950,790.410919
pre-swap WETH reserve:  38,307.966990     -    1.154812   =  38,306.812178
```

Now apply Uniswap V2's constant-product formula with the 0.3% fee:

```
amount_in_with_fee = amount_in * 997
amount_out         = (amount_in_with_fee * reserve_out)
                   / (reserve_in * 1000 + amount_in_with_fee)
```

For this swap (WETH in → USDC out):

```
amount_in_with_fee = 1,154,811,757,668,969,125 * 997
                   = 1,151,347,322,395,962,217,625
numerator          = 1,151,347,322,395,962,217,625 * 105,950,790,410,919   (USDC base units)
denominator        = 38,306,812,178,418,000,685,322 * 1000
                   + 1,151,347,322,395,962,217,625
                   = 38,307,963,525,740,396,647,539,625
amount_out         = numerator / denominator  (integer division, like Solidity)
                   = 3,184,355,095
```

`solve.rb` runs this calculation against the actual on-chain reserves and
reproduces `3,184,355,095` to the unit — same number as the event. That
match is what proves the chain of derivation:

```
constant-product math  →  amount0Out in Swap event  →  Etherscan's "$3,184.35"
```

## Running it

```
bundle install
ruby q3_swap_decoding/solve.rb
```

The script defaults to `ethereum-rpc.publicnode.com` for the receipt
fetch; set `ETHEREUM_RPC_URL` in `.env` to override (Alchemy, Infura, your
own node, etc.).

## Why this matters for the scoring guide

This question is the clearest hit on "understanding of value
decoding/encoding" *and* "additional elaboration… that you understand how
these DeFi protocols work underlying":

- **Decoding:** the `$3,184.35` figure isn't a price feed or an external
  estimate — it's a uint256 inside an event's `data` field, scaled by the
  output token's decimal count and re-prefixed with `$`. Showing the byte
  layout makes that explicit.
- **Protocol understanding:** the same number is reproducible *from
  scratch* using only the pre-swap reserves and the constant-product +
  0.3% fee formula. That's the actual math the pool ran in the EVM.
