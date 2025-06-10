// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";

import {INudixSale} from "src/interfaces/INudixSale.sol";

contract FinishAndStartNudixSale is Script {
    /// @notice Sale params. You need to edit this params
    uint256 constant START_TIME = 1749556800; // Tuesday, June 10, 2025 12:00:00 PM (GMT)
    uint256 constant MIN_PURCHASE = 1e18;
    uint256 constant ROUND_RATE = 0.00625e18; // 1 T-NUDIX per 0.00625 USDT
    uint256 constant ROUND_CAP = 100_000e18;

    INudixSale nudixSale;

    function run(address nudixSaleAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        nudixSale = INudixSale(nudixSaleAddress);

        nudixSale.stopSale();
        nudixSale.startSale(START_TIME , MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.stopBroadcast();

        console.log("------------------ Contracts --------------------");
        console.log("NudixSale: ", address(nudixSale));
        console.log("------------------ Info -----------------------");
        console.log("Chain ID: ", block.chainid);
        console.log("Start time: ", START_TIME);
        console.log("Min purchase: ", MIN_PURCHASE);
        console.log("Round rate: ", ROUND_RATE);
        console.log("Round cap: ", ROUND_CAP);
    }
}
