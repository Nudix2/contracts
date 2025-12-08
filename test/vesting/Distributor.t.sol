// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";

import {Distributor, IDistributor} from "src/vesting/Distributor.sol";
import {VestingParams} from "src/vesting/VestingParams.sol";
import {VestingImpl, IVestingImpl} from "src/vesting/VestingImpl.sol";
import {MigrationImpl, IMigrationImpl} from "src/vesting/MigrationImpl.sol";
import {TemporaryNudix} from "src/publicSale/TemporaryNudix.sol";
import {Nudix} from "src/Nudix.sol";

import {
    Beneficiary,
    VestingType,
    Schedule,
    Period,
    getTotalAmountByVestingType
} from "src/vesting/utils/Common.sol";

uint256 constant TOTAL_AMOUNT = 1_000_000_000e18;

contract DistributorTest is Test {
    uint40 vestingStartTime;

    VestingParams vestingParams;
    VestingImpl vestingImpl;
    MigrationImpl migrationImpl;
    TemporaryNudix temporaryNudix;
    Distributor distributor;
    Nudix nudix;

    address seedBeneficiary;
    address strategicBeneficiary;
    address idoBeneficiary;
    address teamBeneficiary;
    address advisorBeneficiaryA;
    address advisorBeneficiaryB;
    address ecosystemBeneficiary;
    address liquidityBeneficiary;
    address reserveBeneficiary;

    address sweepAccount;
    address temporaryNudixAdmin;
    address temporaryNudixMinter;

    function setUp() public {
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

        sweepAccount = makeAddr("sweepAccount");
        temporaryNudixAdmin = makeAddr("temporaryNudixAdmin");
        temporaryNudixMinter = makeAddr("temporaryNudixMinter");

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();
        vestingParams = new VestingParams(vestingStartTime, beneficiaries);
        vestingImpl = new VestingImpl();
        migrationImpl = new MigrationImpl();
        temporaryNudix = new TemporaryNudix(temporaryNudixAdmin);

        _mintTemporaryNudix(address(this), getTotalAmountByVestingType(VestingType.COMMUNITY_ROUND));

        distributor = new Distributor(
            address(vestingParams), address(vestingImpl), address(migrationImpl), address(temporaryNudix), sweepAccount
        );

        nudix = new Nudix(address(distributor));
    }

    // region - Deploy -

    function test_deploy() external view {
        assertNotEq(address(distributor), address(0));

        assertEq(distributor.getVestingParams(), address(vestingParams));
        assertEq(distributor.getVestingImpl(), address(vestingImpl));
        assertEq(distributor.getMigrationImpl(), address(migrationImpl));
        assertEq(distributor.getTemporaryNudix(), address(temporaryNudix));
        assertEq(distributor.getSweepAccount(), address(sweepAccount));

        assertEq(nudix.balanceOf(address(distributor)), nudix.totalSupply());
        assertEq(nudix.balanceOf(address(distributor)), TOTAL_AMOUNT);
    }

    function test_deploy_revertIfVestingParamsIsZeroAddress() external {
        address invalidAddress = address(0);

        vm.expectRevert(IDistributor.ZeroAddress.selector);
        new Distributor(
            invalidAddress, address(vestingImpl), address(migrationImpl), address(temporaryNudix), sweepAccount
        );
    }

    function test_deploy_revertIfVestingImplIsZeroAddress() external {
        address invalidAddress = address(0);

        vm.expectRevert(IDistributor.ZeroAddress.selector);
        new Distributor(
            address(vestingParams), invalidAddress, address(migrationImpl), address(temporaryNudix), sweepAccount
        );
    }

    function test_deploy_revertIfMigrationImplIsZeroAddress() external {
        address invalidAddress = address(0);

        vm.expectRevert(IDistributor.ZeroAddress.selector);
        new Distributor(
            address(vestingParams), address(vestingImpl), invalidAddress, address(temporaryNudix), sweepAccount
        );
    }

    function test_deploy_revertIfTemporaryNudixIsZeroAddress() external {
        address invalidAddress = address(0);

        vm.expectRevert(IDistributor.ZeroAddress.selector);
        new Distributor(
            address(vestingParams), address(vestingImpl), address(migrationImpl), invalidAddress, sweepAccount
        );
    }

    function test_deploy_revertIfSweepAccountIsZeroAddress() external {
        address invalidAddress = address(0);

        vm.expectRevert(IDistributor.ZeroAddress.selector);
        new Distributor(
            address(vestingParams),
            address(vestingImpl),
            address(migrationImpl),
            address(temporaryNudix),
            invalidAddress
        );
    }

    // endregion

    // region - Start vestings -

    function test_startVestings_checkCommunityRound() external {
        VestingType vestingType = VestingType.COMMUNITY_ROUND;
        distributor.startVestings(address(nudix));

        address communityRoundVesting = distributor.getVestingByType(vestingType);
        assertNotEq(communityRoundVesting, address(0));

        assertEq(IMigrationImpl(communityRoundVesting).getBaseToken(), address(nudix));
        assertEq(IMigrationImpl(communityRoundVesting).getTemporaryNudix(), address(temporaryNudix));
        assertEq(IMigrationImpl(communityRoundVesting).getSweepAccount(), sweepAccount);
        assertEq(nudix.balanceOf(communityRoundVesting), getTotalAmountByVestingType(VestingType.COMMUNITY_ROUND));

        Schedule memory schedule = IMigrationImpl(communityRoundVesting).getSchedule();
        assertEq(schedule.startTime, vestingParams.getStartTime());

        for (uint256 i = 0; i < schedule.periods.length; i++) {
            Period memory period = schedule.periods[i];
            Period memory expectedPeriod = vestingParams.getSchedule(vestingType).periods[i];

            assertEq(period.endTime, expectedPeriod.endTime);
            assertEq(period.portion, expectedPeriod.portion);
        }
    }

    function test_startVestings_checkClassicalVesting() external {
        distributor.startVestings(address(nudix));

        uint256[9] memory totalAmounts = [
            getTotalAmountByVestingType(VestingType.COMMUNITY_ROUND),
            getTotalAmountByVestingType(VestingType.SEED_ROUND),
            getTotalAmountByVestingType(VestingType.STRATEGIC_ROUND),
            getTotalAmountByVestingType(VestingType.IDO),
            getTotalAmountByVestingType(VestingType.TEAM),
            getTotalAmountByVestingType(VestingType.ADVISORS),
            getTotalAmountByVestingType(VestingType.ECOSYSTEM),
            getTotalAmountByVestingType(VestingType.LIQUIDITY),
            getTotalAmountByVestingType(VestingType.RESERVE)
        ];

        Beneficiary[][9] memory rawBeneficiaries = [
            new Beneficiary[](0),
            _getBeneficiaries()[0],
            _getBeneficiaries()[1],
            _getBeneficiaries()[2],
            _getBeneficiaries()[3],
            _getBeneficiaries()[4],
            _getBeneficiaries()[5],
            _getBeneficiaries()[6],
            _getBeneficiaries()[7]
        ];

        for (uint256 i = uint256(VestingType.SEED_ROUND); i < uint256(VestingType.RESERVE); i++) {
            VestingType vestingType = VestingType(i);
            uint256 totalAmount = totalAmounts[i];
            Beneficiary[] memory beneficiaries = rawBeneficiaries[i];

            address vesting = distributor.getVestingByType(vestingType);
            assertNotEq(vesting, address(0));

            assertEq(IVestingImpl(vesting).getBaseToken(), address(nudix));
            assertEq(nudix.balanceOf(vesting), totalAmount);

            Schedule memory schedule = IVestingImpl(vesting).getSchedule();
            assertEq(schedule.startTime, vestingParams.getStartTime());

            for (uint256 j = 0; j < schedule.periods.length; j++) {
                Period memory period = schedule.periods[j];
                Period memory expectedPeriod = vestingParams.getSchedule(vestingType).periods[j];

                assertEq(period.endTime, expectedPeriod.endTime);
                assertEq(period.portion, expectedPeriod.portion);
            }

            for (uint256 k = 0; k < beneficiaries.length; k++) {
                Beneficiary memory beneficiary = beneficiaries[k];

                assertEq(IVestingImpl(vesting).lockedOf(beneficiary.account), beneficiary.amount);
            }
        }
    }

    // endregion

    // region - Private functions -

    function _getBeneficiaries() private view returns (Beneficiary[][8] memory beneficiaries) {
        Beneficiary[] memory seedBeneficiaries = new Beneficiary[](1);
        seedBeneficiaries[0] = Beneficiary({account: seedBeneficiary, amount: getTotalAmountByVestingType(VestingType.SEED_ROUND)});

        Beneficiary[] memory strategicBeneficiaries = new Beneficiary[](1);
        strategicBeneficiaries[0] = Beneficiary({account: strategicBeneficiary, amount: getTotalAmountByVestingType(VestingType.STRATEGIC_ROUND)});

        Beneficiary[] memory idoBeneficiaries = new Beneficiary[](1);
        idoBeneficiaries[0] = Beneficiary({account: idoBeneficiary, amount: getTotalAmountByVestingType(VestingType.IDO)});

        Beneficiary[] memory teamBeneficiaries = new Beneficiary[](1);
        teamBeneficiaries[0] = Beneficiary({account: teamBeneficiary, amount: getTotalAmountByVestingType(VestingType.TEAM)});

        Beneficiary[] memory advisorsBeneficiaries = new Beneficiary[](2);
        advisorsBeneficiaries[0] =
            Beneficiary({account: advisorBeneficiaryA, amount: getTotalAmountByVestingType(VestingType.ADVISORS) * 0.3e18 / 1e18});
        advisorsBeneficiaries[1] =
            Beneficiary({account: advisorBeneficiaryB, amount: getTotalAmountByVestingType(VestingType.ADVISORS) * 0.7e18 / 1e18});

        Beneficiary[] memory ecosystemBeneficiaries = new Beneficiary[](1);
        ecosystemBeneficiaries[0] = Beneficiary({account: ecosystemBeneficiary, amount: getTotalAmountByVestingType(VestingType.ECOSYSTEM)});

        Beneficiary[] memory liquidityBeneficiaries = new Beneficiary[](1);
        liquidityBeneficiaries[0] = Beneficiary({account: liquidityBeneficiary, amount: getTotalAmountByVestingType(VestingType.LIQUIDITY)});

        Beneficiary[] memory reserveBeneficiaries = new Beneficiary[](1);
        reserveBeneficiaries[0] = Beneficiary({account: reserveBeneficiary, amount: getTotalAmountByVestingType(VestingType.RESERVE)});

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
