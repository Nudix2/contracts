// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IVestingParams} from "./interfaces/IVestingParams.sol";
import {
    VestingType,
    Beneficiary,
    Schedule,
    Period,
    getTotalAmountByVestingType
} from "./utils/Common.sol";

/**
 * @title VestingParams
 * @notice Contract that stores vesting parameters for different vesting types
 */
contract VestingParams is IVestingParams {
    uint40 public constant MONTH = 30 days;

    /// @notice Mapping to track list of beneficiaries per vesting type
    mapping(VestingType vestingType => Beneficiary[] beneficiaries) private _beneficiaries;
    uint40 private _startTime;

    /**
     * @notice Constructor to initialize vesting parameters
     * @param startTime Start time for all vesting schedules
     * @param beneficiaries List of beneficiaries for each vesting type.
     *
     * @dev Except community round all other vesting beneficiaries must be initialized here.
     * For community round, beneficiaries are holders of temporary NUDIX tokens.
     */
    constructor(uint40 startTime, Beneficiary[][8] memory beneficiaries) {
        if (startTime < block.timestamp) {
            revert InvalidStartTime();
        }

        _startTime = startTime;
        _storeBeneficiaries(beneficiaries);
    }

    /**
     * @notice Returns vesting parameters for a specific vesting type
     * @param vestingType The type of vesting
     */
    function getVestingParams(VestingType vestingType)
        external
        view
        returns (Schedule memory, Beneficiary[] memory, uint256)
    {
        return (getSchedule(vestingType), getBeneficiaries(vestingType), getTotalAmountByVestingType(vestingType));
    }

    /**
     * @notice Returns the vesting schedule for a specific vesting type
     * @param vestingType The type of vesting
     */
    function getSchedule(VestingType vestingType) public view returns (Schedule memory schedule) {
        uint40 startTime = _startTime;
        Period[] memory periods;

        if (vestingType == VestingType.COMMUNITY_ROUND) {
            periods = _getCommunityRoundPeriods(startTime);
        }

        if (vestingType == VestingType.SEED_ROUND) {
            periods = _getSeedRoundPeriods(startTime);
        }

        if (vestingType == VestingType.STRATEGIC_ROUND) {
            periods = _getStrategicRoundPeriods(startTime);
        }

        if (vestingType == VestingType.IDO) {
            periods = _getIdoPeriods(startTime);
        }

        if (vestingType == VestingType.TEAM) {
            periods = _getTeamPeriods(startTime);
        }

        if (vestingType == VestingType.ADVISORS) {
            periods = _getAdvisorsPeriods(startTime);
        }

        if (vestingType == VestingType.ECOSYSTEM) {
            periods = _getEcosystemPeriods(startTime);
        }

        if (vestingType == VestingType.LIQUIDITY) {
            periods = _getLiquidityPeriods(startTime);
        }

        if (vestingType == VestingType.RESERVE) {
            periods = _getReservePeriods(startTime);
        }

        schedule = Schedule({startTime: startTime, periods: periods});
    }

    /**
     * @notice Returns the list of beneficiaries for a specific vesting type
     * @param vestingType The type of vesting
     */
    function getBeneficiaries(VestingType vestingType) public view returns (Beneficiary[] memory) {
        return _beneficiaries[vestingType];
    }

    /// @notice Returns the start time for all vesting schedules
    function getStartTime() external view returns (uint40) {
        return _startTime;
    }

    // region - Private functions -

    function _storeBeneficiaries(Beneficiary[][8] memory beneficiaries) private {
        VestingType[8] memory vestingTypes = [
            VestingType.SEED_ROUND,
            VestingType.STRATEGIC_ROUND,
            VestingType.IDO,
            VestingType.TEAM,
            VestingType.ADVISORS,
            VestingType.ECOSYSTEM,
            VestingType.LIQUIDITY,
            VestingType.RESERVE
        ];

        for (uint8 i = 0; i < beneficiaries.length;) {
            _validateAndStoreBeneficiaries(vestingTypes[i], beneficiaries[i]);

            unchecked {
                i++;
            }
        }
    }

    function _validateAndStoreBeneficiaries(VestingType vestingType, Beneficiary[] memory beneficiaries) private {
        if (beneficiaries.length == 0) {
            revert ZeroBeneficiaries();
        }

        uint256 totalAmount;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            Beneficiary memory beneficiary = beneficiaries[i];

            if (beneficiary.account == address(0)) {
                revert ZeroAddress();
            }

            if (beneficiary.amount == 0) {
                revert ZeroAmount();
            }

            totalAmount += beneficiary.amount;
            _beneficiaries[vestingType].push(beneficiary);
        }

        uint256 expectedTotalAmount = getTotalAmountByVestingType(vestingType);
        if (totalAmount != expectedTotalAmount) {
            revert IncorrectBeneficiaryAmounts();
        }
    }

    // endregion

    // region - Private functions for periods of schedule -

    function _getCommunityRoundPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 10;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 15e8}); // 15%

        // Cliff period
        uint40 cliffPeriod = 2 * MONTH;
        periods[1] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint40 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 2; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 10.625e8}); // 10.625%
        }
    }

    function _getSeedRoundPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 20;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 10e8}); // 10%

        // Cliff period
        uint40 cliffPeriod = 6 * MONTH;
        periods[1] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint40 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 2; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 5e8}); // 5%
        }
    }

    function _getStrategicRoundPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 14;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 4e8}); // 4%

        // Cliff period
        uint40 cliffPeriod = 3 * MONTH;
        periods[1] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint40 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 2; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 8e8}); // 8%
        }
    }

    function _getIdoPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 7;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 7e8}); // 7%

        // Vesting period = 10%
        for (uint8 i = 1; i < 4; i++) {
            periods[i] = Period({endTime: startTime + i * MONTH, portion: 10e8}); // 10%
        }

        // Vesting period = 10%
        for (uint8 i = 4; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: startTime + i * MONTH, portion: 21e8}); // 21%
        }
    }

    function _getTeamPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 41;
        periods = new Period[](numberOfPeriods);

        // Cliff period
        uint40 cliffPeriod = 12 * MONTH;
        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint40 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + i * MONTH, portion: 2.5e8}); // 2.5%
        }
    }

    function _getAdvisorsPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 21;
        periods = new Period[](numberOfPeriods);

        // Cliff period
        uint40 cliffPeriod = 9 * MONTH;
        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint40 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + i * MONTH, portion: 5e8}); // 5%
        }
    }

    function _getEcosystemPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 41;
        periods = new Period[](numberOfPeriods);

        // Cliff period
        uint40 cliffPeriod = 3 * MONTH;
        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint40 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + i * MONTH, portion: 2.5e8}); // 2.5%
        }
    }

    function _getLiquidityPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 21;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 15e8}); // 15%

        // Vesting period
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: startTime + i * MONTH, portion: 4.25e8}); // 4.25%
        }
    }

    function _getReservePeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 11;
        periods = new Period[](numberOfPeriods);

        // Cliff period
        uint40 cliffPeriod = 24 * MONTH;
        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint40 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + i * MONTH, portion: 10e8}); // 10%
        }
    }

    // endregion
}
