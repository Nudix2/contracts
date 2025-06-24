// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {TemporaryNudix} from "src/TemporaryNudix.sol";
import {NudixSale} from "src/NudixSale.sol";

contract DeployAll is Script {
    TemporaryNudix temporaryNudix;
    NudixSale nudixSale;

    function run(address tNudixAdmin, address USDT, address wallet, address saleOwner) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.envAddress("PUBLIC_KEY");

        vm.startBroadcast(deployerPrivateKey);

        temporaryNudix = new TemporaryNudix(deployerPublicKey);
        nudixSale = new NudixSale(address(temporaryNudix), USDT, wallet, saleOwner);

        temporaryNudix.grantRole(temporaryNudix.MINTER_ROLE(), address(nudixSale));
        temporaryNudix.grantRole(temporaryNudix.DEFAULT_ADMIN_ROLE(), tNudixAdmin);
        temporaryNudix.renounceRole(temporaryNudix.DEFAULT_ADMIN_ROLE(), deployerPublicKey);

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
