// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title Nudix
 * @notice ERC20 token contract for Nudix token with burnable and permit functionalities
 */
contract Nudix is ERC20Permit, ERC20Burnable {
    constructor(address recipient) ERC20("Nudix", "NUDIX") ERC20Permit("Nudix") {
        _mint(recipient, 1_000_000_000 * 10 ** decimals());
    }
}
