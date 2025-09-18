// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDisasterRelief} from "./interfaces/IDisasterRelief.sol";
import {IFundEscrow} from "./interfaces/IFundEscrow.sol";
import {DisasterDonorBadge} from "./DisasterDonorBadge.sol";
import {IAnonAadhaar} from "@anon-aadhaar/contracts/interfaces/IAnonAadhaar.sol";
import {IZKVerifier} from "./interfaces/IZKVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../src/LocationDetails.sol";

contract DisasterRelief is IDisasterRelief {
    using SafeERC20 for IERC20;

    // Base Sepolia USDC address (testnet)
    address public immutable USDC;

    uint256 disasterId;
    string public disasterName;
    string public disasterImage;
    LocationDetails.Location public location;
    ContractState public state;

    uint256 public donationEndTime;
    uint256 public registrationEndTime;
    uint256 public waitingEndTime;
    uint256 public distributionEndTime;

    uint256 public totalFunds;
    uint256 public totalDonors;
    uint256 public totalVictims;
    uint256 public distributedFunds; // Track funds that have already been distributed
    uint256 public amountPerVictim; // Store the calculated amount per victim

    DisasterDonorBadge public donorBadge;
    address public zkVerifier;

    mapping(address => bool) public donors;
    mapping(address => bool) public victims;
    mapping(address => bool) public hasWithdrawn;

    constructor(
        uint256 _disasterId,
        string memory _disasterName,
        string memory _disasterImage,
        LocationDetails.Location memory _location,
        uint256 _donationPeriod,
        uint256 _registrationPeriod,
        uint256 _waitingPeriod,
        uint256 _distributionPeriod,
        uint256 _initialFunds,
        address _donorBadge,
        address _zkVerifier,
        address _usdc
    ) {
        disasterId = _disasterId;
        disasterName = _disasterName;
        disasterImage = _disasterImage;
        location = _location;

        donationEndTime = block.timestamp + _donationPeriod;
        registrationEndTime = donationEndTime + _registrationPeriod;
        waitingEndTime = registrationEndTime + _waitingPeriod;
        distributionEndTime = waitingEndTime + _distributionPeriod;

        state = ContractState.Donation;
        totalFunds = _initialFunds;

        donorBadge = DisasterDonorBadge(_donorBadge);
        zkVerifier = _zkVerifier;
        USDC = _usdc;
    }

    // Automatically update state as needed before any external function is executed
    modifier autoUpdateState() {
        updateState();
        _;
    }

    function donate(uint256 amount) external override autoUpdateState {
        require(state == ContractState.Donation, "Campaign status mismatch");
        require(amount > 0, "Amount must be positive");

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);
        totalFunds += amount;

        if (!donors[msg.sender]) {
            donors[msg.sender] = true;
            totalDonors++;
            donorBadge.mint(msg.sender);
        }

        emit DonationReceived(msg.sender, amount);
    }

    function registerAsVictim(
        uint256 nullifierSeed,
        uint256 nullifier,
        uint256 timestamp,
        uint256[4] memory dataToReveal,
        uint256[8] memory groth16Proof
    ) external override autoUpdateState {
        require(state == ContractState.Registration, "Registrations Not started");
        require(!victims[msg.sender], "Already registered");
        require(
            IAnonAadhaar(zkVerifier).verifyAnonAadhaarProof(
                nullifierSeed, nullifier, timestamp, disasterId, dataToReveal, groth16Proof
            ),
            "Invalid proof"
        );
        //set the state in zkVerifier
        IZKVerifier(zkVerifier).registerNullifier(nullifier, disasterId);
        victims[msg.sender] = true;
        totalVictims++;

        emit VictimRegistered(msg.sender);
    }

    function calculateAmountPerVictim() internal {
        if (amountPerVictim == 0 && totalVictims > 0) {
            // ensuring we don't distribute more than available funds
            amountPerVictim = totalFunds / totalVictims;
        }
    }

    function withdrawFunds() external override autoUpdateState {
        require(state == ContractState.Distribution, "Campaign status mismatch");
        require(victims[msg.sender], "Not a registered victim");
        require(!hasWithdrawn[msg.sender], "Already withdrawn");

        // calculate amount per victim if not already calculated
        calculateAmountPerVictim();

        //  ensure we have enough funds
        uint256 actualBalance = IERC20(USDC).balanceOf(address(this));
        uint256 amount = amountPerVictim;

        // if we somehow don't have enough funds, adjust the amount
        if (amount > actualBalance) {
            amount = actualBalance;
        }

        hasWithdrawn[msg.sender] = true;
        distributedFunds += amount;

        IERC20(USDC).safeTransfer(msg.sender, amount);

        emit FundsDistributed(msg.sender, amount);
    }

    function updateState() public {
        if (state == ContractState.Donation && block.timestamp >= donationEndTime) {
            state = ContractState.Registration;
            emit StateChanged(state);
        }
        if (state == ContractState.Registration && block.timestamp >= registrationEndTime) {
            state = ContractState.Waiting;
            emit StateChanged(state);
        }
        if (state == ContractState.Waiting && block.timestamp >= waitingEndTime) {
            state = ContractState.Distribution;
            // calculate the amount per victim when entering distribution state
            calculateAmountPerVictim();
            emit StateChanged(state);
        }
        if (state == ContractState.Distribution && block.timestamp >= distributionEndTime) {
            state = ContractState.Closed;
            emit StateChanged(state);
        }
    }

    function getState() external view override returns (ContractState) {
        return state;
    }

    function getTotalFunds() external view override returns (uint256) {
        return totalFunds;
    }

    function getDonorCount() external view override returns (uint256) {
        return totalDonors;
    }

    function getVictimCount() external view override returns (uint256) {
        return totalVictims;
    }

    function getDistributedFunds() external view returns (uint256) {
        return distributedFunds;
    }

    function getLocationDetails() external view override returns (LocationDetails.Location memory) {
        return location;
    }

    function getCampaginDetails() external view override returns (DisasterDetails memory) {
        DisasterDetails memory details = DisasterDetails({
            disasterId: disasterId,
            disasterName: disasterName,
            image: disasterImage,
            location: location,
            totalFunds: totalFunds,
            totalDonors: totalDonors,
            totalVictimsRegistered: totalVictims,
            state: state
        });
        return details;
    }
}
