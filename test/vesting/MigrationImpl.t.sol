// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {MigrationImpl, IMigrationImpl} from "src/vesting/MigrationImpl.sol";
import {Nudix} from "src/Nudix.sol";
import {TemporaryNudix} from "src/publicSale/TemporaryNudix.sol";
import {Schedule, Period, BASIS_POINTS} from "src/vesting/utils/Common.sol";

contract MigrationImplTest is Test {
    using SafeERC20 for IERC20;

    uint40 public constant MONTH = 30 days;
    uint256 public constant VESTING_TOTAL_AMOUNT = 1_000_000e18;

    uint64 public constant SCHEDULE_TGE_PORTION = 20e8;
    uint64 public constant SCHEDULE_PERIOD_PORTION = 40e8;
    uint64 public constant SCHEDULE_TOTAL_PERIODS = 4;

    uint40 public immutable VESTING_TGE_END = uint40(block.timestamp) + 10;
    uint40 public immutable VESTING_CLIFF_END = VESTING_TGE_END + MONTH;
    uint40 public immutable VESTING_PERIOD_1_END = VESTING_CLIFF_END + MONTH;
    uint40 public immutable VESTING_PERIOD_2_END = VESTING_PERIOD_1_END + MONTH;

    uint40 public constant CLAIM_PERIOD = 365 days;

    address distributor;
    address sweepAccount;
    address temporaryNudixAdmin;
    address temporaryNudixMinter;
    address beneficiary;

    Nudix nudix;
    TemporaryNudix temporaryNudix;
    MigrationImpl migration;

    function setUp() external {
        distributor = makeAddr("distributor");
        sweepAccount = makeAddr("sweepAccount");
        temporaryNudixAdmin = makeAddr("temporaryNudixAdmin");
        temporaryNudixMinter = makeAddr("temporaryNudixMinter");
        beneficiary = makeAddr("beneficiary");

        nudix = new Nudix(distributor);
        temporaryNudix = new TemporaryNudix(temporaryNudixAdmin);

        _mintTemporaryNudix(beneficiary, VESTING_TOTAL_AMOUNT);

        Schedule memory schedule = _getSchedule();
        migration = _deployMigration(address(nudix), address(temporaryNudix), schedule);
    }

    // region - Deploy migration -

    function test_deploy() public {
        address notBeneficiary = makeAddr("notBeneficiary");

        assertEq(migration.getBaseToken(), address(nudix));
        assertEq(migration.getTemporaryNudix(), address(temporaryNudix));
        assertEq(migration.getSweepAccount(), sweepAccount);
        assertEq(migration.getInitialLocked(beneficiary), temporaryNudix.totalSupply());
        assertEq(migration.totalLocked() + migration.totalUnlocked(), VESTING_TOTAL_AMOUNT);

        assertEq(migration.getSchedule().startTime, VESTING_TGE_END);
        assertEq(migration.getSchedule().periods.length, SCHEDULE_TOTAL_PERIODS);
        assertEq(migration.getSchedule().periods[0].endTime, VESTING_TGE_END);
        assertEq(migration.getSchedule().periods[0].portion, SCHEDULE_TGE_PORTION);
        assertEq(migration.getSchedule().periods[1].endTime, VESTING_CLIFF_END);
        assertEq(migration.getSchedule().periods[1].portion, 0);
        assertEq(migration.getSchedule().periods[2].endTime, VESTING_PERIOD_1_END);
        assertEq(migration.getSchedule().periods[2].portion, SCHEDULE_PERIOD_PORTION);
        assertEq(migration.getSchedule().periods[3].endTime, VESTING_PERIOD_2_END);
        assertEq(migration.getSchedule().periods[3].portion, SCHEDULE_PERIOD_PORTION);

        assertEq(migration.unlockedOf(notBeneficiary), 0);
        assertEq(migration.lockedOf(notBeneficiary), 0);

        assertEq(migration.unlockedOf(beneficiary), 0);
        assertEq(migration.lockedOf(beneficiary), VESTING_TOTAL_AMOUNT);

        // simulate start vesting (= tge end)
        vm.warp(VESTING_TGE_END);

        assertEq(migration.unlockedOf(beneficiary), VESTING_TOTAL_AMOUNT * SCHEDULE_TGE_PORTION / BASIS_POINTS);

        assertEq(
            migration.lockedOf(beneficiary), VESTING_TOTAL_AMOUNT * (BASIS_POINTS - SCHEDULE_TGE_PORTION) / BASIS_POINTS
        );
    }

    function test_deploy_emitVestingInitialized() external {
        MigrationImpl migrationImpl = new MigrationImpl();
        Schedule memory schedule = _getSchedule();

        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(distributor, migrationAddress, VESTING_TOTAL_AMOUNT);

        vm.prank(distributor);
        IERC20(nudix).safeTransfer(migrationAddress, VESTING_TOTAL_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit IMigrationImpl.ScheduleInitialized(schedule);

        MigrationImpl(migrationAddress).initialize(address(nudix), address(temporaryNudix), sweepAccount, schedule);
    }

    function test_deploy_revertInitializeImplementation() external {
        MigrationImpl migrationImpl = new MigrationImpl();
        Schedule memory schedule = _getSchedule();

        vm.expectRevert(Initializable.InvalidInitialization.selector);

        migrationImpl.initialize(address(nudix), address(temporaryNudix), sweepAccount, schedule);
    }

    function test_deploy_revertRepeatInitialize() external {
        Schedule memory schedule = _getSchedule();

        vm.expectRevert(Initializable.InvalidInitialization.selector);

        migration.initialize(address(nudix), address(temporaryNudix), sweepAccount, schedule);
    }

    function test_deploy_revertIfInvalidStartTime() external {
        Schedule memory schedule = _getSchedule();

        schedule.startTime = 0;

        MigrationImpl migrationImpl = new MigrationImpl();
        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.expectRevert(IMigrationImpl.InvalidStartTime.selector);

        MigrationImpl(migrationAddress).initialize(address(nudix), address(temporaryNudix), sweepAccount, schedule);
    }

    function test_deploy_revertIfBaseTokenIsZeroAddress() external {
        Schedule memory schedule = _getSchedule();
        address invalidBaseToken = address(0);

        MigrationImpl migrationImpl = new MigrationImpl();
        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.expectRevert(IMigrationImpl.ZeroAddress.selector);

        MigrationImpl(migrationAddress).initialize(invalidBaseToken, address(temporaryNudix), sweepAccount, schedule);
    }

    function test_deploy_revertIfTemporaryNudixIsZeroAddress() external {
        Schedule memory schedule = _getSchedule();
        address invalidTemporaryNudix = address(0);

        MigrationImpl migrationImpl = new MigrationImpl();
        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.expectRevert(IMigrationImpl.ZeroAddress.selector);

        MigrationImpl(migrationAddress).initialize(address(nudix), invalidTemporaryNudix, sweepAccount, schedule);
    }

    function test_deploy_revertIfSweepAccountIsZeroAddress() external {
        Schedule memory schedule = _getSchedule();
        address invalidSweepAccount = address(0);

        MigrationImpl migrationImpl = new MigrationImpl();
        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.expectRevert(IMigrationImpl.ZeroAddress.selector);

        MigrationImpl(migrationAddress)
            .initialize(address(nudix), address(temporaryNudix), invalidSweepAccount, schedule);
    }

    function test_deploy_revertIfInvalidPortion(uint64 invalidPortion) external {
        Schedule memory schedule = _getSchedule();
        invalidPortion = uint64(bound(invalidPortion, BASIS_POINTS + 1, type(uint64).max));
        schedule.periods[0].portion = invalidPortion;

        MigrationImpl migrationImpl = new MigrationImpl();
        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.expectRevert(IMigrationImpl.InvalidPortion.selector);

        MigrationImpl(migrationAddress).initialize(address(nudix), address(temporaryNudix), sweepAccount, schedule);
    }

    function test_deploy_revertIfIncorrectPeriodTime(uint40 invalidPeriodTime) external {
        Schedule memory schedule = _getSchedule();

        vm.assume(invalidPeriodTime <= schedule.periods[2].endTime);
        schedule.periods[3].endTime = invalidPeriodTime;

        MigrationImpl migrationImpl = new MigrationImpl();
        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.expectRevert(IMigrationImpl.IncorrectPeriodTime.selector);

        MigrationImpl(migrationAddress).initialize(address(nudix), address(temporaryNudix), sweepAccount, schedule);
    }

    function test_deploy_revertIfIncorrectTotalPeriodPortions() external {
        Schedule memory schedule = _getSchedule();

        schedule.periods[3].portion = BASIS_POINTS;

        MigrationImpl migrationImpl = new MigrationImpl();
        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.expectRevert(IMigrationImpl.IncorrectTotalPeriodPortions.selector);

        MigrationImpl(migrationAddress).initialize(address(nudix), address(temporaryNudix), sweepAccount, schedule);
    }

    // endregion

    // region - Claim -

    function _beforeEach_claim() private {
        vm.prank(temporaryNudixAdmin);
        temporaryNudix.addToWhitelist(address(migration));

        vm.prank(beneficiary);
        temporaryNudix.approve(address(migration), type(uint256).max);
    }

    function test_claim() external {
        _beforeEach_claim();

        // Simulate ending of the vesting
        vm.warp(VESTING_PERIOD_2_END + 1);

        assertEq(migration.unlockedOf(beneficiary), VESTING_TOTAL_AMOUNT);
        assertEq(migration.lockedOf(beneficiary), 0);

        assertEq(migration.availableToClaim(beneficiary), VESTING_TOTAL_AMOUNT);

        vm.prank(beneficiary);
        migration.claim();

        assertEq(nudix.balanceOf(beneficiary), VESTING_TOTAL_AMOUNT);
        assertEq(nudix.balanceOf(address(migration)), 0);
    }

    function test_claim_emitClaimed() external {
        _beforeEach_claim();

        // Simulate ending of the vesting
        vm.warp(VESTING_PERIOD_2_END + 1);

        vm.expectEmit(true, true, true, true);
        emit IMigrationImpl.Claimed(beneficiary, VESTING_TOTAL_AMOUNT);

        vm.prank(beneficiary);
        migration.claim();
    }

    function test_claim_zeroAmountIfVestingIsNotStarted() external {
        _beforeEach_claim();

        vm.prank(beneficiary);
        migration.claim();

        assertEq(nudix.balanceOf(beneficiary), 0);
        assertEq(nudix.balanceOf(address(migration)), VESTING_TOTAL_AMOUNT);
    }

    function test_claim_zeroAmountIfAvailableToClaimIsZero() external {
        _beforeEach_claim();

        // simulate middle of cliff period
        vm.warp(VESTING_TGE_END + (VESTING_CLIFF_END - VESTING_TGE_END) / 2);

        vm.prank(beneficiary);
        migration.claim();

        // only for tge
        uint256 claimedAmount = VESTING_TOTAL_AMOUNT * SCHEDULE_TGE_PORTION / BASIS_POINTS;

        assertEq(nudix.balanceOf(beneficiary), claimedAmount);
        assertEq(nudix.balanceOf(address(migration)), VESTING_TOTAL_AMOUNT - claimedAmount);

        // repeat claim return zeroAmount
        vm.prank(beneficiary);
        migration.claim();

        assertEq(nudix.balanceOf(beneficiary), claimedAmount);
        assertEq(nudix.balanceOf(address(migration)), VESTING_TOTAL_AMOUNT - claimedAmount);
    }

    function test_claim_partially() external {
        _beforeEach_claim();

        // Stage0. Simulate ending of the TGE
        vm.warp(VESTING_TGE_END);

        vm.prank(beneficiary);
        migration.claim();

        uint256 expectedTgeAmount = VESTING_TOTAL_AMOUNT * SCHEDULE_TGE_PORTION / BASIS_POINTS;

        assertEq(nudix.balanceOf(beneficiary), expectedTgeAmount);
        assertEq(nudix.balanceOf(address(migration)), VESTING_TOTAL_AMOUNT - expectedTgeAmount);

        // Stage1. Simulate middle of the first period
        vm.warp(VESTING_CLIFF_END + (VESTING_PERIOD_1_END - VESTING_CLIFF_END) / 2);

        vm.prank(beneficiary);
        migration.claim();

        uint256 expectedMiddleOfPeriod1Amount =
            expectedTgeAmount + (VESTING_TOTAL_AMOUNT * SCHEDULE_PERIOD_PORTION / BASIS_POINTS) / 2;

        assertEq(nudix.balanceOf(beneficiary), expectedMiddleOfPeriod1Amount);
        assertEq(nudix.balanceOf(address(migration)), VESTING_TOTAL_AMOUNT - expectedMiddleOfPeriod1Amount);

        // Stage2. Simulate middle of the second period
        vm.warp(VESTING_PERIOD_1_END + (VESTING_PERIOD_2_END - VESTING_PERIOD_1_END) / 2);

        vm.prank(beneficiary);
        migration.claim();

        uint256 expectedPeriod1Amount = VESTING_TOTAL_AMOUNT * SCHEDULE_PERIOD_PORTION / BASIS_POINTS;
        uint256 expectedMiddleOfPeriod2Amount = expectedTgeAmount + expectedPeriod1Amount
            + (VESTING_TOTAL_AMOUNT * SCHEDULE_PERIOD_PORTION / BASIS_POINTS) / 2;

        assertEq(nudix.balanceOf(beneficiary), expectedMiddleOfPeriod2Amount);
        assertEq(nudix.balanceOf(address(migration)), VESTING_TOTAL_AMOUNT - expectedMiddleOfPeriod2Amount);

        // Stage3. Simulate end of the second period
        vm.warp(VESTING_PERIOD_2_END + 1);

        vm.prank(beneficiary);
        migration.claim();

        assertEq(nudix.balanceOf(beneficiary), VESTING_TOTAL_AMOUNT);
        assertEq(nudix.balanceOf(address(migration)), VESTING_TOTAL_AMOUNT - VESTING_TOTAL_AMOUNT);
    }

    function test_claim_revertClaimPeriodEnded() external {
        Schedule memory schedule = _getSchedule();
        _beforeEach_claim();

        // Simulate ending of the vesting
        vm.warp(schedule.startTime + CLAIM_PERIOD + 1);

        vm.expectRevert(IMigrationImpl.ClaimPeriodEnded.selector);

        vm.prank(beneficiary);
        migration.claim();
    }

    // endregion

    // region - Sweep -

    function test_sweep() external {
        Schedule memory schedule = _getSchedule();

        // Simulate ending of the claim period
        vm.warp(schedule.startTime + CLAIM_PERIOD + 1);

        vm.prank(sweepAccount);
        migration.sweep(VESTING_TOTAL_AMOUNT);

        assertEq(nudix.balanceOf(sweepAccount), VESTING_TOTAL_AMOUNT);
        assertEq(nudix.balanceOf(address(migration)), 0);
    }

    function test_sweep_emitSwept() external {
        Schedule memory schedule = _getSchedule();

        // Simulate ending of the claim period
        vm.warp(schedule.startTime + CLAIM_PERIOD + 1);

        vm.expectEmit(true, true, true, true);
        emit IMigrationImpl.Swept(VESTING_TOTAL_AMOUNT);

        vm.prank(sweepAccount);
        migration.sweep(VESTING_TOTAL_AMOUNT);
    }

    function test_sweep_revertIfClaimPeriodIsNotEnded(uint40 timestamp) external {
        Schedule memory schedule = _getSchedule();

        timestamp = uint40(bound(timestamp, schedule.startTime, schedule.startTime + CLAIM_PERIOD));

        // Simulate ending of the claim period
        vm.warp(timestamp);

        vm.expectRevert(IMigrationImpl.ClaimPeriodIsNotEnded.selector);

        vm.prank(sweepAccount);
        migration.sweep(VESTING_TOTAL_AMOUNT);
    }

    function test_sweep_revertIfNotSweepAccount() external {
        Schedule memory schedule = _getSchedule();
        address notSweepAccount = makeAddr("notSweepAccount");

        // Simulate ending of the claim period
        vm.warp(schedule.startTime + CLAIM_PERIOD + 1);

        vm.expectRevert(IMigrationImpl.OnlySweepAccount.selector);

        vm.prank(notSweepAccount);
        migration.sweep(VESTING_TOTAL_AMOUNT);
    }

    // endregion

    // region - Service function -

    function _deployMigration(address baseTokenAddress, address temporaryNudixAddress, Schedule memory schedule)
        private
        returns (MigrationImpl)
    {
        MigrationImpl migrationImpl = new MigrationImpl();

        address migrationAddress = Clones.clone(address(migrationImpl));

        vm.prank(distributor);
        IERC20(baseTokenAddress).safeTransfer(migrationAddress, VESTING_TOTAL_AMOUNT);

        MigrationImpl(migrationAddress).initialize(baseTokenAddress, temporaryNudixAddress, sweepAccount, schedule);

        return MigrationImpl(migrationAddress);
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

    function _mintTemporaryNudix(address to, uint256 amount) private {
        bytes32 minterRole = temporaryNudix.MINTER_ROLE();

        vm.prank(temporaryNudixAdmin);
        temporaryNudix.grantRole(minterRole, temporaryNudixMinter);

        vm.prank(temporaryNudixMinter);
        temporaryNudix.mint(to, amount);
    }

    // endregion
}
