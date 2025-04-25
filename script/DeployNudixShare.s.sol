// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {NudixShare} from "src/NudixShare.sol";

contract DeployNudixShare is Script {
    NudixShare nudixShare;

    function run(address admin, address minter) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        nudixShare = new NudixShare(admin, minter);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("NudixShare: ", "");
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain ID: ", block.chainid);
        console.log("Deployer: ", vm.addr(deployerPrivateKey));
    }
}
