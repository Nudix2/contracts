// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {COMMUNITY_ROUND_TOTAL_AMOUNT} from "src/vesting/utils/Common.sol";

contract DeployTemporaryNudixScript is Script {
    ERC20Mock temporaryNudix;

    function run() public {
        vm.startBroadcast();

        temporaryNudix = new ERC20Mock(18);
        temporaryNudix.mint(msg.sender, COMMUNITY_ROUND_TOTAL_AMOUNT);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("Temporary nudix token: ", address(temporaryNudix));
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain ID: ", block.chainid);
    }

    function test() public {}
}
