// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IVestingImpl} from "./interfaces/IVestingImpl.sol";
import {Schedule, Period, Beneficiary, BASIS_POINTS} from "./utils/Common.sol";

/**
 * @title VestingImpl
 * @notice This contract implements the vesting logic, allowing users to claim their vested tokens.
 */
contract VestingImpl is IVestingImpl, Initializable {
    using SafeERC20 for IERC20;

    Schedule private _schedule;
    IERC20 private _baseToken;

    uint256 private _initialTotalLocked;

    /// @notice Mapping to track amounts initially locked per account
    mapping(address account => uint256 amount) private _initialLocked;

    /// @notice Mapping to track amounts released per account
    mapping(address account => uint256 amount) private _released;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialization function for the vesting contract
     * @param baseToken Address of the base token that will be vested
     * @param schedule The structure that defines the vesting schedule
     * @param beneficiaries The array of beneficiaries with their respective amounts
     */
    function initialize(address baseToken, Schedule calldata schedule, Beneficiary[] calldata beneficiaries)
        external
        initializer
    {
        if (baseToken == address(0)) {
            revert ZeroAddress();
        }

        _baseToken = IERC20(baseToken);

        _initializeSchedule(schedule);
        _initializeBeneficiaries(beneficiaries, baseToken);
    }

    /**
     * @notice Allows users to claim their vested tokens by burning temporary NUDIX tokens
     *
     * @dev Users can claim their vested tokens based on the vesting schedule.
     */
    function claim() external {
        uint256 unlockedAmount = availableToClaim(msg.sender);

        if (unlockedAmount > 0) {
            _released[msg.sender] += unlockedAmount;
            _baseToken.safeTransfer(msg.sender, unlockedAmount);

            emit Claimed(msg.sender, unlockedAmount);
        }
    }

    // region - Public view function -

    /// @notice Retrieves the vesting schedule structure
    function getSchedule() external view returns (Schedule memory) {
        return _schedule;
    }

    /// @notice Returns the base token address
    function getBaseToken() external view returns (address) {
        return address(_baseToken);
    }

    /// @notice Returns the total amount of unlocked tokens
    function totalUnlocked() external view returns (uint256) {
        return _computeUnlocked(_initialTotalLocked);
    }

    /// @notice Returns the total amount of locked tokens
    function totalLocked() external view returns (uint256) {
        uint256 initialTotalLocked = _initialTotalLocked;
        return initialTotalLocked - _computeUnlocked(initialTotalLocked);
    }

    /// @notice Returns the amount of unlocked tokens for a specific account
    function unlockedOf(address account) external view returns (uint256) {
        return _computeUnlocked(_initialLocked[account]);
    }

    /// @notice Returns the amount of locked tokens for a specific account
    function lockedOf(address account) external view returns (uint256) {
        uint256 initialLocked = _initialLocked[account];
        return initialLocked - _computeUnlocked(initialLocked);
    }

    /// @notice Returns the available amount of unlocked tokens that can be claimed by a specific account
    function availableToClaim(address account) public view returns (uint256) {
        return _computeUnlocked(_initialLocked[account]) - _released[account];
    }

    // endregion

    // region - Private functions

    function _initializeSchedule(Schedule calldata schedule) private {
        if (schedule.startTime == 0) {
            revert InvalidStartTime();
        }

        // Check that every period portion param is valid.
        // Variable to keep track of the total percentage of the vesting schedule periods
        uint256 totalPercentageOfPortions;
        uint256 numberOfPeriods = schedule.periods.length;
        for (uint256 i = 0; i < numberOfPeriods; i++) {
            Period memory period = schedule.periods[i];

            if (period.portion > BASIS_POINTS) {
                revert InvalidPortion();
            }

            totalPercentageOfPortions += period.portion;

            if (i > 0) {
                Period memory prevPeriod = schedule.periods[i - 1];

                if (prevPeriod.endTime >= period.endTime) {
                    revert IncorrectPeriodTime();
                }
            }
        }

        if (totalPercentageOfPortions != BASIS_POINTS) {
            revert IncorrectTotalPeriodPortions();
        }

        _schedule.startTime = schedule.startTime;

        for (uint256 i = 0; i < schedule.periods.length; i++) {
            Period memory period = schedule.periods[i];
            _schedule.periods.push(period);
        }

        emit ScheduleInitialized(schedule);
    }

    function _initializeBeneficiaries(Beneficiary[] calldata beneficiaries, address baseToken) private {
        if (beneficiaries.length == 0) {
            revert ZeroBeneficiaries();
        }

        uint256 initialTotalLocked = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            Beneficiary memory beneficiary = beneficiaries[i];

            if (beneficiary.account == address(0)) {
                revert ZeroAddress();
            }

            if (beneficiary.amount == 0) {
                revert ZeroAmount();
            }

            if (_initialLocked[beneficiary.account] > 0) {
                revert DuplicateBeneficiary(beneficiary.account);
            }

            initialTotalLocked += beneficiary.amount;
            _initialLocked[beneficiary.account] = beneficiary.amount;
        }

        if (initialTotalLocked != IERC20(baseToken).balanceOf(address(this))) {
            revert IncorrectAmountOfBeneficiaries();
        }

        _initialTotalLocked = initialTotalLocked;

        emit BeneficiariesInitialized(beneficiaries);
    }

    function _computeUnlocked(uint256 initialLockedAmount) private view returns (uint256 unlockedAmount) {
        Schedule memory schedule = _schedule;

        if (block.timestamp < schedule.startTime) {
            return 0;
        }

        uint256 startTime = schedule.startTime;
        for (uint256 i = 0; i < schedule.periods.length; i++) {
            Period memory period = schedule.periods[i];

            uint256 endTime = period.endTime;
            uint256 portion = period.portion;

            if (block.timestamp < endTime) {
                uint256 partPeriod = block.timestamp - startTime;
                uint256 fullPeriod = endTime - startTime;

                // Calculate the unlocked tokens based on the elapsed time within the period
                unlockedAmount += (initialLockedAmount * partPeriod * portion) / (fullPeriod * BASIS_POINTS);

                // Exit the loop since the unlocked tokens for the current period
                // have been calculated
                break;
            } else {
                // All tokens for the current period are unlocked
                unlockedAmount += (initialLockedAmount * portion) / BASIS_POINTS;
                startTime = endTime;
            }
        }
    }

    // endregion
}
