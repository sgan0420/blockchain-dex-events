# Q2 — Recent swaps on the Uniswap V2 USDC/ETH pool

Pool: [`0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc`](https://etherscan.io/address/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc)
on Ethereum mainnet.

## Three different angles on the same swap

Etherscan's tabs on a pool address don't all answer the question equally —
they're three different *projections* of the same activity, each useful for a
different reason. The Events tab is the canonical answer; the other two
illuminate what's actually happening on the way in and out.

### 1. `Events` tab — canonical protocol view *(primary answer)*

URL: <https://etherscan.io/address/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc#events>

One row = one `Swap` event emitted by the pool itself. Topic0 is
`0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822` =
`keccak256("Swap(address,uint256,uint256,uint256,uint256,address)")`.
The event `data` carries the four uint256 amounts in this order:

```
amount0In, amount1In, amount0Out, amount1Out
```

i.e. exactly the inputs and outputs of the trade, in **base units** of each
token (USDC has 6 decimals, WETH has 18). Topics 1 and 2 are the indexed
`sender` and `to` addresses.

This is the same projection that an off-chain indexer would build by calling
`eth_getLogs` with `address = <pool>` and `topics = [<swap topic>]` — exactly
what Q4 does for Quickswap. So the Events tab is the **canonical protocol
view** of recent swaps.

Screenshot: [`screenshots/events.png`](./screenshots/events.png)

### 2. `Token Transfers (ERC-20)` tab — settlement view

URL: <https://etherscan.io/address/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc#tokentxns>

This tab does **not** read the pool's `Swap` events. It reads the
`Transfer(address,address,uint256)` events emitted by the **two underlying
tokens** (the USDC contract and the WETH contract) whenever they touch the
pool. So every swap appears as **two paired rows**, one per leg:

- USDC → ETH trade: a `Transfer` of USDC *into* the pool, plus a `Transfer`
  of WETH *out* of the pool.
- ETH → USDC trade: the mirror — WETH in, USDC out.

The amounts are already decoded (USDC at 6 decimals, WETH at 18) because
Etherscan looks up each token's metadata. This is the **settlement view** —
what the user's wallet actually pays and receives — and it's how a block
explorer reconstructs a "trade" without trusting the DEX-specific event.

Screenshot: [`screenshots/token-transfers.png`](./screenshots/token-transfers.png)

### 3. `Transactions` tab — direct-call view *(intentionally sparse)*

URL: <https://etherscan.io/address/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc>

Surprisingly empty for one of the most-traded pools on the network. The
reason is the next section.

Screenshot: [`screenshots/transactions.png`](./screenshots/transactions.png)

## Why the Transactions tab looks empty: Router vs. Pool

Uniswap V2 splits responsibility across two contract layers:

| Layer | Contract | Role |
| --- | --- | --- |
| **Pool** (this address) | `UniswapV2Pair` | Dumb x·y=k math vault. Exposes a primitive `swap(amount0Out, amount1Out, to, data)` that assumes the caller has already transferred input tokens in. No slippage, no path-finding, no ETH/WETH wrapping. |
| **Router** | [`0x7a25…488D`](https://etherscan.io/address/0x7a250d5630B4cF539739dF2C5dacb4c659F2488D) (`UniswapV2Router02`) | User-facing wrapper. Accepts slippage limits, computes optimal amounts, handles multi-hop paths across pools, wraps/unwraps ETH↔WETH, and *then* calls `swap()` on the pool. |

Almost every retail swap (Uniswap UI, 1inch, MetaMask Swaps, etc.) lands at
the **Router**. The Router transfers tokens into the pool and calls
`swap()`. Etherscan's "Transactions" tab on the pool only lists txs whose
`to` field is the pool itself — i.e. **direct calls**, which in practice
are mostly arbitrage bots, MEV searchers, and protocol integrators that
skip the Router. That's why the tab is sparse.

But the *underlying* swap still shows up cleanly:

- The pool **emits a `Swap` event** regardless of who called it → **Events tab populates**.
- The pool still **moves USDC in and WETH out** (or vice-versa) → **Token Transfers tab populates** (sourced from the token contracts, not the pool).
- The pool just isn't the tx's `to` → **Transactions tab stays sparse**.

This three-way split — dumb pool + smart Router, with the pool's own
events as the source of truth — is the architectural reason every Uniswap
V2 fork (SushiSwap, Quickswap, etc.) ships a Router contract alongside the
pair factory. Pools are protocol primitives; Routers are UX.

## How to read a single swap from raw event data

Token ordering in a Uniswap V2 pair is fixed by sorting the two token
addresses ascending. For this pool:

- `token0` = USDC (`0xa0b8...`, 6 decimals)
- `token1` = WETH (`0xc02a...`, 18 decimals)

The `Swap` event always carries four amounts:

```
Swap(
  address indexed sender,
  uint256 amount0In,
  uint256 amount1In,
  uint256 amount0Out,
  uint256 amount1Out,
  address indexed to
)
```

So:

| Direction          | `amount0In` | `amount1In` | `amount0Out` | `amount1Out` |
| ------------------ | ----------- | ----------- | ------------ | ------------ |
| USDC → ETH (buy ETH) | >0 USDC | 0 | 0 | >0 WETH |
| ETH → USDC (sell ETH)| 0 | >0 WETH | >0 USDC | 0 |

Divide the USDC amounts by `10^6` and the WETH amounts by `10^18` to get the
human-readable trade. The Token Transfers tab does exactly this scaling in
the browser, except it reads from each token's own `Transfer` events
instead of decoding the pool's `Swap` event.

## Notes

The same `Swap` event topic (`0xd78ad95f...`) is also used by Quickswap on
Polygon (Q4), SushiSwap, and every other Uniswap V2 fork — because they all
inherit from the same `UniswapV2Pair.sol` contract. The decoding logic, and
the dumb-pool-plus-Router architecture, is reusable across all V2-style
DEXs.
