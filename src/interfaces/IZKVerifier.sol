// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZKVerifier {
    function registerNullifier(uint256 nullifier, uint256 campaignId) external;
    function isNullifierRegistered(uint256 nullifier, uint256 campaignId) external view returns (bool);
}
