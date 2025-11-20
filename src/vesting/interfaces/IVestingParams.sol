// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Schedule, Beneficiary, VestingType} from "../utils/Common.sol";

interface IVestingParams {
    function getVestingParams(VestingType vestingType)
        external
        view
        returns (Schedule memory schedule, Beneficiary[] memory beneficiaries, uint256 totalAmount);

    // TODO: functions
}