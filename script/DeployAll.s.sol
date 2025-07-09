// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {TemporaryNudix} from "src/TemporaryNudix.sol";
import {NudixSale} from "src/NudixSale.sol";

contract DeployAll is Script {
    TemporaryNudix temporaryNudix;
    NudixSale nudixSale;

    /// @notice Sale params. You need to edit this params
    uint256 constant START_TIME = 1752062400; // Wednesday, July 9, 2025 12:00:00 PM (GMT)
    uint256 constant MIN_PURCHASE = 1e18;
    uint256 constant ROUND_RATE = 0.00625e18; // 1 T-NUDIX per 0.00625 USDT
    uint256 constant ROUND_CAP = 100_000e18;

    function run(address tNudixAdmin, address USDT, address wallet, address saleOwner, address minter) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.envAddress("PUBLIC_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Stage 0. Deploy
        temporaryNudix = new TemporaryNudix(deployerPublicKey);
        nudixSale = new NudixSale(address(temporaryNudix), USDT, wallet, deployerPublicKey);

        // Stage 1. Grant minter roles

        // For NudixSale
        temporaryNudix.grantRole(temporaryNudix.MINTER_ROLE(), address(nudixSale));
        // For backend minter
        temporaryNudix.grantRole(temporaryNudix.MINTER_ROLE(), minter);

        // Stage 2. Start first sale
        nudixSale.startSale(START_TIME , MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        // Stage 3. Renounce deployer role
        temporaryNudix.grantRole(temporaryNudix.DEFAULT_ADMIN_ROLE(), tNudixAdmin);
        temporaryNudix.renounceRole(temporaryNudix.DEFAULT_ADMIN_ROLE(), deployerPublicKey);

        nudixSale.transferOwnership(saleOwner);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("Temporary nudix: ", address(temporaryNudix));
        console.log("Temporary nudix admin: ", tNudixAdmin);
        console.log("Nudix sale: ", address(nudixSale));
        console.log("Wallet: ", wallet);
        console.log("Nudix sale owner: ", saleOwner);

        console.log("------------------ Deployment info -----------------------");
        console.log("Chain ID: ", block.chainid);
        console.log("Deployer: ", vm.addr(deployerPrivateKey));
    }
}
