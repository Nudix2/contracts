// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Temporary Nudix Token (share token)
 * @notice ERC20-compatible token with burn, permit (EIP-2612), minting
 * and transfer restrictions based on a whitelist
 * Roles:
 * - DEFAULT_ADMIN_ROLE:
 *     - Can add or remove addresses from the whitelist
 *     - Can assign and revoke roles
 *
 * - MINTER_ROLE:
 *     - Can mint new tokens to whitelisted addresses
 *     - Can perform batch minting operations
 */
contract TemporaryNudix is ERC20Permit, ERC20Burnable, AccessControl {
    /// @notice Role identifier for accounts allowed to mint tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Constant for zero address
    address internal constant ADDRESS_ZERO = address(0);

    /// @dev Only addresses present here can receive token transfers
    mapping(address account => bool) private _isWhitelisted;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the recipients and amounts array lengths do not match
    error ArrayLengthMismatch();

    /// @notice Thrown when trying to add an already-whitelisted address
    error AlreadyWhitelisted(address account);

    /// @notice Thrown when trying to remove a non-whitelisted address
    error NotWhitelisted(address account);

    /// @notice Thrown when a transfer is attempted to an address not in the whitelist
    error TransferProhibited(address to);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an address is removed from the whitelist
    event Unwhitelisted(address indexed account);

    /// @notice Emitted when an address is added to the whitelist
    event Whitelisted(address indexed account);

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
     * @param recipients Array of addresses to receive minted tokens
     * @param amounts Array of token amounts corresponding to each recipient
     * @dev Can only be called by addresses with MINTER_ROLE
     */
    function mintBatch(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyRole(MINTER_ROLE)
    {
        if (recipients.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 amount = amounts[i];

            _mint(recipient, amount);
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

    /// @dev Internal transfer hook to restrict transfers to whitelisted addresses
    /// Allows minting and burning, but reverts on transfers to non-whitelisted addresses
    ///     from == ADDRESS_ZERO, to == recipient - mint
    ///     from == sender, to == ADDRESS_ZERO    - burn
    function _update(address from, address to, uint256 value) internal override {
        if (from == ADDRESS_ZERO || to == ADDRESS_ZERO) {
            return super._update(from, to, value);
        }

        if (!_isWhitelisted[to]) {
            revert TransferProhibited(to);
        }
        super._update(from, to, value);
    }

    // endregion
}
