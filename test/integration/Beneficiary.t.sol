// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";

import {Distributor} from "src/vesting/Distributor.sol";
import {VestingParams} from "src/vesting/VestingParams.sol";
import {VestingImpl, IVestingImpl} from "src/vesting/VestingImpl.sol";
import {MigrationImpl, IMigrationImpl} from "src/vesting/MigrationImpl.sol";
import {TemporaryNudix} from "src/publicSale/TemporaryNudix.sol";
import {Nudix} from "src/Nudix.sol";

import {
    Beneficiary,
    VestingType,
    Schedule,
    BASIS_POINTS,
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

contract BeneficiaryTest is Test {
    uint256 constant COMMUNITY_ROUND_BENEFICIARY_AMOUNT = 1_000_000e18;
    uint40 vestingStartTime;

    VestingParams vestingParams;
    VestingImpl vestingImpl;
    MigrationImpl migrationImpl;
    TemporaryNudix temporaryNudix;
    Distributor distributor;
    Nudix nudix;

    address communityBeneficiary;
    address seedBeneficiary;
    address strategicBeneficiary;
    address idoBeneficiary;
    address teamBeneficiary;
    address advisorBeneficiaryA;
    address advisorBeneficiaryB;
    address ecosystemBeneficiary;
    address liquidityBeneficiary;
    address reserveBeneficiary;

    address temporaryNudixAdmin;
    address temporaryNudixMinter;
    address sweepAccount;

    function setUp() external {
        vestingStartTime = uint40(block.timestamp) + 30 days;

        communityBeneficiary = makeAddr("communityBeneficiary");
        seedBeneficiary = makeAddr("seedBeneficiary");
        strategicBeneficiary = makeAddr("seedBeneficiary");
        idoBeneficiary = makeAddr("idoBeneficiary");
        teamBeneficiary = makeAddr("teamBeneficiary");
        advisorBeneficiaryA = makeAddr("advisorBeneficiaryA");
        advisorBeneficiaryB = makeAddr("advisorBeneficiaryB");
        ecosystemBeneficiary = makeAddr("ecosystemBeneficiary");
        liquidityBeneficiary = makeAddr("liquidityBeneficiary");
        reserveBeneficiary = makeAddr("reserveBeneficiary");
        temporaryNudixAdmin = makeAddr("temporaryNudixAdmin");
        temporaryNudixMinter = makeAddr("temporaryNudixMinter");
        sweepAccount = makeAddr("sweepAccount");

        _startVesting();
    }

    // region - Community round -

    // Stage 0. Vesting is not started yet
    function test_claim_communityRound() external {
        address migration = distributor.getVestingByType(VestingType.COMMUNITY_ROUND);
        vm.prank(communityBeneficiary);
        IMigrationImpl(migration).claim();

        assertEq(nudix.balanceOf(communityBeneficiary), 0);
        assertEq(nudix.balanceOf(migration), COMMUNITY_ROUND_TOTAL_AMOUNT);
        assertEq(IMigrationImpl(migration).lockedOf(communityBeneficiary), COMMUNITY_ROUND_BENEFICIARY_AMOUNT);
    }

    // Stage 1. Token generation event (TGE)
    function test_claim_communityRound_tge() external {
        address migration = distributor.getVestingByType(VestingType.COMMUNITY_ROUND);

        vm.warp(vestingStartTime);

        uint256 availableToClaimAmount = IMigrationImpl(migration).availableToClaim(communityBeneficiary);

        vm.startPrank(communityBeneficiary);

        temporaryNudix.approve(migration, availableToClaimAmount);
        IMigrationImpl(migration).claim();

        vm.stopPrank();

        Schedule memory schedule = vestingParams.getSchedule(VestingType.COMMUNITY_ROUND);
        uint256 expectedAmount = COMMUNITY_ROUND_BENEFICIARY_AMOUNT * schedule.periods[0].portion / BASIS_POINTS;

        assertEq(nudix.balanceOf(communityBeneficiary), expectedAmount);
        assertEq(nudix.balanceOf(migration), COMMUNITY_ROUND_TOTAL_AMOUNT - expectedAmount);
        assertEq(IMigrationImpl(migration).lockedOf(communityBeneficiary), COMMUNITY_ROUND_BENEFICIARY_AMOUNT - expectedAmount);
        assertEq(IMigrationImpl(migration).unlockedOf(communityBeneficiary), expectedAmount);
        assertEq(IMigrationImpl(migration).availableToClaim(communityBeneficiary), 0);
    }

    // Stage 2. Half of the first period
    function test_claim_communityRound_halfOfTheFirstPeriod() external {
        address migration = distributor.getVestingByType(VestingType.COMMUNITY_ROUND);

        Schedule memory schedule = vestingParams.getSchedule(VestingType.COMMUNITY_ROUND);

        // Skip tge and cliff
        uint40 halfOfTheFirstPeriodTimestamp = schedule.periods[2].endTime - (schedule.periods[2].endTime - schedule.periods[1].endTime) / 2;
        vm.warp(halfOfTheFirstPeriodTimestamp);

        uint256 availableToClaimAmount = IMigrationImpl(migration).availableToClaim(communityBeneficiary);

        vm.startPrank(communityBeneficiary);

        temporaryNudix.approve(migration, availableToClaimAmount);
        IMigrationImpl(migration).claim();

        vm.stopPrank();

        uint256 expectedTgeAmount = COMMUNITY_ROUND_BENEFICIARY_AMOUNT * schedule.periods[0].portion / BASIS_POINTS;
        uint256 expectedHalfOnTheFirstPeriodAmount = expectedTgeAmount + COMMUNITY_ROUND_BENEFICIARY_AMOUNT * schedule.periods[2].portion / BASIS_POINTS / 2;

        assertEq(nudix.balanceOf(communityBeneficiary), expectedHalfOnTheFirstPeriodAmount);
        assertEq(nudix.balanceOf(migration), COMMUNITY_ROUND_TOTAL_AMOUNT - expectedHalfOnTheFirstPeriodAmount);
        assertEq(IMigrationImpl(migration).lockedOf(communityBeneficiary), COMMUNITY_ROUND_BENEFICIARY_AMOUNT - expectedHalfOnTheFirstPeriodAmount);
        assertEq(IMigrationImpl(migration).unlockedOf(communityBeneficiary), expectedHalfOnTheFirstPeriodAmount);
        assertEq(IMigrationImpl(migration).availableToClaim(communityBeneficiary), 0);
    }

    // Stage 3. Half of the last period
    function test_claim_communityRound_halfOfTheLastPeriod() external {
        address migration = distributor.getVestingByType(VestingType.COMMUNITY_ROUND);

        Schedule memory schedule = vestingParams.getSchedule(VestingType.COMMUNITY_ROUND);

        // Skip tge and cliff
        uint256 lastPeriodIndex = schedule.periods.length - 1;
        uint40 halfOfTheLastPeriodTimestamp = schedule.periods[lastPeriodIndex].endTime - (schedule.periods[lastPeriodIndex].endTime - schedule.periods[lastPeriodIndex - 1].endTime) / 2;
        vm.warp(halfOfTheLastPeriodTimestamp);

        uint256 availableToClaimAmount = IMigrationImpl(migration).availableToClaim(communityBeneficiary);

        vm.startPrank(communityBeneficiary);

        temporaryNudix.approve(migration, availableToClaimAmount);
        IMigrationImpl(migration).claim();

        vm.stopPrank();

        uint256 expectedHalfOnTheLastPeriodAmount = COMMUNITY_ROUND_BENEFICIARY_AMOUNT - COMMUNITY_ROUND_BENEFICIARY_AMOUNT * schedule.periods[lastPeriodIndex].portion / BASIS_POINTS / 2;

        assertEq(nudix.balanceOf(communityBeneficiary), expectedHalfOnTheLastPeriodAmount);
        assertEq(nudix.balanceOf(migration), COMMUNITY_ROUND_TOTAL_AMOUNT - expectedHalfOnTheLastPeriodAmount);
        assertEq(IMigrationImpl(migration).lockedOf(communityBeneficiary), COMMUNITY_ROUND_BENEFICIARY_AMOUNT - expectedHalfOnTheLastPeriodAmount);
        assertEq(IMigrationImpl(migration).unlockedOf(communityBeneficiary), expectedHalfOnTheLastPeriodAmount);
        assertEq(IMigrationImpl(migration).availableToClaim(communityBeneficiary), 0);
    }

    // endregion

    // region - Team -

    // Stage 0. Vesting is not started yet
    function test_claim_team() external {
        address vesting = distributor.getVestingByType(VestingType.TEAM);

        vm.prank(teamBeneficiary);
        IVestingImpl(vesting).claim();

        assertEq(nudix.balanceOf(teamBeneficiary), 0);
        assertEq(nudix.balanceOf(vesting), TEAM_TOTAL_AMOUNT);
        assertEq(IVestingImpl(vesting).lockedOf(teamBeneficiary), TEAM_TOTAL_AMOUNT);
    }

    // Stage 1. Token generation event (TGE)
    function test_claim_team_tge() external {
        address vesting = distributor.getVestingByType(VestingType.TEAM);

        vm.warp(vestingStartTime);

        vm.prank(teamBeneficiary);
        IVestingImpl(vesting).claim();

        Schedule memory schedule = vestingParams.getSchedule(VestingType.TEAM);
        uint256 expectedAmount = TEAM_TOTAL_AMOUNT * schedule.periods[0].portion / BASIS_POINTS;

        assertEq(nudix.balanceOf(teamBeneficiary), expectedAmount);
        assertEq(nudix.balanceOf(vesting), TEAM_TOTAL_AMOUNT - expectedAmount);
        assertEq(IMigrationImpl(vesting).lockedOf(teamBeneficiary), TEAM_TOTAL_AMOUNT - expectedAmount);
        assertEq(IMigrationImpl(vesting).unlockedOf(teamBeneficiary), expectedAmount);
        assertEq(IMigrationImpl(vesting).availableToClaim(teamBeneficiary), 0);
    }

    // Stage 2. Half of the first period
    function test_claim_team_halfOfTheFirstPeriod() external {
        address vesting = distributor.getVestingByType(VestingType.TEAM);
        Schedule memory schedule = vestingParams.getSchedule(VestingType.TEAM);

        // Skip tge and cliff
        uint40 halfOfTheFirstPeriodTimestamp = schedule.periods[1].endTime - (schedule.periods[1].endTime - schedule.periods[0].endTime) / 2;
        vm.warp(halfOfTheFirstPeriodTimestamp);

        vm.prank(teamBeneficiary);
        IMigrationImpl(vesting).claim();

        uint256 expectedTgeAmount = TEAM_TOTAL_AMOUNT * schedule.periods[0].portion / BASIS_POINTS;
        uint256 expectedHalfOnTheFirstPeriodAmount = expectedTgeAmount + TEAM_TOTAL_AMOUNT * schedule.periods[2].portion / BASIS_POINTS / 2;

        assertEq(nudix.balanceOf(teamBeneficiary), expectedHalfOnTheFirstPeriodAmount);
        assertEq(nudix.balanceOf(vesting), TEAM_TOTAL_AMOUNT - expectedHalfOnTheFirstPeriodAmount);
        assertEq(IMigrationImpl(vesting).lockedOf(teamBeneficiary), TEAM_TOTAL_AMOUNT - expectedHalfOnTheFirstPeriodAmount);
        assertEq(IMigrationImpl(vesting).unlockedOf(teamBeneficiary), expectedHalfOnTheFirstPeriodAmount);
        assertEq(IMigrationImpl(vesting).availableToClaim(teamBeneficiary), 0);
    }

    // Stage 3. Half of the last period
    function test_claim_team_halfOfTheLastPeriod() external {
        address vesting = distributor.getVestingByType(VestingType.TEAM);

        Schedule memory schedule = vestingParams.getSchedule(VestingType.TEAM);

        // Skip tge and cliff
        uint256 lastPeriodIndex = schedule.periods.length - 1;
        uint40 halfOfTheLastPeriodTimestamp = schedule.periods[lastPeriodIndex].endTime - (schedule.periods[lastPeriodIndex].endTime - schedule.periods[lastPeriodIndex - 1].endTime) / 2;
        vm.warp(halfOfTheLastPeriodTimestamp);

        vm.prank(teamBeneficiary);
        IMigrationImpl(vesting).claim();

        uint256 expectedHalfOnTheLastPeriodAmount = TEAM_TOTAL_AMOUNT - TEAM_TOTAL_AMOUNT * schedule.periods[lastPeriodIndex].portion / BASIS_POINTS / 2;

        assertEq(nudix.balanceOf(teamBeneficiary), expectedHalfOnTheLastPeriodAmount);
        assertEq(nudix.balanceOf(vesting), TEAM_TOTAL_AMOUNT - expectedHalfOnTheLastPeriodAmount);
        assertEq(IMigrationImpl(vesting).lockedOf(teamBeneficiary), TEAM_TOTAL_AMOUNT - expectedHalfOnTheLastPeriodAmount);
        assertEq(IMigrationImpl(vesting).unlockedOf(teamBeneficiary), expectedHalfOnTheLastPeriodAmount);
        assertEq(IMigrationImpl(vesting).availableToClaim(teamBeneficiary), 0);
    }

    // endregion

    // region - Private functions -

    function _startVesting() private {
        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();

        // Stage 0. Deploy TemporaryNudix contract. It's deployed in real scenario before Distributor contract during public sale
        temporaryNudix = new TemporaryNudix(temporaryNudixAdmin);

        // Stage 1. Deploy VestingParams contract
        vestingParams = new VestingParams(vestingStartTime, beneficiaries);

        // Stage 2. Deploy Vesting and Migration implementations
        vestingImpl = new VestingImpl();
        migrationImpl = new MigrationImpl();

        // Simulate that temporary Nudix was minted and sold during public sale
        _mintTemporaryNudix(address(this), COMMUNITY_ROUND_TOTAL_AMOUNT - COMMUNITY_ROUND_BENEFICIARY_AMOUNT);
        _mintTemporaryNudix(communityBeneficiary, COMMUNITY_ROUND_BENEFICIARY_AMOUNT);

        // Stage 3. Deploy Distributor contract
        distributor = new Distributor(
            address(vestingParams), address(vestingImpl), address(migrationImpl), address(temporaryNudix), sweepAccount
        );

        // Stage 4. Deploy Nudix contract and mint to the distributor contract
        nudix = new Nudix(address(distributor));

        // Stage 5. Start vestings in Distributor
        distributor.startVestings(address(nudix));

        // Stage6. Add migration contract to TemporaryNudix whitelist. This allows beneficiaries to claim their tokens and burn temporary nudix
        address migration = distributor.getVestingByType(VestingType.COMMUNITY_ROUND);
        vm.prank(temporaryNudixAdmin);
        temporaryNudix.addToWhitelist(migration);
    }

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

    function _mintTemporaryNudix(address to, uint256 amount) private {
        bytes32 minterRole = temporaryNudix.MINTER_ROLE();

        vm.prank(temporaryNudixAdmin);
        temporaryNudix.grantRole(minterRole, temporaryNudixMinter);

        vm.prank(temporaryNudixMinter);
        temporaryNudix.mint(to, amount);
    }

    // endregion
}