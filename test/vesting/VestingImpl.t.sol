// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {VestingImpl, IVestingImpl} from "src/vesting/VestingImpl.sol";
import {Nudix} from "src/Nudix.sol";
import {Beneficiary, Schedule, Period, BASIS_POINTS} from "src/vesting/utils/Common.sol";

contract VestingImplTest is Test {
    using SafeERC20 for IERC20;

    uint256 public constant MONTH = 30 days;
    uint256 public constant VESTING_TOTAL_AMOUNT = 1_000_000e18;

    uint256 public constant BENEFICIARY_A_AMOUNT = VESTING_TOTAL_AMOUNT * 0.6e18 / 1e18; // 60%
    uint256 public constant BENEFICIARY_B_AMOUNT = VESTING_TOTAL_AMOUNT * 0.4e18 / 1e18; // 40%

    uint256 public constant SCHEDULE_TGE_PORTION = 20e8;
    uint256 public constant SCHEDULE_PERIOD_PORTION = 40e8;
    uint256 public constant SCHEDULE_TOTAL_PERIODS = 4;

    uint40 public immutable VESTING_TGE_END = uint40(block.timestamp) + 10;
    uint256 public immutable VESTING_CLIFF_END = VESTING_TGE_END + MONTH;
    uint256 public immutable VESTING_PERIOD_1_END = VESTING_CLIFF_END + MONTH;
    uint256 public immutable VESTING_PERIOD_2_END = VESTING_PERIOD_1_END + MONTH;

    address distributor;
    address beneficiaryA;
    address beneficiaryB;

    Nudix nudix;
    VestingImpl vesting;

    function setUp() external {
        distributor = makeAddr("distributor");
        beneficiaryA = makeAddr("beneficiaryA");
        beneficiaryB = makeAddr("beneficiaryB");

        nudix = new Nudix(distributor);

        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();
        vesting = _deployVesting(address(nudix), beneficiaries, schedule);
    }

    // region - Deploy vesting -

    function test_deploy() public {
        assertEq(vesting.getBaseToken(), address(nudix));
        assertEq(vesting.totalLocked() + vesting.totalUnlocked(), VESTING_TOTAL_AMOUNT);

        assertEq(vesting.getSchedule().startTime, VESTING_TGE_END);
        assertEq(vesting.getSchedule().periods.length, SCHEDULE_TOTAL_PERIODS);
        assertEq(vesting.getSchedule().periods[0].endTime, VESTING_TGE_END);
        assertEq(vesting.getSchedule().periods[0].portion, SCHEDULE_TGE_PORTION);
        assertEq(vesting.getSchedule().periods[1].endTime, VESTING_CLIFF_END);
        assertEq(vesting.getSchedule().periods[1].portion, 0);
        assertEq(vesting.getSchedule().periods[2].endTime, VESTING_PERIOD_1_END);
        assertEq(vesting.getSchedule().periods[2].portion, SCHEDULE_PERIOD_PORTION);
        assertEq(vesting.getSchedule().periods[3].endTime, VESTING_PERIOD_2_END);
        assertEq(vesting.getSchedule().periods[3].portion, SCHEDULE_PERIOD_PORTION);

        assertEq(vesting.unlockedOf(beneficiaryA), 0);
        assertEq(vesting.unlockedOf(beneficiaryB), 0);

        assertEq(vesting.lockedOf(beneficiaryA), BENEFICIARY_A_AMOUNT);
        assertEq(vesting.lockedOf(beneficiaryB), BENEFICIARY_B_AMOUNT);

        // simulate start vesting (= tge end)
        vm.warp(VESTING_TGE_END);

        assertEq(vesting.unlockedOf(beneficiaryA), BENEFICIARY_A_AMOUNT * SCHEDULE_TGE_PORTION / BASIS_POINTS);
        assertEq(vesting.unlockedOf(beneficiaryB), BENEFICIARY_B_AMOUNT * SCHEDULE_TGE_PORTION / BASIS_POINTS);

        assertEq(
            vesting.lockedOf(beneficiaryA), BENEFICIARY_A_AMOUNT * (BASIS_POINTS - SCHEDULE_TGE_PORTION) / BASIS_POINTS
        );
        assertEq(
            vesting.lockedOf(beneficiaryB), BENEFICIARY_B_AMOUNT * (BASIS_POINTS - SCHEDULE_TGE_PORTION) / BASIS_POINTS
        );
    }

    function test_deploy_emitVestingAndBeneficiariesInitialized() external {
        VestingImpl vestingImpl = new VestingImpl();
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(distributor, vestingAddress, VESTING_TOTAL_AMOUNT);

        vm.prank(distributor);
        IERC20(nudix).safeTransfer(vestingAddress, VESTING_TOTAL_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit IVestingImpl.ScheduleInitialized(schedule);

        vm.expectEmit(true, true, true, true);
        emit IVestingImpl.BeneficiariesInitialized(beneficiaries);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertInitializeImplementation() external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();
        VestingImpl vestingImpl = new VestingImpl();

        vm.expectRevert(Initializable.InvalidInitialization.selector);

        vestingImpl.initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertRepeatInitialize() external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        vm.expectRevert(Initializable.InvalidInitialization.selector);

        vesting.initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertIfInvalidStartTime() external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        schedule.startTime = 0;

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(IVestingImpl.InvalidStartTime.selector);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertIfBaseTokenIsZeroAddress() external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();
        address invalidBaseToken = address(0);

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(IVestingImpl.ZeroAddress.selector);

        VestingImpl(vestingAddress).initialize(invalidBaseToken, schedule, beneficiaries);
    }

    function test_deploy_revertIfInvalidPortion(uint256 invalidPortion) external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();
        invalidPortion = bound(invalidPortion, BASIS_POINTS + 1, type(uint64).max);
        schedule.periods[0].portion = invalidPortion;

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(IVestingImpl.InvalidPortion.selector);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertIfIncorrectPeriodTime(uint256 invalidPeriodTime) external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        vm.assume(invalidPeriodTime <= schedule.periods[2].endTime);
        schedule.periods[3].endTime = invalidPeriodTime;

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(IVestingImpl.IncorrectPeriodTime.selector);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertIfIncorrectTotalPeriodPortions() external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        schedule.periods[3].portion = BASIS_POINTS;

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(IVestingImpl.IncorrectTotalPeriodPortions.selector);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertIfZeroBeneficiaries() external {
        (, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(IVestingImpl.ZeroBeneficiaries.selector);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, new Beneficiary[](0));
    }

    function test_deploy_revertIfBeneficiaryIsZeroAddress() external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        beneficiaries[0].account = address(0);

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(IVestingImpl.ZeroAddress.selector);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertIfBeneficiaryIsZeroAmount() external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        beneficiaries[0].amount = 0;

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(IVestingImpl.ZeroAmount.selector);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertIfDuplicateBeneficiary() external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        beneficiaries[0].account = beneficiaries[1].account;

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.expectRevert(abi.encodeWithSelector(IVestingImpl.DuplicateBeneficiary.selector, beneficiaries[0].account));

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    function test_deploy_revertIfIncorrectAmountOfBeneficiaries(uint256 invalidVestingAmount) external {
        (Beneficiary[] memory beneficiaries, Schedule memory schedule) = _getBeneficiariesAndSchedule();

        nudix = new Nudix(distributor);

        invalidVestingAmount = bound(invalidVestingAmount, 0, nudix.totalSupply());
        vm.assume(invalidVestingAmount != VESTING_TOTAL_AMOUNT);

        VestingImpl vestingImpl = new VestingImpl();
        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.prank(distributor);
        IERC20(nudix).safeTransfer(vestingAddress, invalidVestingAmount);

        vm.expectRevert(IVestingImpl.IncorrectAmountOfBeneficiaries.selector);

        VestingImpl(vestingAddress).initialize(address(nudix), schedule, beneficiaries);
    }

    // endregion

    // region - Claim -

    function test_claim() external {
        // Simulate ending of the vesting
        vm.warp(VESTING_PERIOD_2_END + 1);

        assertEq(vesting.unlockedOf(beneficiaryA), BENEFICIARY_A_AMOUNT);
        assertEq(vesting.unlockedOf(beneficiaryB), BENEFICIARY_B_AMOUNT);
        assertEq(vesting.lockedOf(beneficiaryA), 0);
        assertEq(vesting.lockedOf(beneficiaryB), 0);

        assertEq(vesting.availableToClaim(beneficiaryA), BENEFICIARY_A_AMOUNT);
        assertEq(vesting.availableToClaim(beneficiaryB), BENEFICIARY_B_AMOUNT);

        vm.prank(beneficiaryA);
        vesting.claim();

        assertEq(nudix.balanceOf(beneficiaryA), BENEFICIARY_A_AMOUNT);
        assertEq(nudix.balanceOf(address(vesting)), VESTING_TOTAL_AMOUNT - BENEFICIARY_A_AMOUNT);
    }

    function test_claim_emitClaimed() external {
        // Simulate ending of the vesting
        vm.warp(VESTING_PERIOD_2_END + 1);

        vm.expectEmit(true, true, true, true);
        emit IVestingImpl.Claimed(beneficiaryA, BENEFICIARY_A_AMOUNT);

        vm.prank(beneficiaryA);
        vesting.claim();
    }

    function test_claim_zeroAmountIfVestingIsNotStarted() external {
        vm.prank(beneficiaryA);
        vesting.claim();

        assertEq(nudix.balanceOf(beneficiaryA), 0);
        assertEq(nudix.balanceOf(address(vesting)), VESTING_TOTAL_AMOUNT);
    }

    function test_claim_zeroAmountIfAvailableToClaimIsZero() external {
        // simulate middle of cliff period
        vm.warp(VESTING_TGE_END + (VESTING_CLIFF_END - VESTING_TGE_END) / 2);

        vm.prank(beneficiaryA);
        vesting.claim();

        // only for tge
        uint256 claimedAmount = BENEFICIARY_A_AMOUNT * SCHEDULE_TGE_PORTION / BASIS_POINTS;

        assertEq(nudix.balanceOf(beneficiaryA), claimedAmount);
        assertEq(nudix.balanceOf(address(vesting)), VESTING_TOTAL_AMOUNT - claimedAmount);

        // repeat claim return zeroAmount
        vm.prank(beneficiaryA);
        vesting.claim();

        assertEq(nudix.balanceOf(beneficiaryA), claimedAmount);
        assertEq(nudix.balanceOf(address(vesting)), VESTING_TOTAL_AMOUNT - claimedAmount);
    }

    function test_claim_partially() external {
        // Stage0. Simulate ending of the TGE
        vm.warp(VESTING_TGE_END);

        vm.prank(beneficiaryA);
        vesting.claim();

        uint256 expectedTgeAmount = BENEFICIARY_A_AMOUNT * SCHEDULE_TGE_PORTION / BASIS_POINTS;

        assertEq(nudix.balanceOf(beneficiaryA), expectedTgeAmount);
        assertEq(nudix.balanceOf(address(vesting)), VESTING_TOTAL_AMOUNT - expectedTgeAmount);

        // Stage1. Simulate middle of the first period
        vm.warp(VESTING_CLIFF_END + (VESTING_PERIOD_1_END - VESTING_CLIFF_END) / 2);

        vm.prank(beneficiaryA);
        vesting.claim();

        uint256 expectedMiddleOfPeriod1Amount =
            expectedTgeAmount + (BENEFICIARY_A_AMOUNT * SCHEDULE_PERIOD_PORTION / BASIS_POINTS) / 2;

        assertEq(nudix.balanceOf(beneficiaryA), expectedMiddleOfPeriod1Amount);
        assertEq(nudix.balanceOf(address(vesting)), VESTING_TOTAL_AMOUNT - expectedMiddleOfPeriod1Amount);

        // Stage2. Simulate middle of the second period
        vm.warp(VESTING_PERIOD_1_END + (VESTING_PERIOD_2_END - VESTING_PERIOD_1_END) / 2);

        vm.prank(beneficiaryA);
        vesting.claim();

        uint256 expectedPeriod1Amount = BENEFICIARY_A_AMOUNT * SCHEDULE_PERIOD_PORTION / BASIS_POINTS;
        uint256 expectedMiddleOfPeriod2Amount = expectedTgeAmount + expectedPeriod1Amount
            + (BENEFICIARY_A_AMOUNT * SCHEDULE_PERIOD_PORTION / BASIS_POINTS) / 2;

        assertEq(nudix.balanceOf(beneficiaryA), expectedMiddleOfPeriod2Amount);
        assertEq(nudix.balanceOf(address(vesting)), VESTING_TOTAL_AMOUNT - expectedMiddleOfPeriod2Amount);

        // Stage3. Simulate end of the second period
        vm.warp(VESTING_PERIOD_2_END + 1);

        vm.prank(beneficiaryA);
        vesting.claim();

        assertEq(nudix.balanceOf(beneficiaryA), BENEFICIARY_A_AMOUNT);
        assertEq(nudix.balanceOf(address(vesting)), VESTING_TOTAL_AMOUNT - BENEFICIARY_A_AMOUNT);
    }

    // endregion

    // region - Service function -

    function _deployVesting(address baseToken, Beneficiary[] memory beneficiaries, Schedule memory schedule)
        private
        returns (VestingImpl)
    {
        VestingImpl vestingImpl = new VestingImpl();

        address vestingAddress = Clones.clone(address(vestingImpl));

        vm.prank(distributor);
        IERC20(baseToken).safeTransfer(vestingAddress, VESTING_TOTAL_AMOUNT);

        VestingImpl(vestingAddress).initialize(baseToken, schedule, beneficiaries);

        return VestingImpl(vestingAddress);
    }

    function _getBeneficiariesAndSchedule()
        private
        view
        returns (Beneficiary[] memory beneficiaries, Schedule memory schedule)
    {
        beneficiaries = _getBeneficiaries();
        schedule = _getSchedule();
    }

    function _getBeneficiaries() private view returns (Beneficiary[] memory beneficiaries) {
        beneficiaries = new Beneficiary[](2);
        beneficiaries[0] = Beneficiary({account: beneficiaryA, amount: BENEFICIARY_A_AMOUNT});
        beneficiaries[1] = Beneficiary({account: beneficiaryB, amount: BENEFICIARY_B_AMOUNT});
    }

    function _getSchedule() private view returns (Schedule memory schedule) {
        Period[] memory periods = new Period[](SCHEDULE_TOTAL_PERIODS);

        // tge
        periods[0] = Period({endTime: VESTING_TGE_END, portion: SCHEDULE_TGE_PORTION});

        // cliff
        periods[1] = Period({endTime: VESTING_CLIFF_END, portion: 0});

        periods[2] = Period({endTime: VESTING_PERIOD_1_END, portion: SCHEDULE_PERIOD_PORTION});

        periods[3] = Period({endTime: VESTING_PERIOD_2_END, portion: SCHEDULE_PERIOD_PORTION});

        schedule = Schedule({startTime: VESTING_TGE_END, periods: periods});
    }

    // endregion
}