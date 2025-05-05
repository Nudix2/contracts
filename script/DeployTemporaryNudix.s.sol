// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {TemporaryNudix} from "src/TemporaryNudix.sol";

contract DeployTemporaryNudix is Script {
    TemporaryNudix temporaryNudix;

    function run(address admin) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        temporaryNudix = new TemporaryNudix(admin);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("TemporaryNudix: ", address(temporaryNudix));
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain ID: ", block.chainid);
        console.log("Deployer: ", vm.addr(deployerPrivateKey));
    }
}
