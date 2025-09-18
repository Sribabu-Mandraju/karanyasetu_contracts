// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFundEscrow} from "./interfaces/IFundEscrow.sol";
import {IDisasterReliefFactory} from "./interfaces/IDisasterReliefFactory.sol";
import {GeneralDonorBadge} from "./GeneralDonorBadge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FundEscrow is IFundEscrow {
    using SafeERC20 for IERC20;

    address public USDC;

    IDisasterReliefFactory public factory;
    GeneralDonorBadge public donorBadge;
    address public daoGovernance;

    //tracks general donors
    mapping(address => bool) public donors;

    modifier onlyDAO() {
        require(msg.sender == daoGovernance, "Not DAO");
        _;
    }

    constructor(address _factory, address _donorBadge, address _daoGovernance, address _usdc) {
        require(_factory != address(0), "Invalid factory address");
        require(_donorBadge != address(0), "Invalid donor badge address");
        require(_daoGovernance != address(0), "Invalid DAO governance address");

        factory = IDisasterReliefFactory(_factory);
        donorBadge = GeneralDonorBadge(_donorBadge);
        daoGovernance = _daoGovernance;
        USDC = _usdc;
        //approving the governance contract to spend USDC
        IERC20(USDC).approve(_daoGovernance, type(uint256).max);
    }

    function donate(uint256 amount) external override {
        require(amount > 0, "Amount must be positive");

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);

        //ensures only 1 minted nft  per donor
        if (!donors[msg.sender]) {
            donors[msg.sender] = true;
            donorBadge.mint(msg.sender);
        }

        emit FundsDeposited(msg.sender, amount);
    }

    function allocateFunds(address reliefContract, uint256 amount) external override onlyDAO {
        require(factory.isDisasterRelief(reliefContract), "Invalid relief contract");
        require(amount <= getBalance(), "Insufficient funds");

        IERC20(USDC).safeTransfer(reliefContract, amount);
        emit FundsAllocated(reliefContract, amount);
    }

    function getBalance() public view override returns (uint256) {
        return IERC20(USDC).balanceOf(address(this));
    }
}
