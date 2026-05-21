# Solutions

CoinGecko take-home: five questions on Ethereum/Polygon contract calls and
DEX event logs. The brief lives in [`docs/QUESTIONS.md`](docs/QUESTIONS.md).

This file is a **navigation aid**. The substantive answers — derivations,
byte-level decoding, screenshots, math — live in **each question's
folder-level `README.md`**. Read those for the full reasoning; treat this
file as a table of contents.

## How it's organised

One folder per question, named `qN_<short_topic>/`. Each folder contains:

- `README.md` — the answer, walkthrough, and any cross-references.
- `solve.rb` — the executable answer when the question calls for one
  (Q1, Q3, Q4).
- `screenshots/` — block-explorer evidence (Q2, Q3).

Code is Ruby. JSON-RPC calls are hand-rolled with `faraday` rather than
hidden behind a library like `eth.rb` / `ethers.js` — the scoring guide
explicitly rewards "usage of RPC API" and "understanding of value
decoding/encoding," and the raw form makes the function selectors, ABI
layouts, and uint256 decoding visible end-to-end.

## Running

```
bundle install            # faraday + dotenv, one Gemfile at repo root
cp .env.example .env      # optional, only needed for keyed RPC endpoints
ruby q1_mana_total_supply/solve.rb
ruby q3_swap_decoding/solve.rb
ruby q4_quickswap_block_logs/solve.rb
```

Each script falls back to an uncredentialed public RPC if `.env` is
empty, so no signup is strictly required.

- `POLYGON_RPC_URL` (Q1, Q4) — defaults to `polygon-bor-rpc.publicnode.com`.
- `ETHEREUM_RPC_URL` (Q3) — defaults to `ethereum-rpc.publicnode.com`.

