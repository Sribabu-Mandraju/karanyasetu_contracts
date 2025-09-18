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
import "../../src/LocationDetails.sol";

contract DeployGov is Script {
    IERC20 public usdc = IERC20(0x036CbD53842c5426634e7929541eC2318f3dCF7e); //usdc address on base sepolia
    GeneralDonorBadge public generalBadge;
    DisasterDonorBadge public disasterBadge;

    IDAOGovernance public daoGovernance;
    IDisasterReliefFactory disasterReliefFactory;
    IFundEscrow fundEscrow;

    address admin = 0xcf744968135c87b91278C0Fe7a38b2459dac9733;

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

        // Deploy fundEscrow
        fundEscrow =
            new FundEscrow(address(disasterReliefFactory), address(generalBadge), address(daoGovernance), address(usdc));
        console.log("FundEscrow address", address(fundEscrow));

        // Set factory and escrow in governance
        daoGovernance.setDisasterReliefFactory(0x6F2dA9b816F80811A4dA21e511cb6235167a33Af);
        daoGovernance.setFundEscrow(0xE9FEfb23Ae5382390c54697EFD9E9d4AC3Cf1bdF);

        // //set allowed contracts in badges to mint NFTs
        generalBadge.setAllowedContract(address(fundEscrow));
        disasterBadge.setAllowedContract(address(disasterReliefFactory));

        vm.stopBroadcast();
    }
}
