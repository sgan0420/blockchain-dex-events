# Blockchain DEX Events

Five short questions on Ethereum / Polygon contract calls and DEX event logs. 
Stack is pure Ruby (no Rails — this is research/RPC-focused and doesn't fit a web app shape).

> **Start here:** [`SOLUTIONS.md`](SOLUTIONS.md) — the consolidated walkthrough
> covering all five answers and the threads that connect them.

## Quick start

```bash
bundle install                              # faraday + dotenv
cp .env.example .env                        # optional, for keyed RPC endpoints
ruby q1_mana_total_supply/solve.rb          # Q1
ruby q3_swap_decoding/solve.rb              # Q3
ruby q4_quickswap_block_logs/solve.rb       # Q4
```

Scripts fall back to uncredentialed public RPC endpoints when `.env` is empty,
so no signup is required to reproduce the answers.

## Layout

```
.
├── SOLUTIONS.md                 ← consolidated walkthrough (start here)
├── docs/
│   ├── QUESTIONS.md             ← original assessment brief
│   └── claude-session.jsonl     ← AI worker session transcript
├── q1_mana_total_supply/        ← MANA totalSupply() on Polygon via raw RPC
├── q2_uniswap_v2_swaps/         ← USDC/ETH swaps on Uniswap V2 (Etherscan)
├── q3_swap_decoding/            ← decoding the $3,184.35 from a real swap
├── q4_quickswap_block_logs/     ← Quickswap Swap events for one Polygon block
├── q5_price_impact/             ← price impact essay + math + the −42.09% solve
├── Gemfile / Gemfile.lock
└── .env.example
```

Each question folder has its own `README.md` with the full answer and
walkthrough. `solve.rb` is present where the question calls for executable
code (Q1, Q3, Q4). Screenshots are in `q2_*/screenshots/` and
`q3_*/screenshots/`.

## Approach

JSON-RPC calls are hand-rolled with `faraday` rather than hidden behind a
library like `eth.rb` or `ethers.js`. The scoring guide explicitly rewards
"usage of RPC API" and "understanding of value decoding/encoding," so the
function selectors, ABI layouts, and uint256 decoding are kept visible
end-to-end.

See [`SOLUTIONS.md`](SOLUTIONS.md) for the question-by-question detail.
