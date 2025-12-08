// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// The factor used to calculate percentages for the vesting schedule period.
uint64 constant BASIS_POINTS = 1e10; // ex: 10% = 10e8, 10.625% = 10.625e8

struct Period {
    uint40 endTime;
    uint64 portion; // in BASIS_POINTS
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

// Total amount = 1_000_000_000
uint256 constant COMMUNITY_ROUND_TOTAL_AMOUNT = 30_000_000e18;
uint256 constant SEED_ROUND_TOTAL_AMOUNT = 70_000_000e18;
uint256 constant STRATEGIC_ROUND_TOTAL_AMOUNT = 110_000_000e18;
uint256 constant IDO_TOTAL_AMOUNT = 40_000_000e18;
uint256 constant TEAM_TOTAL_AMOUNT = 140_000_000e18;
uint256 constant ADVISORS_TOTAL_AMOUNT = 60_000_000e18;
uint256 constant ECOSYSTEM_TOTAL_AMOUNT = 200_000_000e18;
uint256 constant LIQUIDITY_TOTAL_AMOUNT = 150_000_000e18;
uint256 constant RESERVE_TOTAL_AMOUNT = 200_000_000e18;
