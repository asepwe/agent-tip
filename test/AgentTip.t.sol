// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentTip} from "../src/AgentTip.sol";

/// @notice Minimal stand-in for HandleRegistry (0x60B9... on BSC), only for
///         local tests. Real registry behaviour was verified from its Sourcify
///         source: ownerOfHandle returns address(0) for unknown handles,
///         isValidHandle allows lowercase a-z0-9 within length bounds.
contract MockHandleRegistry {
    mapping(string => address) private _ownerOfHandle;
    mapping(address => string) public handleOf;
    mapping(address => uint256) private _balances;

    function mint(address to, string calldata handle) external {
        _ownerOfHandle[handle] = to;
        handleOf[to] = handle;
        _balances[to] = 1;
    }

    function ownerOfHandle(string calldata handle) external view returns (address) {
        return _ownerOfHandle[handle];
    }

    function isValidHandle(string calldata handle) external pure returns (bool) {
        bytes calldata b = bytes(handle);
        if (b.length < 3 || b.length > 64) return false;
        for (uint256 i; i < b.length; ++i) {
            uint8 c = uint8(b[i]);
            if (!((c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39))) return false;
        }
        return true;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }
}

contract AgentTipTest is Test {
    MockHandleRegistry registry;
    AgentTip agentTip;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        registry = new MockHandleRegistry();
        registry.mint(alice, "alice");
        registry.mint(bob, "bob");
        agentTip = new AgentTip(address(registry));
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testTipForwardsBnbAndCounts() public {
        vm.prank(alice);
        agentTip.tip{value: 0.01 ether}("bob.ai", "gg");
        assertEq(bob.balance, 10.01 ether);
        assertEq(address(agentTip).balance, 0, "contract must never hold funds");
        assertEq(agentTip.totalTips(), 1);
        assertEq(agentTip.totalVolume(), 0.01 ether);
        assertEq(agentTip.tipsSent(alice), 1);
        assertEq(agentTip.tipsReceived(bob), 1);
    }

    function testNormalizeCaseAndSuffix() public view {
        assertEq(agentTip.normalize("Bob.AI"), "bob");
        assertEq(agentTip.normalize("BOB"), "bob");
        assertEq(agentTip.normalize("bob.ai"), "bob");
        assertEq(agentTip.resolve("BOB.AI"), bob);
    }

    function testRejectZeroValue() public {
        vm.prank(alice);
        vm.expectRevert(AgentTip.ZeroValue.selector);
        agentTip.tip{value: 0}("bob", "");
    }

    function testRejectNonHolder() public {
        address stranger = address(0x9999);
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        vm.expectRevert(AgentTip.NotAgentIdHolder.selector);
        agentTip.tip{value: 0.01 ether}("bob", "");
    }

    function testRejectUnknownHandle() public {
        vm.prank(alice);
        vm.expectRevert(AgentTip.UnknownHandle.selector);
        agentTip.tip{value: 0.01 ether}("nobody", "");
    }

    function testRejectInvalidHandle() public {
        vm.prank(alice);
        vm.expectRevert(AgentTip.InvalidHandle.selector);
        agentTip.tip{value: 0.01 ether}("Bob_Smith!", "");
    }

    function testRejectSelfTip() public {
        vm.prank(alice);
        vm.expectRevert(AgentTip.SelfTip.selector);
        agentTip.tip{value: 0.01 ether}("alice.ai", "");
    }

    function testRejectLongMessage() public {
        vm.prank(alice);
        vm.expectRevert(AgentTip.MessageTooLong.selector);
        agentTip.tip{value: 0.01 ether}("bob", string(new bytes(281)));
    }

    function testTipEmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(agentTip));
        emit AgentTip.Tipped(alice, bob, "bob", 0.01 ether, "gg");
        agentTip.tip{value: 0.01 ether}("bob", "gg");
    }
}
