// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IDistributor} from "./interfaces/IDistributor.sol";
import {IVestingParams} from "./interfaces/IVestingParams.sol";
import {IVestingImpl} from "./interfaces/IVestingImpl.sol";
import {IMigrationImpl} from "./interfaces/IMigrationImpl.sol";
import {Schedule, Beneficiary, VestingType, NUMBER_OF_VESTING_TYPES} from "./utils/Common.sol";

contract Distributor is IDistributor {
    using SafeERC20 for IERC20;

    IVestingParams private _vestingParams;
    address private _vestingImpl;
    address private _migrationImpl;
    address private _temporaryNudix;
    address private _sweepAccount;

    mapping(VestingType vestingType => address vesting) private _vestingAddresses;

    constructor(
        address vestingParams,
        address vestingImpl,
        address migrationImpl,
        address temporaryNudix,
        address sweepAccount
    ) {
        if (
            vestingParams == address(0) || vestingImpl == address(0) || migrationImpl == address(0)
                || temporaryNudix == address(0) || sweepAccount == address(0)
        ) {
            revert ZeroAddress();
        }

        _vestingParams = IVestingParams(vestingParams);
        _vestingImpl = vestingImpl;
        _migrationImpl = migrationImpl;
        _temporaryNudix = temporaryNudix;
        _sweepAccount = sweepAccount;
    }

    function startVestings(address baseToken) external {
        for (uint8 i = 0; i < NUMBER_OF_VESTING_TYPES;) {
            _startVesting(baseToken, VestingType(i));

            unchecked {
                i++;
            }
        }
    }

    function _startVesting(address baseToken, VestingType vestingType) private {
        (Schedule memory schedule, Beneficiary[] memory beneficiaries, uint256 vestingTotalAmount) =
            _vestingParams.getVestingParams(vestingType);

        address vesting;
        if (vestingType == VestingType.COMMUNITY_ROUND) {
            vesting = _startMigrationVesting(baseToken, schedule, vestingTotalAmount);
        } else {
            vesting = _startClassicVesting(baseToken, schedule, beneficiaries, vestingTotalAmount);
        }

        _vestingAddresses[vestingType] = vesting;

        emit VestingStarted(vestingType, vesting);
    }

    function _startMigrationVesting(address baseToken, Schedule memory schedule, uint256 vestingTotalAmount) private returns (address vesting) {
        vesting = Clones.clone(_migrationImpl);

        IERC20(baseToken).safeTransfer(vesting, vestingTotalAmount);
        IMigrationImpl(vesting).initialize(baseToken, _temporaryNudix, _sweepAccount, schedule);
    }

    function _startClassicVesting(address baseToken, Schedule memory schedule, Beneficiary[] memory beneficiaries, uint256 vestingTotalAmount) private returns (address vesting) {
        vesting = Clones.clone(_vestingImpl);

        IERC20(baseToken).safeTransfer(vesting, vestingTotalAmount);
        IVestingImpl(vesting).initialize(baseToken, schedule, beneficiaries);
    }

    function getVestingByType(VestingType vestingType) external view returns (address) {
        return _vestingAddresses[vestingType];
    }

    function getVestingParams() external view returns (address) {
        return address(_vestingParams);
    }

    function getVestingImpl() external view returns (address) {
        return _vestingImpl;
    }

    function getMigrationImpl() external view returns (address) {
        return _migrationImpl;
    }

    function getTemporaryNudix() external view returns (address) {
        return _temporaryNudix;
    }

    function getSweepAccount() external view returns (address) {
        return _sweepAccount;
    }
}
