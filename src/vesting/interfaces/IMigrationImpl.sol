// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Schedule} from "../utils/Common.sol";

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

    /// @notice Revert when claim is finished
    error ClaimPeriodEnded();

    /// @notice Revert when claim is not finished
    error ClaimPeriodIsNotEnded();

    /// @notice Revert when sweep was done by the non-sweep account
    error OnlySweepAccount();

    /// @notice Revert when insufficient total locked before initialize migration implementation
    error InsufficientInitialTotalLocked();

    /// @notice Emit when beneficiary has claimed vesting token
    event Claimed(address indexed account, uint256 amount);

    /// @notice Emit when vesting schedule params has been initialized
    event ScheduleInitialized(Schedule schedule);

    /// @notice Emit when sweep has been performed
    event Swept(uint256 amount);

    function initialize(address baseToken, address temporaryNudix, address sweepAccount, Schedule calldata schedule)
        external;
    function claim() external;
    function sweep(uint256 amount) external;
    function getSchedule() external view returns (Schedule memory);
    function getBaseToken() external view returns (address);
    function getTemporaryNudix() external view returns (address);
    function getSweepAccount() external view returns (address);
    function totalUnlocked() external view returns (uint256);
    function totalLocked() external view returns (uint256);
    function initialLockedOf(address account) external view returns (uint256);
    function unlockedOf(address account) external view returns (uint256);
    function lockedOf(address account) external view returns (uint256);
    function availableToClaim(address account) external view returns (uint256);
}
