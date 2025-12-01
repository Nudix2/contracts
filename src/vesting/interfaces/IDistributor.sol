// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {VestingType} from "../utils/Common.sol";

interface IDistributor {
    /// @notice Emit when whole vesting implementations were created
    event VestingStarted(VestingType indexed vestingType, address vesting);

    /// @notice Revert when call with zero address
    error ZeroAddress();

    function startVestings(address baseToken) external;
    function getVestingByType(VestingType vestingType) external view returns (address);
    function getVestingParams() external view returns (address);
    function getVestingImpl() external view returns (address);
    function getMigrationImpl() external view returns (address);
    function getTemporaryNudix() external view returns (address);
    function getSweepAccount() external view returns (address);
}
