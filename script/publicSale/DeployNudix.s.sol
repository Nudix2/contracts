// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {Nudix} from "src/Nudix.sol";

contract DeployNudix is Script {
    Nudix nudix;

    function run(address recipient) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        nudix = new Nudix(recipient);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("Nudix: ", address(nudix));
        console.log("Recipient of all supply token Nudix: ", recipient);
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain ID: ", block.chainid);
        console.log("Deployer: ", vm.addr(deployerPrivateKey));
    }

    function test() public {}
}
