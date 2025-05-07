// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {NudixSale} from "src/NudixSale.sol";

contract DeployNudixSale is Script {
    NudixSale nudixSale;

    function run(address temporaryNudix, address paymentToken, address wallet, address initialOwner) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        nudixSale = new NudixSale(temporaryNudix, paymentToken, wallet, initialOwner);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("NudixSale: ", address(nudixSale));
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain ID: ", block.chainid);
        console.log("Deployer: ", vm.addr(deployerPrivateKey));
    }
}
