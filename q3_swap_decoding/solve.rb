#!/usr/bin/env ruby
# Q3 — Determine where the $3,184.35 figure in tx 0x5e555836... comes from
# and how it is derived on-chain.
#
# Strategy: fetch the tx receipt, find the Swap event emitted by the
# Uniswap V2 USDC/WETH pool, decode the four uint256 amounts in the event
# data, and apply each token's decimal scaling. We also pull the Sync
# event that precedes the Swap so we can show the post-swap reserves and
# back into the pre-swap reserves, which is what the constant-product
# formula uses to compute the output.

require "bundler/setup"
require "dotenv/load"
require "faraday"
require "json"

TX_HASH        = "0x5e555836bacad83ac3989dc1ec9600800c7796d19d706f007844dfc45e9703ac"
USDC_WETH_POOL = "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc"
SWAP_TOPIC     = "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822"
SYNC_TOPIC     = "0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1"

# token0 = USDC (6 decimals), token1 = WETH (18 decimals).
# Fixed by the V2 pair contract sorting the two token addresses ascending.
USDC_DECIMALS = 6
WETH_DECIMALS = 18

RPC_URLS = [
  ENV["ETHEREUM_RPC_URL"],
  "https://ethereum-rpc.publicnode.com"
].compact.reject(&:empty?)

def rpc_call(method, params)
  payload = { jsonrpc: "2.0", id: 1, method: method, params: params }
  RPC_URLS.each do |url|
    res  = Faraday.post(url, JSON.generate(payload), "Content-Type" => "application/json")
    body = JSON.parse(res.body)
    next if body["error"]

    return body["result"]
  end
  raise "all RPC endpoints failed for #{method}"
end

# A Swap event's `data` is the ABI encoding of (uint256, uint256, uint256, uint256),
# i.e. four 32-byte big-endian words concatenated. Strip 0x, split into 64-char
# chunks, parse each as base-16.
def decode_uint256_tuple(data, count)
  hex = data.sub(/\A0x/, "")
  Array.new(count) { |i| Integer(hex[i * 64, 64], 16) }
end

receipt = rpc_call("eth_getTransactionReceipt", [TX_HASH])
logs    = receipt["logs"]

pool_swap = logs.find do |l|
  l["address"].casecmp?(USDC_WETH_POOL) && l["topics"][0].casecmp?(SWAP_TOPIC)
end
pool_sync = logs.find do |l|
  l["address"].casecmp?(USDC_WETH_POOL) && l["topics"][0].casecmp?(SYNC_TOPIC)
end

raise "Swap log not found on USDC/WETH pool" unless pool_swap

amount0_in, amount1_in, amount0_out, amount1_out = decode_uint256_tuple(pool_swap["data"], 4)

puts "Tx:    #{TX_HASH}"
puts "Block: #{Integer(receipt['blockNumber'], 16)}"
puts "Pool:  #{USDC_WETH_POOL} (Uniswap V2 USDC/WETH)"
puts
puts "Raw Swap event data (four uint256 words):"
puts "  amount0In  = 0x%064x  = %d  (USDC base units)" % [amount0_in,  amount0_in]
puts "  amount1In  = 0x%064x  = %d  (WETH base units)" % [amount1_in,  amount1_in]
puts "  amount0Out = 0x%064x  = %d  (USDC base units)" % [amount0_out, amount0_out]
puts "  amount1Out = 0x%064x  = %d  (WETH base units)" % [amount1_out, amount1_out]
puts
puts "Scaled by each token's decimals:"
puts "  WETH in:   %.6f WETH"  % (amount1_in.to_f  / 10**WETH_DECIMALS)
puts "  USDC out:  %.6f USDC ($%.2f)" %
       [amount0_out.to_f / 10**USDC_DECIMALS, amount0_out.to_f / 10**USDC_DECIMALS]
puts

if pool_sync
  # Sync(uint112 reserve0, uint112 reserve1) — two 32-byte words.
  reserve0_after, reserve1_after = decode_uint256_tuple(pool_sync["data"], 2)
  reserve0_before = reserve0_after + amount0_out - amount0_in
  reserve1_before = reserve1_after + amount1_out - amount1_in

  puts "Reserves around this swap (from the Sync event emitted just before it):"
  puts "  post-swap USDC reserve: %.6f"  % (reserve0_after.to_f  / 10**USDC_DECIMALS)
  puts "  post-swap WETH reserve: %.6f"  % (reserve1_after.to_f  / 10**WETH_DECIMALS)
  puts "  pre-swap  USDC reserve: %.6f"  % (reserve0_before.to_f / 10**USDC_DECIMALS)
  puts "  pre-swap  WETH reserve: %.6f"  % (reserve1_before.to_f / 10**WETH_DECIMALS)
  puts
  puts "Constant-product check (Uniswap V2 with 0.3% fee):"
  # Pool formula:
  #   amount_in_with_fee = amount_in * 997
  #   numerator          = amount_in_with_fee * reserve_out
  #   denominator        = reserve_in * 1000 + amount_in_with_fee
  #   amount_out         = numerator / denominator
  amount_in_with_fee = amount1_in * 997
  numerator          = amount_in_with_fee * reserve0_before
  denominator        = reserve1_before * 1000 + amount_in_with_fee
  predicted_out      = numerator / denominator # integer division, like Solidity
  puts "  predicted amount0Out from formula = %d  (= %.6f USDC)" %
         [predicted_out, predicted_out.to_f / 10**USDC_DECIMALS]
  puts "  actual    amount0Out from event   = %d  (= %.6f USDC)" %
         [amount0_out, amount0_out.to_f / 10**USDC_DECIMALS]
  puts "  match? #{predicted_out == amount0_out}"
end
