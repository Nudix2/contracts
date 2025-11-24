// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Schedule, Beneficiary, VestingType} from "../utils/Common.sol";

interface IVestingParams {
    /// @notice Revert when start time less than current block timestamp
    error InvalidStartTime();

    /// @notice Revert when call with zero list of beneficiaries
    error ZeroBeneficiaries();

    /// @notice Revert when call with zero address
    error ZeroAddress();

    /// @notice Revert when call with zero amount
    error ZeroAmount();

    /// @notice Revert when sum of beneficiaries amount mismatch with total amount
    error IncorrectBeneficiaryAmounts();

    function getVestingParams(VestingType vestingType)
        external
        view
        returns (Schedule memory, Beneficiary[] memory, uint256 totalAmount);
    function getSchedule(VestingType vestingType) external view returns (Schedule memory schedule);
    function getBeneficiaries(VestingType vestingType) external view returns (Beneficiary[] memory);
    function getStartTime() external view returns (uint40);
}