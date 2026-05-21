#!/usr/bin/env ruby
# Q4 — Fetch every Quickswap-style Swap event in Polygon block #26444465 via
# eth_getLogs and decode each one by hand.
#
# Quickswap is a UniswapV2 fork; its pair contract emits the same Swap event
# with the same topic0 hash as every other V2 fork (Uniswap V2 on mainnet,
# SushiSwap, etc.). topic0 = keccak256("Swap(address,uint256,uint256,uint256,uint256,address)").

require "bundler/setup"
require "dotenv/load"
require "faraday"
require "json"

SWAP_TOPIC = "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822"
BLOCK_DEC  = 26_444_465
BLOCK_HEX  = "0x" + BLOCK_DEC.to_s(16) # eth_getLogs requires hex-encoded block numbers

RPC_URLS = [
  ENV["POLYGON_RPC_URL"],
  "https://polygon-bor-rpc.publicnode.com"
].compact.reject(&:empty?)

def rpc_call(method, params)
  payload = { jsonrpc: "2.0", id: 1, method: method, params: params }
  RPC_URLS.each do |url|
    res  = Faraday.post(url, JSON.generate(payload), "Content-Type" => "application/json")
    body = JSON.parse(res.body)
    if body["error"]
      warn "  -> #{url} rejected: #{body['error'].inspect}"
      next
    end
    return body["result"]
  end
  raise "all RPC endpoints failed for #{method}"
end

# Swap event data is the ABI encoding of four uint256s — read as four
# 32-byte big-endian words.
def decode_swap_amounts(hex_data)
  hex = hex_data.sub(/\A0x/, "")
  raise "expected 256 hex chars (4 uint256 words), got #{hex.length}" unless hex.length == 256

  Array.new(4) { |i| Integer(hex[i * 64, 64], 16) }
end

params = [{
  fromBlock: BLOCK_HEX,
  toBlock:   BLOCK_HEX,
  topics:    [SWAP_TOPIC]
}]

puts "POST <Polygon RPC>"
puts "eth_getLogs request:"
puts JSON.pretty_generate(jsonrpc: "2.0", id: 1, method: "eth_getLogs", params: params)
puts

logs = rpc_call("eth_getLogs", params)

puts "Found #{logs.length} Swap event(s) in block #{BLOCK_DEC} (#{BLOCK_HEX})."
puts

logs.each_with_index do |log, i|
  sender = "0x" + log["topics"][1][-40..]
  to_addr = "0x" + log["topics"][2][-40..]
  a0in, a1in, a0out, a1out = decode_swap_amounts(log["data"])

  puts "── Swap ##{i + 1} ──"
  puts "  pool address: #{log['address']}"
  puts "  tx hash:      #{log['transactionHash']}"
  puts "  log index:    #{Integer(log['logIndex'], 16)}"
  puts "  topics[1] (sender): #{sender}"
  puts "  topics[2] (to):     #{to_addr}"
  puts "  amount0In:  #{a0in}"
  puts "  amount1In:  #{a1in}"
  puts "  amount0Out: #{a0out}"
  puts "  amount1Out: #{a1out}"
  puts
end
