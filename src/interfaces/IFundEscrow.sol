// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFundEscrow {
    event FundsDeposited(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event FundsAllocated(address indexed toContract, uint256 amount);

    function donate(uint256 amount) external;
    function allocateFunds(address reliefContract, uint256 amount) external;
    function getBalance() external view returns (uint256);
}
