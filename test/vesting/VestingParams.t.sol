// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";

import {Nudix} from "src/Nudix.sol";
import {VestingParams, IVestingParams} from "src/vesting/VestingParams.sol";
import {
    Beneficiary,
    Schedule,
    Period,
    VestingType,
    NUMBER_OF_VESTING_TYPES,
    COMMUNITY_ROUND_TOTAL_AMOUNT,
    SEED_ROUND_TOTAL_AMOUNT,
    STRATEGIC_ROUND_TOTAL_AMOUNT,
    IDO_TOTAL_AMOUNT,
    TEAM_TOTAL_AMOUNT,
    ADVISORS_TOTAL_AMOUNT,
    ECOSYSTEM_TOTAL_AMOUNT,
    LIQUIDITY_TOTAL_AMOUNT,
    RESERVE_TOTAL_AMOUNT
} from "src/vesting/utils/Common.sol";

contract VestingParamsTest is Test {
    uint40 public constant MONTH = 30 days;

    uint40 vestingStartTime;
    VestingParams vestingParams;

    address seedBeneficiary;
    address strategicBeneficiary;
    address idoBeneficiary;
    address teamBeneficiary;
    address advisorBeneficiaryA;
    address advisorBeneficiaryB;
    address ecosystemBeneficiary;
    address liquidityBeneficiary;
    address reserveBeneficiary;

    function setUp() external {
        vestingStartTime = uint40(block.timestamp) + 30 days;

        seedBeneficiary = makeAddr("seedBeneficiary");
        strategicBeneficiary = makeAddr("seedBeneficiary");
        idoBeneficiary = makeAddr("idoBeneficiary");
        teamBeneficiary = makeAddr("teamBeneficiary");
        advisorBeneficiaryA = makeAddr("advisorBeneficiaryA");
        advisorBeneficiaryB = makeAddr("advisorBeneficiaryB");
        ecosystemBeneficiary = makeAddr("ecosystemBeneficiary");
        liquidityBeneficiary = makeAddr("liquidityBeneficiary");
        reserveBeneficiary = makeAddr("reserveBeneficiary");

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();
        vestingParams = new VestingParams(vestingStartTime, beneficiaries);
    }

    // region - Deploy -

    function test_deploy() external view {
        assertNotEq(address(vestingParams), address(0));
        assertEq(vestingParams.getStartTime(), vestingStartTime);

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();

        // Community round haven't beneficiaries. Expected that beneficiaries are accounts who have t-nudix token
        Beneficiary[] memory communityBeneficiaries = vestingParams.getBeneficiaries(VestingType.COMMUNITY_ROUND);
        assertEq(communityBeneficiaries.length, 0);

        for (uint8 i = 0; i < 8; i++) {
            VestingType vestingType = VestingType(i + 1); // skip COMMUNITY_ROUND
            Beneficiary[] memory vestingBeneficiaries = vestingParams.getBeneficiaries(vestingType);
            Beneficiary[] memory expectedBeneficiaries = beneficiaries[i];

            assertEq(vestingBeneficiaries.length, expectedBeneficiaries.length);
            for (uint256 j = 0; j < vestingBeneficiaries.length; j++) {
                assertEq(vestingBeneficiaries[j].account, expectedBeneficiaries[j].account);
                assertEq(vestingBeneficiaries[j].amount, expectedBeneficiaries[j].amount);
            }
        }
    }

    function test_deploy_revertIfInvalidStartTime(uint40 currentTimestamp) external {
        vm.assume(vestingStartTime < currentTimestamp);
        vm.warp(currentTimestamp);

        vm.expectRevert(IVestingParams.InvalidStartTime.selector);

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();
        vestingParams = new VestingParams(vestingStartTime, beneficiaries);
    }

    function test_deploy_revertIfZeroBeneficiaries(uint8 index) external {
        index = uint8(bound(index, 0, 7));

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();
        beneficiaries[index] = new Beneficiary[](0);

        vm.expectRevert(IVestingParams.ZeroBeneficiaries.selector);

        vestingParams = new VestingParams(vestingStartTime, beneficiaries);
    }

    function test_deploy_revertIfZeroAddress(uint8 index) external {
        index = uint8(bound(index, 0, 7));

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();
        beneficiaries[index][0].account = address(0);

        vm.expectRevert(IVestingParams.ZeroAddress.selector);

        vestingParams = new VestingParams(vestingStartTime, beneficiaries);
    }

    function test_deploy_revertIfZeroAmount(uint8 index) external {
        index = uint8(bound(index, 0, 7));

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();
        beneficiaries[index][0].amount = 0;

        vm.expectRevert(IVestingParams.ZeroAmount.selector);

        vestingParams = new VestingParams(vestingStartTime, beneficiaries);
    }

    function test_deploy_revertIfIncorrectBeneficiaryAmounts(uint8 index) external {
        index = uint8(bound(index, 0, 7));

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();
        beneficiaries[index][0].amount += 1e18;

        vm.expectRevert(IVestingParams.IncorrectBeneficiaryAmounts.selector);

        vestingParams = new VestingParams(vestingStartTime, beneficiaries);
    }

    // endregion

    // region - Check total supply -

    function test_checkTotalSupply() external {
        Nudix nudix = new Nudix(address(this));

        assertEq(
            nudix.totalSupply(),
            COMMUNITY_ROUND_TOTAL_AMOUNT
                + SEED_ROUND_TOTAL_AMOUNT
                + STRATEGIC_ROUND_TOTAL_AMOUNT
                + IDO_TOTAL_AMOUNT
                + TEAM_TOTAL_AMOUNT
                + ADVISORS_TOTAL_AMOUNT
                + ECOSYSTEM_TOTAL_AMOUNT
                + LIQUIDITY_TOTAL_AMOUNT
                + RESERVE_TOTAL_AMOUNT
        );
    }
    // endregion

    // region - Get Schedule -

    function test_getSchedule() external view {
        for (uint256 i = 0; i < NUMBER_OF_VESTING_TYPES; i++) {
            VestingType vestingType = VestingType(i);
            Schedule memory schedule = vestingParams.getSchedule(vestingType);

            assertEq(schedule.startTime, vestingStartTime);

            Period[] memory expectedPeriods = _getVestingPeriods(vestingType);
            for (uint256 j = 0; j < schedule.periods.length; j++) {
                Period memory period = schedule.periods[j];

                assertEq(period.endTime, expectedPeriods[j].endTime);
                assertEq(period.portion, expectedPeriods[j].portion);
            }
        }
    }

    // endregion

    // region - Get vesting params -

    function test_getVestingParams() external view {
        for (uint256 i = 0; i < NUMBER_OF_VESTING_TYPES; i++) {
            VestingType vestingType = VestingType(i);
            (Schedule memory schedule, Beneficiary[] memory beneficiaries, uint256 totalAmount) =
                vestingParams.getVestingParams(vestingType);

            // Stage 1. Check schedules
            assertEq(schedule.startTime, vestingStartTime);

            Period[] memory expectedPeriods = _getVestingPeriods(vestingType);
            for (uint256 j = 0; j < schedule.periods.length; j++) {
                Period memory period = schedule.periods[j];

                assertEq(period.endTime, expectedPeriods[j].endTime);
                assertEq(period.portion, expectedPeriods[j].portion);
            }

            // Stage 2. Check beneficiaries
            if (vestingType == VestingType.COMMUNITY_ROUND) {
                assertEq(beneficiaries.length, 0);
            } else {
                Beneficiary[][8] memory expectedBeneficiaries = _getBeneficiaries();
                for (uint256 j = 0; j < beneficiaries.length; j++) {
                    Beneficiary memory beneficiary = beneficiaries[j];

                    assertEq(beneficiary.account, expectedBeneficiaries[i - 1][j].account);
                    assertEq(beneficiary.amount, expectedBeneficiaries[i - 1][j].amount);
                }
            }

            // Stage 3. Check total amount
            uint256 expectedTotalAmount = _getTotalAmount(vestingType);
            assertEq(totalAmount, expectedTotalAmount);
        }
    }

    // endregion

    // region - Private functions -

    function _getBeneficiaries() private view returns (Beneficiary[][8] memory beneficiaries) {
        Beneficiary[] memory seedBeneficiaries = new Beneficiary[](1);
        seedBeneficiaries[0] = Beneficiary({account: seedBeneficiary, amount: SEED_ROUND_TOTAL_AMOUNT});

        Beneficiary[] memory strategicBeneficiaries = new Beneficiary[](1);
        strategicBeneficiaries[0] = Beneficiary({account: strategicBeneficiary, amount: STRATEGIC_ROUND_TOTAL_AMOUNT});

        Beneficiary[] memory idoBeneficiaries = new Beneficiary[](1);
        idoBeneficiaries[0] = Beneficiary({account: idoBeneficiary, amount: IDO_TOTAL_AMOUNT});

        Beneficiary[] memory teamBeneficiaries = new Beneficiary[](1);
        teamBeneficiaries[0] = Beneficiary({account: teamBeneficiary, amount: TEAM_TOTAL_AMOUNT});

        Beneficiary[] memory advisorsBeneficiaries = new Beneficiary[](2);
        advisorsBeneficiaries[0] =
            Beneficiary({account: advisorBeneficiaryA, amount: ADVISORS_TOTAL_AMOUNT * 0.3e18 / 1e18});
        advisorsBeneficiaries[1] =
            Beneficiary({account: advisorBeneficiaryB, amount: ADVISORS_TOTAL_AMOUNT * 0.7e18 / 1e18});

        Beneficiary[] memory ecosystemBeneficiaries = new Beneficiary[](1);
        ecosystemBeneficiaries[0] = Beneficiary({account: ecosystemBeneficiary, amount: ECOSYSTEM_TOTAL_AMOUNT});

        Beneficiary[] memory liquidityBeneficiaries = new Beneficiary[](1);
        liquidityBeneficiaries[0] = Beneficiary({account: liquidityBeneficiary, amount: LIQUIDITY_TOTAL_AMOUNT});

        Beneficiary[] memory reserveBeneficiaries = new Beneficiary[](1);
        reserveBeneficiaries[0] = Beneficiary({account: reserveBeneficiary, amount: RESERVE_TOTAL_AMOUNT});

        beneficiaries = [
            seedBeneficiaries,
            strategicBeneficiaries,
            idoBeneficiaries,
            teamBeneficiaries,
            advisorsBeneficiaries,
            ecosystemBeneficiaries,
            liquidityBeneficiaries,
            reserveBeneficiaries
        ];
    }

    function _getTotalAmount(VestingType vestingType) private pure returns (uint256 totalAmount) {
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

    function _getVestingPeriods(VestingType vestingType) private view returns (Period[] memory periods) {
        if (vestingType == VestingType.COMMUNITY_ROUND) {
            periods = _getCommunityRoundPeriods(vestingStartTime);
        }

        if (vestingType == VestingType.SEED_ROUND) {
            periods = _getSeedRoundPeriods(vestingStartTime);
        }

        if (vestingType == VestingType.STRATEGIC_ROUND) {
            periods = _getStrategicRoundPeriods(vestingStartTime);
        }

        if (vestingType == VestingType.IDO) {
            periods = _getIdoPeriods(vestingStartTime);
        }

        if (vestingType == VestingType.TEAM) {
            periods = _getTeamPeriods(vestingStartTime);
        }

        if (vestingType == VestingType.ADVISORS) {
            periods = _getAdvisorsPeriods(vestingStartTime);
        }

        if (vestingType == VestingType.ECOSYSTEM) {
            periods = _getEcosystemPeriods(vestingStartTime);
        }

        if (vestingType == VestingType.LIQUIDITY) {
            periods = _getLiquidityPeriods(vestingStartTime);
        }

        if (vestingType == VestingType.RESERVE) {
            periods = _getReservePeriods(vestingStartTime);
        }
    }

    function _getCommunityRoundPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint40 cliffPeriod = 2 * MONTH;

        periods = new Period[](10);

        periods[0] = Period({endTime: startTime, portion: 15e8}); // 15%
        periods[1] = Period({endTime: startTime + cliffPeriod, portion: 0});
        periods[2] = Period({endTime: startTime + cliffPeriod + MONTH, portion: 10.625e8}); // 10.625%
        periods[3] = Period({endTime: startTime + cliffPeriod + 2 * MONTH, portion: 10.625e8});
        periods[4] = Period({endTime: startTime + cliffPeriod + 3 * MONTH, portion: 10.625e8});
        periods[5] = Period({endTime: startTime + cliffPeriod + 4 * MONTH, portion: 10.625e8});
        periods[6] = Period({endTime: startTime + cliffPeriod + 5 * MONTH, portion: 10.625e8});
        periods[7] = Period({endTime: startTime + cliffPeriod + 6 * MONTH, portion: 10.625e8});
        periods[8] = Period({endTime: startTime + cliffPeriod + 7 * MONTH, portion: 10.625e8});
        periods[9] = Period({endTime: startTime + cliffPeriod + 8 * MONTH, portion: 10.625e8});
    }

    function _getSeedRoundPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint40 cliffPeriod = 6 * MONTH;
        periods = new Period[](20);

        periods[0] = Period({endTime: startTime, portion: 10e8}); // 10%
        periods[1] = Period({endTime: startTime + cliffPeriod, portion: 0});
        periods[2] = Period({endTime: startTime + cliffPeriod + MONTH, portion: 5e8}); // 5%
        periods[3] = Period({endTime: startTime + cliffPeriod + 2 * MONTH, portion: 5e8});
        periods[4] = Period({endTime: startTime + cliffPeriod + 3 * MONTH, portion: 5e8});
        periods[5] = Period({endTime: startTime + cliffPeriod + 4 * MONTH, portion: 5e8});
        periods[6] = Period({endTime: startTime + cliffPeriod + 5 * MONTH, portion: 5e8});
        periods[7] = Period({endTime: startTime + cliffPeriod + 6 * MONTH, portion: 5e8});
        periods[8] = Period({endTime: startTime + cliffPeriod + 7 * MONTH, portion: 5e8});
        periods[9] = Period({endTime: startTime + cliffPeriod + 8 * MONTH, portion: 5e8});
        periods[10] = Period({endTime: startTime + cliffPeriod + 9 * MONTH, portion: 5e8});
        periods[11] = Period({endTime: startTime + cliffPeriod + 10 * MONTH, portion: 5e8});
        periods[12] = Period({endTime: startTime + cliffPeriod + 11 * MONTH, portion: 5e8});
        periods[13] = Period({endTime: startTime + cliffPeriod + 12 * MONTH, portion: 5e8});
        periods[14] = Period({endTime: startTime + cliffPeriod + 13 * MONTH, portion: 5e8});
        periods[15] = Period({endTime: startTime + cliffPeriod + 14 * MONTH, portion: 5e8});
        periods[16] = Period({endTime: startTime + cliffPeriod + 15 * MONTH, portion: 5e8});
        periods[17] = Period({endTime: startTime + cliffPeriod + 16 * MONTH, portion: 5e8});
        periods[18] = Period({endTime: startTime + cliffPeriod + 17 * MONTH, portion: 5e8});
        periods[19] = Period({endTime: startTime + cliffPeriod + 18 * MONTH, portion: 5e8});
    }

    function _getStrategicRoundPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint40 cliffPeriod = 3 * MONTH;
        periods = new Period[](14);

        periods[0] = Period({endTime: startTime, portion: 4e8}); // 4%
        periods[1] = Period({endTime: startTime + cliffPeriod, portion: 0});
        periods[2] = Period({endTime: startTime + cliffPeriod + MONTH, portion: 8e8}); // 8%
        periods[3] = Period({endTime: startTime + cliffPeriod + 2 * MONTH, portion: 8e8});
        periods[4] = Period({endTime: startTime + cliffPeriod + 3 * MONTH, portion: 8e8});
        periods[5] = Period({endTime: startTime + cliffPeriod + 4 * MONTH, portion: 8e8});
        periods[6] = Period({endTime: startTime + cliffPeriod + 5 * MONTH, portion: 8e8});
        periods[7] = Period({endTime: startTime + cliffPeriod + 6 * MONTH, portion: 8e8});
        periods[8] = Period({endTime: startTime + cliffPeriod + 7 * MONTH, portion: 8e8});
        periods[9] = Period({endTime: startTime + cliffPeriod + 8 * MONTH, portion: 8e8});
        periods[10] = Period({endTime: startTime + cliffPeriod + 9 * MONTH, portion: 8e8});
        periods[11] = Period({endTime: startTime + cliffPeriod + 10 * MONTH, portion: 8e8});
        periods[12] = Period({endTime: startTime + cliffPeriod + 11 * MONTH, portion: 8e8});
        periods[13] = Period({endTime: startTime + cliffPeriod + 12 * MONTH, portion: 8e8});
    }

    function _getIdoPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        periods = new Period[](7);

        periods[0] = Period({endTime: startTime, portion: 7e8}); // 7%
        periods[1] = Period({endTime: startTime + MONTH, portion: 10e8}); // 10%
        periods[2] = Period({endTime: startTime + 2 * MONTH, portion: 10e8});
        periods[3] = Period({endTime: startTime + 3 * MONTH, portion: 10e8});
        periods[4] = Period({endTime: startTime + 4 * MONTH, portion: 21e8}); // 21%
        periods[5] = Period({endTime: startTime + 5 * MONTH, portion: 21e8}); // 21%
        periods[6] = Period({endTime: startTime + 6 * MONTH, portion: 21e8}); // 21%
    }

    function _getTeamPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint40 cliffPeriod = 12 * MONTH;
        periods = new Period[](41);

        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});
        periods[1] = Period({endTime: startTime + cliffPeriod + MONTH, portion: 2.5e8}); // 2.5%
        periods[2] = Period({endTime: startTime + cliffPeriod + 2 * MONTH, portion: 2.5e8});
        periods[3] = Period({endTime: startTime + cliffPeriod + 3 * MONTH, portion: 2.5e8});
        periods[4] = Period({endTime: startTime + cliffPeriod + 4 * MONTH, portion: 2.5e8});
        periods[5] = Period({endTime: startTime + cliffPeriod + 5 * MONTH, portion: 2.5e8});
        periods[6] = Period({endTime: startTime + cliffPeriod + 6 * MONTH, portion: 2.5e8});
        periods[7] = Period({endTime: startTime + cliffPeriod + 7 * MONTH, portion: 2.5e8});
        periods[8] = Period({endTime: startTime + cliffPeriod + 8 * MONTH, portion: 2.5e8});
        periods[9] = Period({endTime: startTime + cliffPeriod + 9 * MONTH, portion: 2.5e8});
        periods[10] = Period({endTime: startTime + cliffPeriod + 10 * MONTH, portion: 2.5e8});
        periods[11] = Period({endTime: startTime + cliffPeriod + 11 * MONTH, portion: 2.5e8});
        periods[12] = Period({endTime: startTime + cliffPeriod + 12 * MONTH, portion: 2.5e8});
        periods[13] = Period({endTime: startTime + cliffPeriod + 13 * MONTH, portion: 2.5e8});
        periods[14] = Period({endTime: startTime + cliffPeriod + 14 * MONTH, portion: 2.5e8});
        periods[15] = Period({endTime: startTime + cliffPeriod + 15 * MONTH, portion: 2.5e8});
        periods[16] = Period({endTime: startTime + cliffPeriod + 16 * MONTH, portion: 2.5e8});
        periods[17] = Period({endTime: startTime + cliffPeriod + 17 * MONTH, portion: 2.5e8});
        periods[18] = Period({endTime: startTime + cliffPeriod + 18 * MONTH, portion: 2.5e8});
        periods[19] = Period({endTime: startTime + cliffPeriod + 19 * MONTH, portion: 2.5e8});
        periods[20] = Period({endTime: startTime + cliffPeriod + 20 * MONTH, portion: 2.5e8});
        periods[21] = Period({endTime: startTime + cliffPeriod + 21 * MONTH, portion: 2.5e8});
        periods[22] = Period({endTime: startTime + cliffPeriod + 22 * MONTH, portion: 2.5e8});
        periods[23] = Period({endTime: startTime + cliffPeriod + 23 * MONTH, portion: 2.5e8});
        periods[24] = Period({endTime: startTime + cliffPeriod + 24 * MONTH, portion: 2.5e8});
        periods[25] = Period({endTime: startTime + cliffPeriod + 25 * MONTH, portion: 2.5e8});
        periods[26] = Period({endTime: startTime + cliffPeriod + 26 * MONTH, portion: 2.5e8});
        periods[27] = Period({endTime: startTime + cliffPeriod + 27 * MONTH, portion: 2.5e8});
        periods[28] = Period({endTime: startTime + cliffPeriod + 28 * MONTH, portion: 2.5e8});
        periods[29] = Period({endTime: startTime + cliffPeriod + 29 * MONTH, portion: 2.5e8});
        periods[30] = Period({endTime: startTime + cliffPeriod + 30 * MONTH, portion: 2.5e8});
        periods[31] = Period({endTime: startTime + cliffPeriod + 31 * MONTH, portion: 2.5e8});
        periods[32] = Period({endTime: startTime + cliffPeriod + 32 * MONTH, portion: 2.5e8});
        periods[33] = Period({endTime: startTime + cliffPeriod + 33 * MONTH, portion: 2.5e8});
        periods[34] = Period({endTime: startTime + cliffPeriod + 34 * MONTH, portion: 2.5e8});
        periods[35] = Period({endTime: startTime + cliffPeriod + 35 * MONTH, portion: 2.5e8});
        periods[36] = Period({endTime: startTime + cliffPeriod + 36 * MONTH, portion: 2.5e8});
        periods[37] = Period({endTime: startTime + cliffPeriod + 37 * MONTH, portion: 2.5e8});
        periods[38] = Period({endTime: startTime + cliffPeriod + 38 * MONTH, portion: 2.5e8});
        periods[39] = Period({endTime: startTime + cliffPeriod + 39 * MONTH, portion: 2.5e8});
        periods[40] = Period({endTime: startTime + cliffPeriod + 40 * MONTH, portion: 2.5e8});
    }

    function _getAdvisorsPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint40 cliffPeriod = 9 * MONTH;
        periods = new Period[](21);

        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});
        periods[1] = Period({endTime: startTime + cliffPeriod + MONTH, portion: 5e8}); // 5%
        periods[2] = Period({endTime: startTime + cliffPeriod + 2 * MONTH, portion: 5e8});
        periods[3] = Period({endTime: startTime + cliffPeriod + 3 * MONTH, portion: 5e8});
        periods[4] = Period({endTime: startTime + cliffPeriod + 4 * MONTH, portion: 5e8});
        periods[5] = Period({endTime: startTime + cliffPeriod + 5 * MONTH, portion: 5e8});
        periods[6] = Period({endTime: startTime + cliffPeriod + 6 * MONTH, portion: 5e8});
        periods[7] = Period({endTime: startTime + cliffPeriod + 7 * MONTH, portion: 5e8});
        periods[8] = Period({endTime: startTime + cliffPeriod + 8 * MONTH, portion: 5e8});
        periods[9] = Period({endTime: startTime + cliffPeriod + 9 * MONTH, portion: 5e8});
        periods[10] = Period({endTime: startTime + cliffPeriod + 10 * MONTH, portion: 5e8});
        periods[11] = Period({endTime: startTime + cliffPeriod + 11 * MONTH, portion: 5e8});
        periods[12] = Period({endTime: startTime + cliffPeriod + 12 * MONTH, portion: 5e8});
        periods[13] = Period({endTime: startTime + cliffPeriod + 13 * MONTH, portion: 5e8});
        periods[14] = Period({endTime: startTime + cliffPeriod + 14 * MONTH, portion: 5e8});
        periods[15] = Period({endTime: startTime + cliffPeriod + 15 * MONTH, portion: 5e8});
        periods[16] = Period({endTime: startTime + cliffPeriod + 16 * MONTH, portion: 5e8});
        periods[17] = Period({endTime: startTime + cliffPeriod + 17 * MONTH, portion: 5e8});
        periods[18] = Period({endTime: startTime + cliffPeriod + 18 * MONTH, portion: 5e8});
        periods[19] = Period({endTime: startTime + cliffPeriod + 19 * MONTH, portion: 5e8});
        periods[20] = Period({endTime: startTime + cliffPeriod + 20 * MONTH, portion: 5e8});
    }

    function _getEcosystemPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint40 cliffPeriod = 3 * MONTH;
        periods = new Period[](41);

        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});
        periods[1] = Period({endTime: startTime + cliffPeriod + MONTH, portion: 2.5e8}); // 2.5%
        periods[2] = Period({endTime: startTime + cliffPeriod + 2 * MONTH, portion: 2.5e8});
        periods[3] = Period({endTime: startTime + cliffPeriod + 3 * MONTH, portion: 2.5e8});
        periods[4] = Period({endTime: startTime + cliffPeriod + 4 * MONTH, portion: 2.5e8});
        periods[5] = Period({endTime: startTime + cliffPeriod + 5 * MONTH, portion: 2.5e8});
        periods[6] = Period({endTime: startTime + cliffPeriod + 6 * MONTH, portion: 2.5e8});
        periods[7] = Period({endTime: startTime + cliffPeriod + 7 * MONTH, portion: 2.5e8});
        periods[8] = Period({endTime: startTime + cliffPeriod + 8 * MONTH, portion: 2.5e8});
        periods[9] = Period({endTime: startTime + cliffPeriod + 9 * MONTH, portion: 2.5e8});
        periods[10] = Period({endTime: startTime + cliffPeriod + 10 * MONTH, portion: 2.5e8});
        periods[11] = Period({endTime: startTime + cliffPeriod + 11 * MONTH, portion: 2.5e8});
        periods[12] = Period({endTime: startTime + cliffPeriod + 12 * MONTH, portion: 2.5e8});
        periods[13] = Period({endTime: startTime + cliffPeriod + 13 * MONTH, portion: 2.5e8});
        periods[14] = Period({endTime: startTime + cliffPeriod + 14 * MONTH, portion: 2.5e8});
        periods[15] = Period({endTime: startTime + cliffPeriod + 15 * MONTH, portion: 2.5e8});
        periods[16] = Period({endTime: startTime + cliffPeriod + 16 * MONTH, portion: 2.5e8});
        periods[17] = Period({endTime: startTime + cliffPeriod + 17 * MONTH, portion: 2.5e8});
        periods[18] = Period({endTime: startTime + cliffPeriod + 18 * MONTH, portion: 2.5e8});
        periods[19] = Period({endTime: startTime + cliffPeriod + 19 * MONTH, portion: 2.5e8});
        periods[20] = Period({endTime: startTime + cliffPeriod + 20 * MONTH, portion: 2.5e8});
        periods[21] = Period({endTime: startTime + cliffPeriod + 21 * MONTH, portion: 2.5e8});
        periods[22] = Period({endTime: startTime + cliffPeriod + 22 * MONTH, portion: 2.5e8});
        periods[23] = Period({endTime: startTime + cliffPeriod + 23 * MONTH, portion: 2.5e8});
        periods[24] = Period({endTime: startTime + cliffPeriod + 24 * MONTH, portion: 2.5e8});
        periods[25] = Period({endTime: startTime + cliffPeriod + 25 * MONTH, portion: 2.5e8});
        periods[26] = Period({endTime: startTime + cliffPeriod + 26 * MONTH, portion: 2.5e8});
        periods[27] = Period({endTime: startTime + cliffPeriod + 27 * MONTH, portion: 2.5e8});
        periods[28] = Period({endTime: startTime + cliffPeriod + 28 * MONTH, portion: 2.5e8});
        periods[29] = Period({endTime: startTime + cliffPeriod + 29 * MONTH, portion: 2.5e8});
        periods[30] = Period({endTime: startTime + cliffPeriod + 30 * MONTH, portion: 2.5e8});
        periods[31] = Period({endTime: startTime + cliffPeriod + 31 * MONTH, portion: 2.5e8});
        periods[32] = Period({endTime: startTime + cliffPeriod + 32 * MONTH, portion: 2.5e8});
        periods[33] = Period({endTime: startTime + cliffPeriod + 33 * MONTH, portion: 2.5e8});
        periods[34] = Period({endTime: startTime + cliffPeriod + 34 * MONTH, portion: 2.5e8});
        periods[35] = Period({endTime: startTime + cliffPeriod + 35 * MONTH, portion: 2.5e8});
        periods[36] = Period({endTime: startTime + cliffPeriod + 36 * MONTH, portion: 2.5e8});
        periods[37] = Period({endTime: startTime + cliffPeriod + 37 * MONTH, portion: 2.5e8});
        periods[38] = Period({endTime: startTime + cliffPeriod + 38 * MONTH, portion: 2.5e8});
        periods[39] = Period({endTime: startTime + cliffPeriod + 39 * MONTH, portion: 2.5e8});
        periods[40] = Period({endTime: startTime + cliffPeriod + 40 * MONTH, portion: 2.5e8});
    }

    function _getLiquidityPeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        periods = new Period[](21);

        periods[0] = Period({endTime: startTime, portion: 15e8}); // 15%
        periods[1] = Period({endTime: startTime + MONTH, portion: 4.25e8}); // 4.25%
        periods[2] = Period({endTime: startTime + 2 * MONTH, portion: 4.25e8});
        periods[3] = Period({endTime: startTime + 3 * MONTH, portion: 4.25e8});
        periods[4] = Period({endTime: startTime + 4 * MONTH, portion: 4.25e8});
        periods[5] = Period({endTime: startTime + 5 * MONTH, portion: 4.25e8});
        periods[6] = Period({endTime: startTime + 6 * MONTH, portion: 4.25e8});
        periods[7] = Period({endTime: startTime + 7 * MONTH, portion: 4.25e8});
        periods[8] = Period({endTime: startTime + 8 * MONTH, portion: 4.25e8});
        periods[9] = Period({endTime: startTime + 9 * MONTH, portion: 4.25e8});
        periods[10] = Period({endTime: startTime + 10 * MONTH, portion: 4.25e8});
        periods[11] = Period({endTime: startTime + 11 * MONTH, portion: 4.25e8});
        periods[12] = Period({endTime: startTime + 12 * MONTH, portion: 4.25e8});
        periods[13] = Period({endTime: startTime + 13 * MONTH, portion: 4.25e8});
        periods[14] = Period({endTime: startTime + 14 * MONTH, portion: 4.25e8});
        periods[15] = Period({endTime: startTime + 15 * MONTH, portion: 4.25e8});
        periods[16] = Period({endTime: startTime + 16 * MONTH, portion: 4.25e8});
        periods[17] = Period({endTime: startTime + 17 * MONTH, portion: 4.25e8});
        periods[18] = Period({endTime: startTime + 18 * MONTH, portion: 4.25e8});
        periods[19] = Period({endTime: startTime + 19 * MONTH, portion: 4.25e8});
        periods[20] = Period({endTime: startTime + 20 * MONTH, portion: 4.25e8});
    }

    function _getReservePeriods(uint40 startTime) private pure returns (Period[] memory periods) {
        uint40 cliffPeriod = 24 * MONTH;
        periods = new Period[](11);

        periods[0] = Period({endTime: startTime + cliffPeriod, portion: 0});
        periods[1] = Period({endTime: startTime + cliffPeriod + MONTH, portion: 10e8}); // 10%
        periods[2] = Period({endTime: startTime + cliffPeriod + 2 * MONTH, portion: 10e8});
        periods[3] = Period({endTime: startTime + cliffPeriod + 3 * MONTH, portion: 10e8});
        periods[4] = Period({endTime: startTime + cliffPeriod + 4 * MONTH, portion: 10e8});
        periods[5] = Period({endTime: startTime + cliffPeriod + 5 * MONTH, portion: 10e8});
        periods[6] = Period({endTime: startTime + cliffPeriod + 6 * MONTH, portion: 10e8});
        periods[7] = Period({endTime: startTime + cliffPeriod + 7 * MONTH, portion: 10e8});
        periods[8] = Period({endTime: startTime + cliffPeriod + 8 * MONTH, portion: 10e8});
        periods[9] = Period({endTime: startTime + cliffPeriod + 9 * MONTH, portion: 10e8});
        periods[10] = Period({endTime: startTime + cliffPeriod + 10 * MONTH, portion: 10e8});
    }

    // endregion
}
