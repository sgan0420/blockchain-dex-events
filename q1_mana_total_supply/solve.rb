#!/usr/bin/env ruby
# Q1 — Read MANA totalSupply() from the Polygon blockchain via a raw JSON-RPC eth_call.
#
# We deliberately hand-roll the ABI encoding (the function selector) and the
# uint256 decoding instead of using a library like eth.rb / ethers, so the
# request and response shape is visible end-to-end.

require "bundler/setup"
require "faraday"
require "json"

# Primary endpoint per the brief. As of 2026 the public polygon-rpc.com gateway
# requires a (free) API key — uncredentialed requests come back with
# "tenant disabled, code -32051". We fall back to publicnode's open Bor RPC,
# which speaks the same JSON-RPC dialect, so the call shape stays identical.
RPC_URLS         = [
  "https://polygon-rpc.com/",
  "https://polygon-bor-rpc.publicnode.com"
]
MANA_TOKEN       = "0xa1c57f48f0deb89f569dfbe6e2b7f46d33606fd4"
# keccak256("totalSupply()")[0, 4] = 0x18160ddd. This is the function selector
# every ERC-20 implementation uses for totalSupply().
TOTAL_SUPPLY_SEL = "0x18160ddd"
MANA_DECIMALS    = 18

payload = {
  jsonrpc: "2.0",
  id:      1,
  method:  "eth_call",
  params:  [
    { to: MANA_TOKEN, data: TOTAL_SUPPLY_SEL },
    "latest"
  ]
}

puts "Request body (identical regardless of endpoint):"
puts JSON.pretty_generate(payload)
puts

body = nil
RPC_URLS.each do |url|
  puts "POST #{url}"
  response = Faraday.post(url, JSON.generate(payload), "Content-Type" => "application/json")
  body     = JSON.parse(response.body)
  if body["error"]
    warn "  -> RPC error: #{body['error'].inspect}"
    body = nil
    next
  end
  break
end

if body.nil?
  warn "All endpoints failed."
  exit 1
end

raw_hex = body["result"]
puts "Raw response:"
puts JSON.pretty_generate(body)
puts

# The result is a 32-byte (64 hex char) uint256, big-endian, 0x-prefixed.
# Strip 0x and parse with Integer(..., 16). Ruby integers are arbitrary
# precision so we don't need a BigInt library.
raw_supply = Integer(raw_hex, 16)
human      = raw_supply.to_f / (10**MANA_DECIMALS)

puts "Decoded uint256 (base units, smallest unit of MANA):"
puts "  #{raw_supply}"
puts
puts "Adjusted for #{MANA_DECIMALS} decimals:"
puts "  #{format('%.6f', human)} MANA"
