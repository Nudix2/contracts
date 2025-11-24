// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IVestingParams} from "./interfaces/IVestingParams.sol";
import {VestingType, Beneficiary, Schedule, Period} from "./utils/Common.sol";

contract VestingParams is IVestingParams {
    uint256 public constant MONTH = 30 days;

    // Total amount = 1_000_000_000
    uint256 public constant COMMUNITY_ROUND_TOTAL_AMOUNT = 30_000_000e18;
    uint256 public constant SEED_ROUND_TOTAL_AMOUNT = 70_000_000e18;
    uint256 public constant STRATEGIC_ROUND_TOTAL_AMOUNT = 110_000_000e18;
    uint256 public constant IDO_TOTAL_AMOUNT = 40_000_000e18;
    uint256 public constant TEAM_TOTAL_AMOUNT = 140_000_000e18;
    uint256 public constant ADVISORS_TOTAL_AMOUNT = 60_000_000e18;
    uint256 public constant ECOSYSTEM_TOTAL_AMOUNT = 200_000_000e18;
    uint256 public constant LIQUIDITY_TOTAL_AMOUNT = 150_000_000e18;
    uint256 public constant RESERVE_TOTAL_AMOUNT = 200_000_000e18;

    mapping(VestingType vestingType => Beneficiary[] beneficiaries) private _beneficiaries;
    uint40 private _startTime;

    constructor(uint40 startTime, Beneficiary[][8] memory beneficiaries) {
        if (startTime < block.timestamp) {
            revert InvalidStartTime();
        }

        _startTime = startTime;
        _storeBeneficiaries(beneficiaries);
    }

    function getVestingParams(VestingType vestingType)
        external
        view
        returns (Schedule memory, Beneficiary[] memory, uint256)
    {
        return (getSchedule(vestingType), getBeneficiaries(vestingType), _getTotalAmountByVestingType(vestingType));
    }

    function getSchedule(VestingType vestingType) public view returns (Schedule memory schedule) {
        uint40 startTime = _startTime;
        Period[] memory periods;

        if (vestingType == VestingType.SEED_ROUND) {
            periods = _getSeedRoundPeriods(startTime);
        }

        if (vestingType == VestingType.STRATEGIC_ROUND) {
            periods = _getStrategicRoundPeriods(startTime);
        }

        if (vestingType == VestingType.IDO) {
            periods = _getIDOPeriods(startTime);
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

    function getBeneficiaries(VestingType vestingType) public view returns (Beneficiary[] memory) {
        return _beneficiaries[vestingType];
    }

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

        uint256 expectedTotalAmount = _getTotalAmountByVestingType(vestingType);
        if (totalAmount != expectedTotalAmount) {
            revert IncorrectBeneficiaryAmounts();
        }
    }

    function _getTotalAmountByVestingType(VestingType vestingType) private pure returns (uint256 totalAmount) {
        if (vestingType == VestingType.COMMUNITY_ROUND) {
            totalAmount = COMMUNITY_ROUND_TOTAL_AMOUNT;
        }

        if (vestingType == VestingType.SEED_ROUND) {
            totalAmount = SEED_ROUND_TOTAL_AMOUNT;
        }

        if (vestingType == VestingType.STRATEGIC_ROUND) {
            totalAmount = STRATEGIC_ROUND_TOTAL_AMOUNT;
        }

        if (vestingType == VestingType.IDO) {
            totalAmount = IDO_TOTAL_AMOUNT;
        }

        if (vestingType == VestingType.TEAM) {
            totalAmount = TEAM_TOTAL_AMOUNT;
        }

        if (vestingType == VestingType.ADVISORS) {
            totalAmount = ADVISORS_TOTAL_AMOUNT;
        }

        if (vestingType == VestingType.ECOSYSTEM) {
            totalAmount = ECOSYSTEM_TOTAL_AMOUNT;
        }

        if (vestingType == VestingType.LIQUIDITY) {
            totalAmount = LIQUIDITY_TOTAL_AMOUNT;
        }

        if (vestingType == VestingType.RESERVE) {
            totalAmount = RESERVE_TOTAL_AMOUNT;
        }
    }

    // endregion

    // region - Private functions for periods of schedule -

    function _getSeedRoundPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 20;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 1000}); // 10%

        // Cliff period
        uint256 cliffPeriod = 6 * MONTH; // TODO: uint40?
        periods[1] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint256 vestingStartTime = startTime + cliffPeriod; // TODO: uint40?
        for (uint8 i = 2; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 500}); // 5%
        }
    }

    function _getStrategicRoundPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 14;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 400}); // 4%

        // Cliff period
        uint256 cliffPeriod = 3 * MONTH;
        periods[1] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint256 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 2; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 800}); // 8%
        }
    }

    function _getIDOPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 8;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 700}); // 7%

        // Vesting period = 10%
        uint256 vestingStartTime = startTime;
        for (uint256 i = 1; i < 4; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 1000}); // 10%
        }

        // Vesting period = 10%
        for (uint8 i = 4; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 2100}); // 21%
        }
    }

    function _getTeamPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 41;
        periods = new Period[](numberOfPeriods);

        // Cliff period
        uint256 cliffPeriod = 12 * MONTH;
        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint256 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 250}); // 2.5%
        }
    }

    function _getAdvisorsPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 21;
        periods = new Period[](numberOfPeriods);

        // Cliff period
        uint256 cliffPeriod = 9 * MONTH;
        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint256 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 500}); // 5%
        }
    }

    function _getEcosystemPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 41;
        periods = new Period[](numberOfPeriods);

        // Cliff period
        uint256 cliffPeriod = 3 * MONTH;
        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint256 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 250}); // 2.5%
        }
    }

    function _getLiquidityPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 21;
        periods = new Period[](numberOfPeriods);

        // TGE
        periods[0] = Period({endTime: startTime, portion: 1500}); // 15%

        // Vesting period
        uint256 vestingStartTime = startTime;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 425}); // 4.25%
        }
    }

    function _getReservePeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint8 numberOfPeriods = 11;
        periods = new Period[](numberOfPeriods);

        // Cliff period
        uint256 cliffPeriod = 24 * MONTH;
        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});

        // Vesting period
        uint256 vestingStartTime = startTime + cliffPeriod;
        for (uint8 i = 1; i < numberOfPeriods; i++) {
            periods[i] = Period({endTime: vestingStartTime + (i - 1) * MONTH, portion: 1000}); // 10%
        }
    }

    // endregion
}
