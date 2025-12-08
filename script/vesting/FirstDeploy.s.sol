// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {VestingParams} from "src/vesting/VestingParams.sol";
import {VestingImpl} from "src/vesting/VestingImpl.sol";
import {MigrationImpl} from "src/vesting/MigrationImpl.sol";
import {Distributor} from "src/vesting/Distributor.sol";
import {Nudix} from "src/Nudix.sol";

import {
    Beneficiary,
    SEED_ROUND_TOTAL_AMOUNT,
    STRATEGIC_ROUND_TOTAL_AMOUNT,
    IDO_TOTAL_AMOUNT,
    TEAM_TOTAL_AMOUNT,
    ADVISORS_TOTAL_AMOUNT,
    ECOSYSTEM_TOTAL_AMOUNT,
    LIQUIDITY_TOTAL_AMOUNT,
    RESERVE_TOTAL_AMOUNT
} from "src/vesting/utils/Common.sol";

contract FirstDeployScript is Script {
    // TODO: set up beneficiaries before deployment
    address constant SEED_ROUND_BENEFICIARY_ADDRESS = 0x0320f7e3fc8cCA3e619332404957A5C3d5A1831b;
    address constant STRATEGIC_ROUND_BENEFICIARY_ADDRESS = 0x0320f7e3fc8cCA3e619332404957A5C3d5A1831b;
    address constant IDO_BENEFICIARY_ADDRESS = 0x0320f7e3fc8cCA3e619332404957A5C3d5A1831b;
    address constant TEAM_BENEFICIARY_ADDRESS = 0x0320f7e3fc8cCA3e619332404957A5C3d5A1831b;
    address constant ADVISER_BENEFICIARY_ADDRESS = 0x0320f7e3fc8cCA3e619332404957A5C3d5A1831b;
    address constant ECOSYSTEM_BENEFICIARY_ADDRESS = 0x0320f7e3fc8cCA3e619332404957A5C3d5A1831b;
    address constant LIQUIDITY_BENEFICIARY_ADDRESS = 0x0320f7e3fc8cCA3e619332404957A5C3d5A1831b;
    address constant RESERVE_BENEFICIARY_ADDRESS = 0x0320f7e3fc8cCA3e619332404957A5C3d5A1831b;

    Nudix nudix;
    VestingParams vestingParams;
    VestingImpl vestingImpl;
    MigrationImpl migrationImpl;
    Distributor distributor;

    function run(address temporaryNudix, address sweepAccount) public {
        // Adding 5 minutes to block.timestamp to account for potential transaction confirmation delays in BNB Smart Chain,
        // ensuring startTime is set in the future relative to the block in which the transaction is included.
        uint40 startTime = uint40(block.timestamp + 5 minutes);

        Beneficiary[][8] memory beneficiaries = _getBeneficiaries();

        vm.startBroadcast();

        // Stage 1. Deploy VestingParams contract
        vestingParams = new VestingParams(startTime, beneficiaries);

        // Stage 2. Deploy Vesting and Migration implementations
        vestingImpl = new VestingImpl();
        migrationImpl = new MigrationImpl();

        // Stage 3. Deploy Distributor contract
        distributor = new Distributor(
            address(vestingParams),
            address(vestingImpl),
            address(migrationImpl),
            address(temporaryNudix),
            sweepAccount
        );

        // Stage 4. Deploy Nudix contract and mint to the distributor contract
        nudix = new Nudix(address(distributor));

        // Stage 5. Start vestings in Distributor
        distributor.startVestings(address(nudix));

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("Nudix: ", address(nudix));
        console.log("Distributor: ", address(distributor));
        console.log("VestingImpl: ", address(vestingImpl));
        console.log("MigrationImpl: ", address(migrationImpl));
    }

    function _getBeneficiaries() private pure returns (Beneficiary[][8] memory beneficiaries) {
        Beneficiary[] memory seedBeneficiaries = new Beneficiary[](1);
        seedBeneficiaries[0] = Beneficiary({account: SEED_ROUND_BENEFICIARY_ADDRESS, amount: SEED_ROUND_TOTAL_AMOUNT});

        Beneficiary[] memory strategicBeneficiaries = new Beneficiary[](1);
        strategicBeneficiaries[0] = Beneficiary({account: STRATEGIC_ROUND_BENEFICIARY_ADDRESS, amount: STRATEGIC_ROUND_TOTAL_AMOUNT});

        Beneficiary[] memory idoBeneficiaries = new Beneficiary[](1);
        idoBeneficiaries[0] = Beneficiary({account: IDO_BENEFICIARY_ADDRESS, amount: IDO_TOTAL_AMOUNT});

        Beneficiary[] memory teamBeneficiaries = new Beneficiary[](1);
        teamBeneficiaries[0] = Beneficiary({account: TEAM_BENEFICIARY_ADDRESS, amount: TEAM_TOTAL_AMOUNT});

        Beneficiary[] memory advisorsBeneficiaries = new Beneficiary[](1);
        advisorsBeneficiaries[0] = Beneficiary({account: ADVISER_BENEFICIARY_ADDRESS, amount: ADVISORS_TOTAL_AMOUNT});

        Beneficiary[] memory ecosystemBeneficiaries = new Beneficiary[](1);
        ecosystemBeneficiaries[0] = Beneficiary({account: ECOSYSTEM_BENEFICIARY_ADDRESS, amount: ECOSYSTEM_TOTAL_AMOUNT});

        Beneficiary[] memory liquidityBeneficiaries = new Beneficiary[](1);
        liquidityBeneficiaries[0] = Beneficiary({account: LIQUIDITY_BENEFICIARY_ADDRESS, amount: LIQUIDITY_TOTAL_AMOUNT});

        Beneficiary[] memory reserveBeneficiaries = new Beneficiary[](1);
        reserveBeneficiaries[0] = Beneficiary({account: RESERVE_BENEFICIARY_ADDRESS, amount: RESERVE_TOTAL_AMOUNT});

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

    function test() public {}
}
