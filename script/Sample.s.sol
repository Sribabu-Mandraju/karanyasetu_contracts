// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DAOGovernance, IDAOGovernance} from "../src/DAOGovernance.sol";
import {DisasterReliefFactory, IDisasterReliefFactory} from "../src/DisasterReliefFactory.sol";
import {DisasterRelief, IDisasterRelief} from "../src/DisasterRelief.sol";
import {FundEscrow, IFundEscrow} from "../src/FundEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExecuteProposal is Script {
    DAOGovernance dao = DAOGovernance(0x4799E4B5f6f74aB21778304B8b0919949f4366B3);
    FundEscrow escrow = FundEscrow(0xf3116cc4a8d404A07B435c4CAb55B1583CE43f87);
    IERC20 public usdc = IERC20(0x036CbD53842c5426634e7929541eC2318f3dCF7e); //usdc address on base sepolia

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        //donate to escrow
        usdc.approve(address(escrow), 30e6);
        escrow.donate(30e6);
        //check if donation is successful
        console.log("Donation successful", usdc.balanceOf(address(escrow)) == 30e6);
        //assertTrue(uint256(dao.getProposalStatus(1))==1);
        console.log("Proposal status", uint256(dao.getProposalStatus(1)));

        //execute proposal
        dao.executeProposal(1);
        //check if proposal is executed
        console.log(
            "Is proposal executed",
            DisasterReliefFactory(0x270e042cE306128c316e05f5D94F63EB69410f7F).getAllProposals().length == 1
        );
        vm.stopBroadcast();
    }
}
