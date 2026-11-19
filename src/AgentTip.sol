// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentTip — tip any Agent ID by its .ai name
/// @notice Binance Agent ID Hackathon entry (submission closes 9 Dec 2026 15:00 WIB).
/// @notice Send BNB to an Agent ID holder by name, e.g. tip("nanako.ai", "gg") or
///         tip("nanako", "gg"). The name is normalized on-chain (lowercased, ".ai"
///         suffix stripped) and resolved via the SPACE ID HandleRegistry.
/// @notice Design, as chosen by the user on 2026-11-18:
///         - tipper MUST hold an Agent ID (registry.balanceOf(msg.sender) > 0)
///         - no fee, no owner, no pause, no withdraw: BNB is forwarded to the
///           recipient in the same call, so the contract never holds funds
///         - self-tips are rejected (no wash volume toward the Growth metrics)
/// @dev Registry verified on-chain / Sourcify exact_match:
///      HandleRegistry 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F (BSC)
///      - tokenId = uint256(keccak256(bytes(handle))), handle WITHOUT ".ai"
///      - ownerOfHandle(string) returns address(0) for an unregistered handle
///        (it uses _ownerOf, so it does NOT revert)
///      - isValidHandle(string): lowercase a-z + 0-9 only, within minLen/maxLen
///      - handleOf(address) public mapping; token is soulbound (ERC721)
interface IHandleRegistry {
    function ownerOfHandle(string calldata handle) external view returns (address);
    function isValidHandle(string calldata handle) external view returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function handleOf(address owner) external view returns (string memory);
}

contract AgentTip {
    IHandleRegistry public immutable registry;

    /// @notice Max message length (bytes) — keeps tips cheap and spam-light.
    uint256 public constant MAX_MESSAGE_LEN = 280;

    uint256 public totalTips;
    uint256 public totalVolume;
    mapping(address => uint256) public tipsSent;
    mapping(address => uint256) public volumeSent;
    mapping(address => uint256) public tipsReceived;
    mapping(address => uint256) public volumeReceived;

    event Tipped(
        address indexed from,
        address indexed to,
        string handle,
        uint256 amount,
        string message
    );

    error ZeroValue();
    error MessageTooLong();
    error NotAgentIdHolder();
    error InvalidHandle();
    error UnknownHandle();
    error SelfTip();
    error TransferFailed();
    error Reentrant();

    bool private _locked;

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address registry_) {
        registry = IHandleRegistry(registry_);
    }

    /// @notice Tip the holder of `name` (with or without ".ai", any case).
    /// @param name e.g. "nanako", "nanako.ai", "Nanako.AI"
    /// @param message optional message, max 280 bytes
    function tip(string calldata name, string calldata message)
        external
        payable
        nonReentrant
    {
        if (msg.value == 0) revert ZeroValue();
        if (bytes(message).length > MAX_MESSAGE_LEN) revert MessageTooLong();
        if (registry.balanceOf(msg.sender) == 0) revert NotAgentIdHolder();

        string memory handle = normalize(name);
        if (!registry.isValidHandle(handle)) revert InvalidHandle();
        address recipient = registry.ownerOfHandle(handle);
        if (recipient == address(0)) revert UnknownHandle();
        if (recipient == msg.sender) revert SelfTip();

        // Checks-effects-interactions: counters first, external call last.
        totalTips += 1;
        totalVolume += msg.value;
        tipsSent[msg.sender] += 1;
        volumeSent[msg.sender] += msg.value;
        tipsReceived[recipient] += 1;
        volumeReceived[recipient] += msg.value;

        (bool ok,) = recipient.call{value: msg.value}("");
        if (!ok) revert TransferFailed();

        emit Tipped(msg.sender, recipient, handle, msg.value, message);
    }

    /// @notice Resolve a name to its holder's address (view, no tip).
    function resolve(string calldata name) external view returns (address) {
        string memory handle = normalize(name);
        if (!registry.isValidHandle(handle)) revert InvalidHandle();
        return registry.ownerOfHandle(handle);
    }

    /// @notice Lowercase `name` and strip a trailing ".ai" (case-insensitive).
    /// @dev Pure so frontends/tests can call it off-chain for free.
    function normalize(string calldata name) public pure returns (string memory) {
        bytes memory b = bytes(name);
        // Lowercase in place.
        for (uint256 i; i < b.length; ++i) {
            uint8 c = uint8(b[i]);
            if (c >= 0x41 && c <= 0x5A) b[i] = bytes1(c + 32);
        }
        // Strip trailing ".ai" (already lowercased above).
        if (b.length > 3 && b[b.length - 3] == 0x2E && b[b.length - 2] == 0x61 && b[b.length - 1] == 0x69) {
            bytes memory trimmed = new bytes(b.length - 3);
            for (uint256 i; i < trimmed.length; ++i) trimmed[i] = b[i];
            return string(trimmed);
        }
        return string(b);
    }
}
