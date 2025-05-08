// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract DeployPaymentTokenScript is Script {
    ERC20Mock paymentToken;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        paymentToken = new ERC20Mock(18);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("Payment token: ", address(paymentToken));
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain ID: ", block.chainid);
    }
}
