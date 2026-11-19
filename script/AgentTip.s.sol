// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {AgentTip} from "../src/AgentTip.sol";

/// @notice Deploy AgentTip to BSC. Registry is the SPACE ID HandleRegistry.
/// @dev Deployed 2026-11-19 to 0x64F517f72E96428845451ef8D4B45Df587Dc6e02
///      via the CreateX factory (deployCreate) — the Agentic Wallet CLI
///      cannot send contract-creation transactions directly.
///      Tx 0xf727c298e48054134bc518eafa15b21e2dc625b41a719e2365c877503073a660.
contract AgentTipScript is Script {
    address constant REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external returns (AgentTip) {
        vm.startBroadcast();
        AgentTip tip = new AgentTip(REGISTRY);
        vm.stopBroadcast();
        return tip;
    }
}
