# Q2 — Recent swaps on the Uniswap V2 USDC/ETH pool

Pool: [`0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc`](https://etherscan.io/address/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc)
on Ethereum mainnet.

## Where to look on Etherscan

Etherscan exposes three different views that all surface the same underlying
data. Each one is useful at a different level of abstraction:

### 1. `DEX Trades` tab — decoded, human-readable

URL: <https://etherscan.io/address/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc#dextrades>

This is the easiest entry point. Etherscan recognises the pair contract as a
Uniswap V2 pool, decodes every `Swap` event, and renders each trade as:

> *Swap N USDC for M ETH* (or vice-versa), with USD value, tx hash, and time.

Screenshot: [`screenshots/dex-trades.png`](./screenshots/dex-trades.png)

### 2. `Events` tab — raw on-chain events

URL: <https://etherscan.io/address/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc#events>

This shows every `Swap(address,uint256,uint256,uint256,uint256,address)`
event emitted by the pair contract, with `topic0` =
`0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822`.
The four uint256 values in the event `data` are `amount0In`, `amount1In`,
`amount0Out`, `amount1Out` — i.e. exactly the inputs and outputs of the swap
in **base units** of each token (USDC has 6 decimals, WETH has 18).

Screenshot: [`screenshots/events.png`](./screenshots/events.png)

### 3. `Transactions` tab — every tx touching the pool

URL: <https://etherscan.io/address/0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc>

The default landing tab. Every swap (plus mints, burns, syncs) appears here.
Clicking into a single tx and scrolling to the **Logs** section gives the
same `Swap` event as the Events tab but in the context of the full
transaction.

Screenshot: [`screenshots/transactions.png`](./screenshots/transactions.png)

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
human-readable trade. The `DEX Trades` tab does exactly this in the browser.

## Notes

The same `Swap` event topic (`0xd78ad95f...`) is also used by Quickswap on
Polygon (Q4), SushiSwap, and every other Uniswap V2 fork — because they all
inherit from the same `UniswapV2Pair.sol` contract. The decoding logic is
therefore reusable across all V2-style DEXs.
