// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {Nudix} from "src/Nudix.sol";

contract DeployNudix is Script {
    Nudix NUDIX;

    function run(address recipient) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        NUDIX = new Nudix(recipient);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("Nudix: ", address(NUDIX));
        console.log("Recipient of all supply token Nudix: ", recipient);
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain ID: ", block.chainid);
        console.log("Deployer: ", vm.addr(deployerPrivateKey));
    }
}
