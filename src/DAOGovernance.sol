// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDAOGovernance} from "./interfaces/IDAOGovernance.sol";
import {IDisasterReliefFactory} from "./interfaces/IDisasterReliefFactory.sol";
import {IFundEscrow} from "./interfaces/IFundEscrow.sol";
import "../../src/LocationDetails.sol";

contract DAOGovernance is IDAOGovernance {
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isDAOMember;
    address[] public daoMembers;
    uint256 public totalMembers; //totalMembers in the DAO

    uint256 private _nextProposalId;
    mapping(uint256 => Proposal) private _proposals; //mapping from proposalId to Proposal details
    mapping(uint256 => mapping(address => bool)) private _hasVoted;

    // governance parameters
    uint256 public votingPeriod = 2 days;

    IDisasterReliefFactory public disasterReliefFactory;
    IFundEscrow public fundEscrow;

    address public operator;

    // modifiers
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not an admin");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "Only operator can do this action");
        _;
    }

    modifier onlyDAOMember() {
        require(isDAOMember[msg.sender], "Not a DAO member");
        _;
    }

    constructor(address admin) {
        require(admin != address(0), "Admin address cannot be zero");
        isAdmin[admin] = true;
        isDAOMember[admin] = true;
        daoMembers.push(admin);
        totalMembers = 1;
        operator = admin;
    }

    function setDisasterReliefFactory(address factory) external onlyAdmin {
        //only one time factory set
        if (address(disasterReliefFactory) == address(0)) {
            disasterReliefFactory = IDisasterReliefFactory(factory);
        }
    }

    function setFundEscrow(address fundEscrowAddress) external onlyAdmin {
        if (address(fundEscrow) == address(0)) {
            fundEscrow = IFundEscrow(fundEscrowAddress);
        }
    }

    function addDAOMember(address member) external onlyAdmin {
        if (!isDAOMember[member]) {
            isDAOMember[member] = true;
            daoMembers.push(member);
            totalMembers++;
        } else {
            revert("Member already exists");
        }
    }

    function removeDAOMember(address member) external onlyAdmin {
        if (isDAOMember[member] && member != msg.sender) {
            isDAOMember[member] = false;
            deleteDAOMember(member);
            totalMembers--;
        } else {
            revert("Member already removed");
        }
    }

    function createProposal(
        string memory disasterName,
        LocationDetails.Location memory area,
        uint256 fundAmount,
        string memory image
    ) external override onlyDAOMember returns (uint256) {
        uint256 proposalId = ++_nextProposalId;

        _proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            disasterName: disasterName,
            location: area,
            fundsRequested: fundAmount,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            image: image,
            state: ProposalState.Active
        });

        emit ProposalCreated(proposalId, disasterName, area, fundAmount);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external override onlyDAOMember {
        Proposal storage proposal = _proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Proposal Not Active");
        require(block.timestamp < proposal.endTime, "Voting period has ended");
        require(!_hasVoted[proposalId][msg.sender], "Already voted");

        _hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.forVotes++;

            if (checkProposalPassed(proposalId)) {
                proposal.state = ProposalState.Passed;
            }
        } else {
            proposal.againstVotes++;
        }

        emit Voted(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external onlyOperator {
        Proposal storage proposal = _proposals[proposalId];
        require(proposal.state == ProposalState.Passed, "Proposal does not exist");

        // Deploy DisasterRelief contract via factory
        address disasterReliefAddress = disasterReliefFactory.deployDisasterRelief(
            proposal.id,
            proposal.disasterName,
            proposal.image,
            proposal.location,
            15 minutes, // donation period
            10 minutes, // registration period
            2 minutes, // waiting period
            1 days, // distribution period
            proposal.fundsRequested
        );
        uint256 escrowBalance = fundEscrow.getBalance();
        require(escrowBalance >= proposal.fundsRequested, "Insufficient funds in escrow");

        //add initial funds to the contract
        fundEscrow.allocateFunds(disasterReliefAddress, proposal.fundsRequested);

        emit ProposalExecuted(proposalId, disasterReliefAddress);
    }

    function checkProposalPassed(uint256 proposalId) internal view returns (bool) {
        Proposal memory proposal = _proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Proposal is Not Active");
        // check the for Vote count is satisfied
        if (proposal.forVotes >= calculateRequiredVotes()) {
            return true;
        } else if (proposal.againstVotes >= calculateRequiredVotes()) {
            //check for proposal rejection
            proposal.state = ProposalState.Rejected;
            return false;
        }
        return false;
    }

    function isProposalPassed(uint256 proposalId) external view override returns (bool) {
        return checkProposalPassed(proposalId);
    }

    function calculateRequiredVotes() internal view returns (uint256 votes) {
        return (60 * totalMembers + 99) / 100;
    }

    function deleteDAOMember(address member) internal {
        uint256 index = 0;
        for (uint256 i = 0; i < daoMembers.length; i++) {
            if (daoMembers[i] == member) {
                index = i;
                break;
            }
        }
        //swap logic
        daoMembers[index] = daoMembers[daoMembers.length - 1];
        daoMembers.pop();
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return _hasVoted[proposalId][voter];
    }

    function getProposal(uint256 proposalId) external view override returns (Proposal memory) {
        if (_proposals[proposalId].id == 0) {
            revert("Proposal Doesn't exist");
        }
        return _proposals[proposalId];
    }

    function proposalCount() external view returns (uint256) {
        return _nextProposalId;
    }

    function memberCount() external view returns (uint256) {
        return totalMembers;
    }

    function getProposalStatus(uint256 proposalId) external view returns (ProposalState) {
        return _proposals[proposalId].state;
    }

    function getDAOMembers() external view override returns (address[] memory) {
        return daoMembers;
    }
}
