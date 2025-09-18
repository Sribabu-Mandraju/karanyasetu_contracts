// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 100 * 10 ** decimals());
    }

    // Override to make it 6 decimals like real USDC
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Public mint function for testing purposes
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
