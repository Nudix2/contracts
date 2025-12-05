// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Schedule, Period, BASIS_POINTS} from "./utils/Common.sol";

import {IERC20Burnable} from "./interfaces/IERC20Burnable.sol";
import {IMigrationImpl} from "./interfaces/IMigrationImpl.sol";

/**
 * @title MigrationImpl
 * @notice Contract for vesting implementation of Community round
 *
 * @dev This contract implements the migration vesting logic, allowing users to claim their vested tokens
 * by burning temporary NUDIX tokens within a specified claim period. After the claim period ends,
 * the sweep account can collect any remaining tokens.
 *
 * Temporary nudix was distributed earlier to community round participants.
 */
contract MigrationImpl is IMigrationImpl, Initializable {
    using SafeERC20 for IERC20;

    /// @notice Claim period duration constant (365 days)
    uint40 private constant _CLAIM_PERIOD = 365 days;

    Schedule private _schedule;
    IERC20 private _baseToken;
    IERC20 private _temporaryNudix;
    address private _sweepAccount;
    uint40 private _claimEnd;

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
     * @param temporaryNudix Address of the temporary NUDIX token
     * @param sweepAccount Address of the sweep account
     * @param schedule The structure that defines the vesting schedule
     */
    function initialize(address baseToken, address temporaryNudix, address sweepAccount, Schedule calldata schedule)
        external
        initializer
    {
        if (baseToken == address(0) || temporaryNudix == address(0) || sweepAccount == address(0)) {
            revert ZeroAddress();
        }

        _baseToken = IERC20(baseToken);
        _temporaryNudix = IERC20(temporaryNudix);
        _sweepAccount = sweepAccount;
        _claimEnd = schedule.startTime + _CLAIM_PERIOD;

        uint256 initialTotalLocked = IERC20(temporaryNudix).totalSupply();
        if (initialTotalLocked == 0 || IERC20(baseToken).balanceOf(address(this)) < initialTotalLocked) {
            revert InsufficientInitialTotalLocked();
        }

        _initialTotalLocked = initialTotalLocked;

        _initializeSchedule(schedule);
    }

    /**
     * @notice Allows users to claim their vested tokens by burning temporary NUDIX tokens
     *
     * @dev Users can claim their vested tokens only within the claim period. After the claim period ends,
     * the claim function will revert.
     */
    function claim() external {
        if (block.timestamp > _claimEnd) {
            revert ClaimPeriodEnded();
        }

        uint256 unlockedAmount = availableToClaim(msg.sender);
        if (unlockedAmount > 0) {
            if (_initialLocked[msg.sender] == 0) {
                _initialLocked[msg.sender] = _temporaryNudix.balanceOf(msg.sender);
            }

            _temporaryNudix.safeTransferFrom(msg.sender, address(this), unlockedAmount);
            IERC20Burnable(address(_temporaryNudix)).burn(unlockedAmount);

            _released[msg.sender] += unlockedAmount;
            _baseToken.safeTransfer(msg.sender, unlockedAmount);

            emit Claimed(msg.sender, unlockedAmount);
        }
    }

    /**
     * @notice Allows the sweep account to collect remaining tokens after the claim period has ended
     * @param amount Amount of tokens to sweep
     */
    function sweep(uint256 amount) external {
        if (block.timestamp <= _claimEnd) {
            revert ClaimPeriodIsNotEnded();
        }

        address sweepAccount = _sweepAccount;
        if (msg.sender != sweepAccount) {
            revert OnlySweepAccount();
        }

        _baseToken.safeTransfer(sweepAccount, amount);

        emit Swept(amount);
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
    function getTemporaryNudix() external view returns (address) {
        return address(_temporaryNudix);
    }

    /// @notice Returns the sweep account address
    function getSweepAccount() external view returns (address) {
        return address(_sweepAccount);
    }

    /// @notice Initial locked amount of a specific account
    function initialLockedOf(address account) public view returns (uint256) {
        return _initialLocked[account] != 0 ? _initialLocked[account] : _temporaryNudix.balanceOf(account);
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
        uint256 initialLocked = initialLockedOf(account);
        return _computeUnlocked(initialLocked);
    }

    /// @notice Returns the amount of locked tokens for a specific account
    function lockedOf(address account) external view returns (uint256) {
        uint256 initialLocked = initialLockedOf(account);
        return initialLocked - _computeUnlocked(initialLocked);
    }

    /// @notice Returns the available amount of unlocked tokens that can be claimed by a specific account
    function availableToClaim(address account) public view returns (uint256) {
        uint256 initialLocked = initialLockedOf(account);
        return _computeUnlocked(initialLocked) - _released[account];
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
