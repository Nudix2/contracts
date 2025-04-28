// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20, ERC20DecimalsMock} from "@openzeppelin/contracts/mocks/token/ERC20DecimalsMock.sol";

contract ERC20Mock is ERC20DecimalsMock {
    constructor(uint8 decimals_) ERC20("ERC20Mock", "E20M") ERC20DecimalsMock(decimals_) {}

    function mint(address account, uint256 value) external {
        _mint(account, value);
    }
}
