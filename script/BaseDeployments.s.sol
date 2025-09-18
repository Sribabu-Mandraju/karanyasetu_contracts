// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DAOGovernance, IDAOGovernance} from "../src/DAOGovernance.sol";
import {FundEscrow, IFundEscrow} from "../src/FundEscrow.sol";
import {DisasterReliefFactory, IDisasterReliefFactory} from "../src/DisasterReliefFactory.sol";
import {DisasterRelief, IDisasterRelief} from "../src/DisasterRelief.sol";
import {DisasterDonorBadge, INFTBadge} from "../src/DisasterDonorBadge.sol";
import {GeneralDonorBadge, INFTBadge} from "../src/GeneralDonorBadge.sol";
import {ZKVerifier} from "../src/ZKVerifier.sol";
import "../../src/LocationDetails.sol";

contract BaseDeployments is Script {
    IERC20 public usdc = IERC20(0x036CbD53842c5426634e7929541eC2318f3dCF7e); //usdc address on base sepolia
    GeneralDonorBadge public generalBadge;
    DisasterDonorBadge public disasterBadge;

    IDAOGovernance public daoGovernance;
    IDisasterReliefFactory disasterReliefFactory;
    IFundEscrow fundEscrow;

    address admin = 0xD087160A240C7FA9545680BdCb93939D760BAd12;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        //deploy nft badge contracts
        generalBadge = new GeneralDonorBadge();
        console.log("GeneralDonorBadge address", address(generalBadge));

        disasterBadge = new DisasterDonorBadge();
        console.log("DisasterDonorBadge address", address(disasterBadge));
        //set baseURI to nfts
        generalBadge.setBaseURI("ipfs://QmaeCzcmok8YQFV2mMrWtVii26284pV9k3TnouhogtsMRp/");
        disasterBadge.setBaseURI("ipfs://QmQvbWT14YLj8GbFLsnmi92nv4w5vZ2XErTN8reD2kpfuk/");

        //deploy zk verifier contract
        ZKVerifier zkverifier = new ZKVerifier();

        daoGovernance = new DAOGovernance(admin);
        console.log("DAOGovernance address", address(daoGovernance));
        // Deploy disaster relief factory
        disasterReliefFactory = new DisasterReliefFactory(
            address(daoGovernance),
            address(this), // zkverifier address
            address(usdc),
            address(disasterBadge)
        );
        console.log("DisasterReliefFactory address", address(disasterReliefFactory));

        //set zkverifier address in disaster relief
        disasterReliefFactory.setZKVerifier(address(zkverifier));

        // Deploy fundEscrow
        fundEscrow =
            new FundEscrow(address(disasterReliefFactory), address(generalBadge), address(daoGovernance), address(usdc));
        console.log("FundEscrow address", address(fundEscrow));

        // Set factory and escrow in governance
        daoGovernance.setDisasterReliefFactory(address(disasterReliefFactory));
        daoGovernance.setFundEscrow(address(fundEscrow));

        //set allowed contracts in badges to mint NFTs
        generalBadge.setAllowedContract(address(fundEscrow));
        disasterBadge.setAllowedContract(address(disasterReliefFactory));

        vm.stopBroadcast();
    }
}
