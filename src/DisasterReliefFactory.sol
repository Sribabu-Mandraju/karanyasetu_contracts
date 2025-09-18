// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDisasterReliefFactory} from "./interfaces/IDisasterReliefFactory.sol";
import {DisasterRelief} from "./DisasterRelief.sol";
import {IDAOGovernance} from "./interfaces/IDAOGovernance.sol";
import {DisasterDonorBadge} from "./DisasterDonorBadge.sol";
import {IFundEscrow} from "./interfaces/IFundEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../src/LocationDetails.sol";

contract DisasterReliefFactory is IDisasterReliefFactory {
    using SafeERC20 for IERC20;

    address public immutable USDC;

    IDAOGovernance public daoGov;
    address public zkVerifier;
    address public owner;
    DisasterDonorBadge public donorBadge;

    mapping(address => bool) public isDisasterRelief;
    address[] public disasterReliefContracts;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _daoGov, address _zkVerifier, address _usdc, address _donorBadge) {
        owner = msg.sender;
        daoGov = IDAOGovernance(_daoGov);
        //zkVerifier = _zkVerifier;
        USDC = _usdc;
        donorBadge = DisasterDonorBadge(_donorBadge);
    }

    function deployDisasterRelief(
        uint256 disasterId,
        string memory disasterName,
        string memory image,
        LocationDetails.Location memory area,
        uint256 donationPeriod,
        uint256 registrationPeriod,
        uint256 waitingPeriod,
        uint256 distributionPeriod,
        uint256 initialFunds
    ) external override returns (address) {
        require(msg.sender == address(daoGov), "Only DAOGov can deploy");

        DisasterRelief newRelief = new DisasterRelief(
            disasterId,
            disasterName,
            image,
            area,
            donationPeriod,
            registrationPeriod,
            waitingPeriod,
            distributionPeriod,
            initialFunds,
            address(donorBadge),
            zkVerifier,
            USDC
        );

        isDisasterRelief[address(newRelief)] = true;
        disasterReliefContracts.push(address(newRelief));
        emit DisasterReliefDeployed(address(newRelief), disasterName, initialFunds);
        return address(newRelief);
    }

    // function setDAOGovernance(address _daoGov) external onlyOwner {
    //     daoGov = IDAOGovernance(_daoGov);
    // }

    function getProposal(uint256 _index) external view returns (address) {
        return disasterReliefContracts[_index];
    }

    function getAllProposals() external view returns (address[] memory) {
        return disasterReliefContracts;
    }

    function setZKVerifier(address _zkVerifier) external onlyOwner {
        zkVerifier = _zkVerifier;
    }
}
