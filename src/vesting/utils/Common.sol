// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// The factor used to calculate percentages for the vesting schedule period.
uint256 constant BASIS_POINTS = 1e10; // ex: 10% = 10e8, 10.625% = 10.625e8

struct Period {
    uint256 endTime; // TODO: uint40
    uint256 portion; // TODO: think about which uint
}

struct Schedule {
    uint40 startTime;
    Period[] periods;
}

struct Beneficiary {
    address account;
    uint256 amount;
}

uint8 constant NUMBER_OF_VESTING_TYPES = 9;
enum VestingType {
    COMMUNITY_ROUND,
    SEED_ROUND,
    STRATEGIC_ROUND,
    IDO,
    TEAM,
    ADVISORS,
    ECOSYSTEM,
    LIQUIDITY,
    RESERVE
}
