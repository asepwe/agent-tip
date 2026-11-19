# AgentTip — tip any Agent ID by its .ai name

**Live site: https://asepwe.github.io/agent-tip/**

Binance Agent ID Hackathon entry (submission closes **9 Dec 2026 15:00 WIB**,
60,000 USDC pot). Send BNB to an Agent ID holder by name — `tip("nanako.ai", "gg")`
or `tip("nanako", "gg")` — resolved on-chain via the SPACE ID HandleRegistry.

## Contract

`src/AgentTip.sol` — `tip(string name, string message) payable`

- Tipper **must hold an Agent ID** (`registry.balanceOf(msg.sender) > 0`)
- Name normalized on-chain: lowercased, trailing `.ai` stripped; then
  `registry.isValidHandle` + `registry.ownerOfHandle` resolve it
- **No fee, no owner, no pause, no withdraw** — BNB is forwarded to the
  recipient in the same call; the contract never holds funds
- Self-tips rejected (no wash volume); message max 280 bytes
- On-chain counters for the Growth metrics: `totalTips`, `totalVolume`,
  `tipsSent`/`volumeSent`/`tipsReceived`/`volumeReceived` per address
- `resolve(name)` view helper for frontends; `normalize(name)` pure helper

Registry (verified from Sourcify source, exact_match):
`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (BSC) —
tokenId = `uint256(keccak256(bytes(handle)))`, handle WITHOUT `.ai`;
`ownerOfHandle` returns `address(0)` for unknown handles (does not revert).

## Status

- ✅ Contract written, `forge test` **9/9 passed** (`test/AgentTip.t.sol`,
  incl. mock registry: forward + counters, normalize, zero-value /
  non-holder / unknown / invalid / self-tip / long-message rejections, event)
- ✅ **Deployed on BNB Chain (2026-11-19):** `0x64F517f72E96428845451ef8D4B45Df587Dc6e02`
  ([tx](https://bscscan.com/tx/0xf727c298e48054134bc518eafa15b21e2dc625b41a719e2365c877503073a660),
  block 134459529) via the [CreateX](https://github.com/pcaversaccio/createx)
  factory `0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed` (`deployCreate`)
- ✅ Source verified on Sourcify (**exact_match**, creation + runtime)
- ✅ **Frontend live: https://asepwe.github.io/agent-tip/** (`docs/`, GitHub Pages) — connect wallet (MetaMask/Binance Wallet extension, BSC), tip form with recipient preview, stats + recent tips, all reads via public RPC. No Agentic Wallet QR login (hackathon red line), every tip is confirmed in the user's own wallet.
- ⏳ Promotion to **≥30 Agent ID holders** (Innovation needs 30+ interacting addresses + live product), submit before 9 Dec 15:00 WIB

## Commands

```shell
forge test        # 9 tests, local (mock registry, no fork needed)
forge build
forge script script/AgentTip.s.sol --rpc-url <bsc-rpc> --broadcast  # after top-up
```
