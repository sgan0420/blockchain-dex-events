# Q5 — Price impact on a constant-product DEX

> *Quickswap reports a price impact of **-42.09%** when the trade size is
> increased. What does that mean, why does it matter, and where does the
> number come from?*

## 1. What "price impact" means

A constant-product AMM (Uniswap V2, Quickswap, Sushi, …) doesn't have an
orderbook. There are just two reserves, `x` and `y`, of the two tokens
held by the pool, and a single invariant the pool refuses to violate:

```
x · y = k          (k is constant; ignored fees aside)
```

Every trade slides the pool along that hyperbola. There are two prices
worth distinguishing at any point on the curve:

- **Spot price** (the marginal price for an infinitesimal swap) is the
  *slope of the curve* at the current reserves. Selling token `x` for
  token `y`, the spot price is:

  ```
  P_spot = y / x         (units: y per x)
  ```

  This is the price the UI shows when you haven't typed an amount in yet.

- **Execution price** is what you actually got — the realised ratio
  `Δy / Δx` once you've traded a finite amount. Because the curve bends
  away from your trade, the bigger `Δx` is, the more `P_exec` undershoots
  `P_spot`.

**Price impact** is the relative gap between the two:

```
price_impact = (P_exec − P_spot) / P_spot
             = P_exec / P_spot − 1
```

It is **always negative** for a normal trade (you receive *less* per unit
than the spot price promised). Quickswap displays it with a negative sign
for that reason — a `-42.09%` figure means "your execution price is 42.09%
worse than the headline spot price."

## 2. The math — deriving the price impact formula

Uniswap V2 charges a 0.3% fee by routing only `997/1000` of the input
into the swap (the fee stays in the pool and accrues to LPs).

Given input reserve `x`, output reserve `y`, and input amount `Δx`:

```
Δx_with_fee = Δx · 997 / 1000

amount_out  Δy = (Δx_with_fee · y) / (x + Δx_with_fee)
              = (997 · Δx · y) / (1000 · x + 997 · Δx)
```

Execution price:

```
P_exec = Δy / Δx
       = (997 · y) / (1000 · x + 997 · Δx)
```

Divide by `P_spot = y / x`:

```
P_exec / P_spot = (997 · x) / (1000 · x + 997 · Δx)
```

So price impact (signed, in fractional form):

```
price_impact = (997 · x) / (1000 · x + 997 · Δx) − 1
             = −(3 · x + 997 · Δx) / (1000 · x + 997 · Δx)
```

Two clean takeaways from that formula:

- The `3 · x` term in the numerator is the **0.3% fee floor**. Even an
  infinitesimal trade (`Δx → 0`) has a price impact of `−3 / 1000 =
  −0.30%`, exactly equal to the fee. The fee *is* a baseline price impact.
- The `997 · Δx` terms dominate as `Δx` grows. Price impact scales with
  `Δx / x` — the trade size *relative to the input reserve*. It does not
  depend on which side of the trade is bigger in dollars; only on the
  ratio between your input and the pool's input reserve.

If you drop the fee entirely the formula collapses to the cleaner
identity:

```
|price_impact_no_fee| = Δx / (x + Δx)
```

That is the bare geometric statement: trade `Δx` against reserve `x`, and
your impact is the fraction `Δx / (x + Δx)`.

## 3. Where −42.09% comes from

Set the magnitude to 0.4209 and solve for `Δx / x` (with the 0.3% fee):

```
0.4209 = (3·x + 997·Δx) / (1000·x + 997·Δx)
0.4209·1000·x + 0.4209·997·Δx = 3·x + 997·Δx
420.9·x − 3·x                 = 997·Δx − 419.58·Δx
417.9·x                       = 577.42·Δx
Δx / x                        ≈ 0.7237
```

So a price impact of −42.09% corresponds to swapping in **roughly 72.4%
of the input reserve** in one trade. (Without the fee it's ~72.7% — the
fee shaves the threshold by about 0.3 percentage points, exactly as
expected.)

For perspective, retail trades on healthy pools are typically less than
**1% of the input reserve**, which produces an impact of well under
−0.5% (most of which *is* the 0.3% fee). To hit −42.09%, you'd be
swallowing close to three-quarters of one side of the pool. On a thin
Quickswap pool with, say, $50k of WMATIC liquidity, that's a ~$36k
buy — easy to bump into accidentally if you're trading a long-tail
token.

## 4. Worked example (Q3's USDC/WETH pool)

To keep the math consistent with the rest of the assessment, we'll use
the same Uniswap V2 USDC/WETH pool reserves that Q3 reconstructed from
the `Sync` event at block 14,402,267:

```
x = WETH reserve = 38,306.812178
y = USDC reserve = 105,950,790.410919
P_spot           = y / x = 2,765.95 USDC per WETH
```

The Q3 swap itself was tiny — `Δx = 1.154812 WETH` — so its price impact
is also tiny:

```
P_exec_q3 = 3,184.355095 / 1.154812 ≈ 2,757.46 USDC/WETH
impact_q3 = 2,757.46 / 2,765.95 − 1   ≈ −0.307%
```

That −0.31% almost exactly equals the 0.30% fee floor plus a sliver of
real impact (`Δx / x ≈ 3 × 10⁻⁵`). A user wouldn't even notice.

