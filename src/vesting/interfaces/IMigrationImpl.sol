// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Schedule, Beneficiary} from "../utils/Common.sol";

interface IMigrationImpl {
    function initialize(address baseToken, Schedule memory schedule, Beneficiary[] memory beneficiaries) external;
    // TODO
}