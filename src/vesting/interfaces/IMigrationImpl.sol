// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Schedule, Beneficiary} from "../utils/Common.sol";

interface IMigrationImpl {
    /// @notice Revert when call with zero address
    error ZeroAddress();

    /// @notice Revert when invalid vesting start time. Must be greater or equal the current block timestamp
    error InvalidStartTime();

    /// @notice Revert when vesting period portion less than BASIS_POINTS
    error InvalidPortion();

    /// @notice Revert when each new end period time greater then prev
    error IncorrectPeriodTime();

    /// @notice Revert when sum of vesting period portion not equal BASIS_POINTS
    error IncorrectTotalPeriodPortions();

    error ClaimPeriodEnded();
    error ClaimPeriodIsNotEnded();
    error OnlySweepAccount();

    /// @notice Emit when beneficiary has claimed vesting token
    event Claimed(address indexed account, uint256 amount);

    /// @notice Emit when vesting schedule params has been initialized
    event ScheduleInitialized(Schedule schedule);

    function initialize(address baseToken, address temporaryNudix, address sweepAccount, Schedule calldata schedule) external;
    function sweep(uint256 amount) external;
    // TODO: check interfaces
}