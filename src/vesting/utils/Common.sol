// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

struct Period {
    uint256 endTime;
    uint256 portion;
}

struct Schedule {
    uint256 startTime;
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
