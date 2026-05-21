# Q1 — MANA `totalSupply()` on Polygon via RPC

## The answer

Run against `polygon-rpc.com` (with API key):

```
raw uint256: <fill in from a keyed run against polygon-rpc.com>
human:       <fill in>
```

Run against the `polygon-bor-rpc.publicnode.com` fallback (uncredentialed):

```
raw uint256: 4644407770269267540540803  (0x...03d77dd9875ceb07a37d83)
human:       4,644,407.770269 MANA
```

(The number changes over time as MANA is bridged across networks, so a later
run will report a slightly different supply. Decoding is identical.)

Run it yourself:

```
bundle install
ruby q1_mana_total_supply/solve.rb

# To hit polygon-rpc.com with your own API key, pass the full URL via env:
POLYGON_RPC_URL="https://polygon-rpc.com/?apikey=YOUR_KEY" \
  ruby q1_mana_total_supply/solve.rb
```

`POLYGON_RPC_URL` overrides the first endpoint in the fallback list, so you
can point the script at any Polygon JSON-RPC node (Alchemy, Infura, your own
Bor node) without touching the code.

## How `totalSupply()` becomes an RPC call

`totalSupply()` is part of the ERC-20 interface. To read it from a node we use
`eth_call`, which simulates a transaction against a deployed contract without
spending gas or producing a state change.

The thing that turns a Solidity call into bytes the EVM understands is the
**ABI encoding**. For a `nonpayable returns (uint256)` view function with no
arguments, the calldata is just the **function selector**: the first four
bytes of the Keccak-256 hash of the canonical signature.

```
signature  = "totalSupply()"
keccak256  = 0x18160ddd...   (32 bytes)
selector   = 0x18160ddd        (first 4 bytes)
```

`0x18160ddd` is the same selector every ERC-20 token uses for `totalSupply`,
so you'll see it everywhere.

## The JSON-RPC envelope

`eth_call` takes a partial transaction and a block tag. We only fill in `to`
and `data` — no `from`, no value, no gas, since we're reading state.

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_call",
  "params": [
    {
      "to":   "0xa1c57f48f0deb89f569dfbe6e2b7f46d33606fd4",
      "data": "0x18160ddd"
    },
    "latest"
  ]
}
```

`"latest"` pins us to the head block. We could also pass a specific block
number in hex (`"0x..."`) to query a historical supply.

## Decoding the response

The Polygon node returns a 32-byte word, 0x-prefixed, big-endian:

```
"result": "0x00000000000000000000000000000000000000000003d77dd9875ceb07a37d83"
```

ABI return types are always padded to 32 bytes. A `uint256` is the trivial
case — interpret the whole word as an unsigned big-endian integer:

```ruby
raw_supply = Integer("0x...03d77dd9875ceb07a37d83", 16)
# => 4644407770269267540540803
```

The result is in **base units** (the smallest divisible unit of the token).
MANA's ERC-20 contract declares `decimals = 18`, so the human-readable supply
is `raw_supply / 10**18`:

```
4644407770269267540540803 / 10**18 ≈ 4,644,407.770269 MANA
```

Ruby's `Integer` is arbitrary precision, so no `BigInt`/`BigDecimal` shim is
needed.

## Endpoint note

The brief asks for `https://polygon-rpc.com/`. That endpoint now sits behind a
free API key — uncredentialed requests come back with `tenant disabled,
code -32051`. The script tries it first, then falls back to
`polygon-bor-rpc.publicnode.com`, which speaks the same JSON-RPC dialect. The
request body and the decoding are identical against either endpoint; the only
difference is who is hosting the Bor node.

## Why not just use a library?

A Ruby gem like [`eth.rb`](https://github.com/q9f/eth.rb) (or
[`ethers.js`](https://docs.ethers.io/v5/) / [`web3.py`](https://web3.py)) would
collapse the whole thing to roughly:

```ruby
require "eth"
client = Eth::Client.create("https://polygon-rpc.com/")
erc20  = Eth::Contract.from_abi(name: "MANA", address: MANA, abi: ERC20_ABI)
client.call(erc20, "totalSupply")
```

That hides exactly what this question is testing: the selector computation,
the eth_call params, and the uint256 decode. Doing it by hand makes those
three steps visible.
