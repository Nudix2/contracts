// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Schedule, Beneficiary} from "../utils/Common.sol";

interface IVesting {
    function initialize(address baseToken, Schedule memory schedule, Beneficiary[] memory beneficiaries) external;

    // TODO
}