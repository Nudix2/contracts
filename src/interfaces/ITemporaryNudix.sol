// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ITemporaryNudix is IERC20Metadata {
    /// @notice Thrown when the recipients and amounts array lengths do not match
    error ArrayLengthMismatch();

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
    function mintBatch(address[] calldata recipients, uint256[] calldata amounts) external;
    function addToWhitelist(address account) external;
    function removeFromWhitelist(address account) external;
    function isWhitelisted(address account) external view returns (bool);
}
