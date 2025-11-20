// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {VestingType} from "../utils/Common.sol";

interface IDistributor {
    event VestingStarted(VestingType indexed vestingType, address vesting);

    error InvalidStartTime();
    error ZeroAddress();
    error VestingStartTimeHasNotArrived();

    // TODO: functions
}