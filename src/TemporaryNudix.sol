// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {ITemporaryNudix, MintBatchData} from "src/interfaces/ITemporaryNudix.sol";

/**
 * @title Temporary Nudix Token (T-NUDIX)
 * @notice ERC20-compatible share token (temporary wrapper for Nudix) with the following features:
 * - Minting and batch minting
 * - Burning (used in the future to exchange for the main Nudix token)
 * - EIP-2612 Permit support
 * - Transfer restrictions: only whitelisted addresses can receive tokens
 *
 * Roles:
 * - DEFAULT_ADMIN_ROLE:
 *     - Can add or remove addresses from the whitelist
 *     - Can assign and revoke roles
 *
 * - MINTER_ROLE:
 *     - Can mint new tokens to whitelisted addresses
 *     - Can perform batch minting operations
 */
contract TemporaryNudix is ITemporaryNudix, ERC20Permit, ERC20Burnable, AccessControl {
    /// @notice Role identifier for accounts allowed to mint tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Maximum value for batch operation
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @dev Only addresses present here can receive token transfers
    mapping(address account => bool) private _isWhitelisted;

    constructor(address admin) ERC20("Temporary Nudix", "T-NUDIX") ERC20Permit("TemporaryNudix") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // region - Mint logic -

    /**
     * @notice Mints new tokens to a single recipient
     * @param recipient Address receiving the newly minted tokens
     * @param amount Amount of tokens to mint
     * @dev Can only be called by addresses with MINTER_ROLE
     */
    function mint(address recipient, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(recipient, amount);
    }

    /**
     * @notice Mints tokens in batch to multiple recipients
     * @param data Array of mint data
     * @dev Can only be called by addresses with MINTER_ROLE
     */
    function mintBatch(MintBatchData[] calldata data) external onlyRole(MINTER_ROLE) {
        uint256 dataSize = data.length;

        if (dataSize > MAX_BATCH_SIZE) {
            revert BatchSizeExceeded(dataSize, MAX_BATCH_SIZE);
        }

        for (uint256 i; i < dataSize;) {
            _mint(data[i].recipient, data[i].amount);
            unchecked { ++i; }
        }
    }

    // endregion

    // region - Whitelist logic

    /**
     * @notice Adds an address to the whitelist
     * @param account The address to whitelist
     * @dev Can only be called by addresses with DEFAULT_ADMIN_ROLE
     */
    function addToWhitelist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_isWhitelisted[account]) {
            revert AlreadyWhitelisted(account);
        }

        _isWhitelisted[account] = true;
        emit Whitelisted(account);
    }

    /**
     * @notice Removes an address from the whitelist
     * @param account The address to remove from the whitelist
     * @dev Can only be called by addresses with DEFAULT_ADMIN_ROLE
     */
    function removeFromWhitelist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_isWhitelisted[account]) {
            revert NotWhitelisted(account);
        }

        _isWhitelisted[account] = false;
        emit Unwhitelisted(account);
    }

    /**
     * @notice Checks whether an address is whitelisted
     * @param account The address to check
     * @return True if the address is whitelisted, false otherwise
     */
    function isWhitelisted(address account) external view returns (bool) {
        return _isWhitelisted[account];
    }

    /// @dev Internal transfer hook that enforces whitelist rules:
    ///     - Minting (from == address(0)) is always allowed
    ///     - Burning (to == address(0)) is allowed only if sender (`from`) is whitelisted
    ///     - Transfers between accounts require recipient (`to`) to be whitelisted
    function _update(address from, address to, uint256 value) internal override {
        bool isMint = from == address(0);
        bool isBurn = to == address(0) && _isWhitelisted[from];

        if (isMint || isBurn) {
            return super._update(from, to, value);
        }

        if (!_isWhitelisted[to]) {
            revert TransferProhibited(to);
        }
        super._update(from, to, value);
    }

    // endregion
}