Now scale `Δx` up until the impact reaches the prompt's −42.09%. Using
the threshold derived above:

```
Δx = 0.7237 · x ≈ 0.7237 · 38,306.81 ≈ 27,723.7 WETH
```

Plug back into the V2 pool formula to see what gets delivered:

```
Δx_with_fee = 27,723.7 · 0.997 ≈ 27,640.5
new_x       = x + Δx_with_fee  ≈ 65,947.3
new_y       = (x · y) / new_x  ≈ (38,306.81 · 105,950,790.41) / 65,947.3
                               ≈ 61,541,884 USDC
Δy          = y − new_y        ≈ 105,950,790.41 − 61,541,884
                               ≈ 44,408,906 USDC
P_exec      = Δy / Δx          ≈ 44,408,906 / 27,723.7
                               ≈ 1,602.0 USDC/WETH
impact      = 1,602.0 / 2,765.95 − 1
                               ≈ −0.4209  →  −42.09%  ✓
```

The same x·y=k formula from Q3 reproduces the figure exactly. At spot,
27,723 WETH would have bought ~$76.7M of USDC. Through the pool it
bought only ~$44.4M. The missing ~$32M is **price impact** — it isn't
paid to anyone; it's a side-effect of moving along the curve.

That value doesn't disappear, by the way. It accrues to whoever sells
WETH into this pool *after* the big trade (typically arbitrageurs), who
buy WETH cheap from the now-distorted pool and sell into deeper markets
until the price is realigned. Price impact on one DEX = arbitrage
opportunity for everyone else.

## 5. Why price impact matters in practice

### Slippage protection

Every Uniswap V2 router call (`swapExactTokensForTokens`,
`swapExactETHForTokens`, …) takes a `minAmountOut` parameter. The
caller computes it as roughly:

```
minAmountOut = expectedAmountOut · (1 − slippage_tolerance)
```

If the realised price impact pushes `Δy` below `minAmountOut`, the
router reverts and refunds gas. Slippage tolerance is the user's
explicit cap on price impact (combined with any front-running between
quote and execution).

A user trading on a thin Quickswap pool with default 0.5% slippage
tolerance and no awareness of impact will simply get their tx reverted
once impact exceeds 0.5%. Quickswap surfacing the −42.09% number is
exactly to short-circuit that: it's warning you before you sign.

### Sandwich attacks / MEV

This is where price impact gets actively weaponised:

1. An MEV searcher sees a victim's pending swap in the mempool with a
   high slippage tolerance (often 5–10% for memecoins).
2. The searcher front-runs by buying the same direction the victim is
   about to buy. This pushes the pool further along the curve, so the
   spot price moves *against* the victim.
3. The victim's tx executes at the now-worse price, eating even more
   impact.
4. The searcher immediately sells what they bought into the
   victim-inflated pool, capturing the spread.

The bigger the victim's price impact, the more room there is for the
sandwich. A pool with `Δx / x ≈ 0.5` is essentially advertising itself
as sandwich bait. Private mempools (Flashbots Protect, MEV-Share) and
intent-based protocols (CowSwap, UniswapX) exist largely to remove this
attack surface.

### Pool depth and venue selection

Two pools trading the same pair at the same spot price can have wildly
different price impacts for the same trade. That's exactly what
aggregators like 1inch, 0x, and ParaSwap solve — they:

- Split a single user trade across multiple pools.
- Route through intermediate tokens (e.g. `DOMI → WETH → USDC` in Q3)
  to take impact on two smaller curves instead of one big one.
- Compare Uniswap V2-style x·y=k curves against V3's concentrated-
  liquidity curves (which can offer much lower impact in-range), Curve's
  StableSwap (lower impact for like-kind assets), and off-chain RFQ
  market-makers.

The metric they optimise is "minimum price impact for the trade as a
whole," not "best price on any single pool."

### Constant-product is a *design choice*

Pools don't have to use `x · y = k`. Curve uses a different invariant
optimised for stablecoin pairs where the expected ratio is ~1:1; that
keeps impact near-zero for typical sizes. Uniswap V3 generalises by
letting LPs concentrate liquidity into specific price ranges, which is
mathematically equivalent to a V2 pool with *much larger virtual
reserves* inside that range — same x·y=k formula, much lower impact for
the same `Δx`. The architectural lesson is that **price impact is a
direct, calculable consequence of the pool's invariant**, and a DEX is
in the business of picking an invariant that minimises it for the
trades it wants to host.

## TL;DR

- **Price impact** is the relative gap between an AMM's spot price and
  the execution price you actually realise.
- For a Uniswap V2 / Quickswap pool with the 0.3% fee:
  `price_impact = −(3·x + 997·Δx) / (1000·x + 997·Δx)`.
- Even a zero-size trade has −0.30% impact (the fee). Real impact scales
  with `Δx / x`.
- **−42.09% impact ⇒ Δx ≈ 72.4% of the input reserve.** A trade that
  big lives in the pool, not next to it.
- The same x·y=k formula from Q3 reproduces the number to the unit.
- It matters because it sets slippage limits, sizes sandwich-attack
  profit, drives the existence of aggregators, and is the variable that
  every alternative AMM design (Curve, V3, RFQ) is trying to suppress.
