// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Schedule, Beneficiary} from "../utils/Common.sol";

interface IVestingImpl {
    /// @notice Revert when call with zero address
    error ZeroAddress();

    /// @notice Revert when call with zero list of beneficiaries
    error ZeroBeneficiaries();

    /// @notice Revert when call with zero amount
    error ZeroAmount();

    /// @notice Revert when duplication of beneficiary for one vesting is not allowed
    error DuplicateBeneficiary(address account);

    /// @notice Revert when sum of beneficiaries amount mismatch with total amount
    error IncorrectAmountOfBeneficiaries();

    /// @notice Revert when invalid vesting start time. Must be greater or equal the current block timestamp
    error InvalidStartTime();

    /// @notice Revert when vesting period portion less than BASIS_POINTS
    error InvalidPortion();

    /// @notice Revert when sum of vesting period portion not equal BASIS_POINTS
    error IncorrectTotalPeriodPortions();

    /// @notice Revert when each new end period time greater then prev
    error IncorrectPeriodTime();

    /// @notice Emit when vesting schedule params has been initialized
    event ScheduleInitialized(Schedule schedule);

    /// @notice Emit when list of beneficiaries has been initialized
    event BeneficiariesInitialized(Beneficiary[] beneficiaries);

    /// @notice Emit when beneficiary has claimed vesting token
    event Claimed(address indexed account, uint256 amount);

    function initialize(address baseToken, Schedule memory schedule, Beneficiary[] memory beneficiaries) external;
    function claim() external;
    function getSchedule() external view returns (Schedule memory);
    function getBaseToken() external view returns (address);
    function totalUnlocked() external view returns (uint256);
    function totalLocked() external view returns (uint256);
    function unlockedOf(address account) external view returns (uint256);
    function lockedOf(address account) external view returns (uint256);
    function availableToClaim(address account) external view returns (uint256);
}