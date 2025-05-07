// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice Struct data for mint batch operation
struct MintBatchData {
    address recipient;
    uint256 amount;
}

interface ITemporaryNudix is IERC20Metadata {
    /// @notice Thrown a mint batch operation exceeds the maximum data size
    error BatchSizeExceeded(uint256 size, uint256 maxSize);

    /// @notice Thrown when trying to add an already-whitelisted address
    error AlreadyWhitelisted(address account);

    /// @notice Thrown when trying to remove a non-whitelisted address
    error NotWhitelisted(address account);

    /// @notice Thrown when a transfer is attempted to an address not in the whitelist
    error TransferProhibited(address to);

    /// @notice Emitted when an address is removed from the whitelist
    event Unwhitelisted(address account);

    /// @notice Emitted when an address is added to the whitelist
    event Whitelisted(address account);

    function mint(address recipient, uint256 amount) external;
    function mintBatch(MintBatchData[] calldata data) external;
    function addToWhitelist(address account) external;
    function removeFromWhitelist(address account) external;
    function isWhitelisted(address account) external view returns (bool);
}