The brief asks for `polygon-rpc.com` specifically; that endpoint is
operated by Ankr and now requires a free API key (`https://rpc.ankr.com/polygon/<KEY>`).
See [`q1_mana_total_supply/README.md`](q1_mana_total_supply/README.md#endpoint-note)
for the full note.

## The five questions

### Q1 — MANA `totalSupply()` on Polygon → [`q1_mana_total_supply/`](q1_mana_total_supply/README.md)

Hand-rolled `eth_call` against the MANA ERC-20 contract on Polygon, using
the canonical `0x18160ddd` `totalSupply()` selector. The 32-byte hex
response is parsed as a big-endian uint256 and scaled by MANA's 18
decimals. **Answer: ~4,644,407.77 MANA** (raw `4644407770269267540540803`).
README walks through ABI selector derivation, the `eth_call` envelope,
and uint256 decoding.

### Q2 — Recent swaps on the Uniswap V2 USDC/ETH pool → [`q2_uniswap_v2_swaps/`](q2_uniswap_v2_swaps/README.md)

Etherscan exposes three different projections of the same activity on the
pool address. The README frames them as: **Events tab** (canonical
protocol view, the pool's own `Swap` events — matches Q4's
`eth_getLogs`), **Token Transfers (ERC-20) tab** (settlement view, two
paired `Transfer` rows per swap sourced from USDC/WETH contracts), and
**Transactions tab** (direct-call view, intentionally sparse because
almost all retail swaps land at the Uniswap V2 Router, not the pool).
The Router-vs-Pool split is the architectural punchline.

### Q3 — Where `$3,184.35` comes from in tx `0x5e5558…9703ac` → [`q3_swap_decoding/`](q3_swap_decoding/README.md)

The tx is a two-hop swap routed through the **1inch v4 aggregator**:
`DOMI → WETH → USDC`. The `$3,184.35` figure is the **second hop's
output** from the same Uniswap V2 USDC/WETH pool as Q2. It lives
in the `Swap` event's `amount0Out` field as the uint256
`3,184,355,095`, divided by USDC's 6 decimals and formatted with a `$`
because USDC is USD-pegged. `solve.rb` also reconstructs pre-swap
reserves from the `Sync` event and re-derives the same number from the
constant-product formula with the 0.3% fee — match to the unit, which is
what proves the chain "x·y=k math → Swap event → block-explorer dollars."

### Q4 — Quickswap `Swap` events in Polygon block #26,444,465 → [`q4_quickswap_block_logs/`](q4_quickswap_block_logs/README.md)

`eth_getLogs` with `fromBlock = toBlock = 0x19382b1` and the V2 `Swap`
topic `0xd78ad9…0159d822`. Returns exactly one log; three follow-up
`eth_call`s to `factory()`, `token0()`, `token1()` confirm the pool is
Quickswap WMATIC/WETH (factory matches the QuickSwap V2 Factory at
`0x5757…3Ab32`). Decoded trade: **0.004487 WETH in → 8.713302 WMATIC
out**, sender = recipient (arb-bot signature). The README also frames
`eth_getLogs` as the workhorse of off-chain indexing (The Graph,
analytics pipelines).

### Q5 — Price impact and the −42.09% figure → [`q5_price_impact/`](q5_price_impact/README.md)

Essay-style. Derives the V2 price-impact formula from `x·y=k` and the
0.3% fee:

```
price_impact = −(3·x + 997·Δx) / (1000·x + 997·Δx)
```

Two takeaways from the formula: the `3·x` numerator term is the **fee
floor** (every trade has at least −0.30% impact), and impact scales with
`Δx / x` — relative trade size, not absolute dollars. Solving
algebraically for `−42.09%` magnitude gives `Δx ≈ 72.4%` of the input
reserve. A worked example uses Q3's exact pool reserves and reproduces
−42.09% to the unit. Closes with slippage protection, sandwich-attack
mechanics, the existence of aggregators, and "constant-product is a
design choice" (Curve, V3, RFQ as alternatives).

## Threads that run through multiple questions

- **The V2 `Swap` event topic `0xd78ad95f…0159d822`** is shared by every
  Uniswap V2 fork — Uniswap V2, Quickswap, SushiSwap, etc. — because
  they all inherit from the same `UniswapV2Pair.sol`. The same hash
  appears as a filter in **Q4**, as the event payload in **Q3**, and as
  the source of the "Events tab" projection in **Q2**.
- **The constant-product formula** (with 0.3% fee) appears twice. **Q3**
  uses it to verify that `amount0Out = 3,184,355,095` is exactly what
  the pool would compute from its pre-swap reserves; **Q5** uses the
  same pool's reserves to derive the −42.09% impact figure. Same
  invariant, two different views.
- **Router vs Pool architecture.** **Q2** introduces it (dumb pool, smart
  Router, explains why the pool's Transactions tab is empty); **Q3**
  shows a real instance where a third-party Router — 1inch's aggregator
  — fronts two V2 pools in series; **Q5** generalises it (aggregators
  exist because they minimise impact by splitting routes).
- **ABI uint256 decoding.** Every question that touches log data —
  **Q1** (totalSupply return), **Q3** (Swap event payload), **Q4**
  (Swap event payload) — uses the same big-endian-32-byte ↦
  `Integer(hex, 16)` ↦ scale-by-decimals pipeline. Ruby's arbitrary-
  precision integers mean no `BigInt`/`BigDecimal` shim is needed.

## Repo structure

```
.
├── docs/
│   └── QUESTIONS.md            ← original brief
├── q1_mana_total_supply/       ← RPC + uint256 decode (Polygon)
│   ├── README.md
│   └── solve.rb
├── q2_uniswap_v2_swaps/        ← Etherscan walkthrough, screenshots
│   ├── README.md
│   └── screenshots/
├── q3_swap_decoding/           ← tx receipt decode + constant-product check
│   ├── README.md
│   ├── solve.rb
│   └── screenshots/
├── q4_quickswap_block_logs/    ← eth_getLogs + pool identification
│   ├── README.md
│   └── solve.rb
├── q5_price_impact/            ← essay (no code)
│   └── README.md
├── Gemfile                     ← faraday + dotenv, shared
├── .env.example                ← optional RPC API keys
└── SOLUTIONS.md                ← this file
```

The substantive answers and reasoning all live in the per-folder
`README.md` files. **If you're reviewing for scoring, those are where
the detail is** — this file just routes you to the right one.
