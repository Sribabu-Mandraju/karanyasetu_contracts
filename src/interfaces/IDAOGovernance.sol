// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/LocationDetails.sol";

interface IDAOGovernance {
    enum ProposalState {
        Active,
        Passed,
        Rejected
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string disasterName;
        LocationDetails.Location location;
        uint256 fundsRequested;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        string image; //campaign specific image
        ProposalState state;
    }

    event ProposalCreated(
        uint256 indexed proposalId, string disasterName, LocationDetails.Location location, uint256 fundAmount
    );
    event Voted(uint256 indexed proposalId, address voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId, address disasterReliefAddress);

    function createProposal(
        string memory disasterName,
        LocationDetails.Location memory location,
        uint256 fundsRequested,
        string memory image
    ) external returns (uint256);

    function vote(uint256 proposalId, bool support) external;

    function getProposal(uint256 proposalId) external view returns (Proposal memory);

    function hasVoted(uint256 proposalId, address voter) external view returns (bool);
    function executeProposal(uint256 proposalId) external;
    function isProposalPassed(uint256 proposalId) external view returns (bool);
    //added extra
    function setDisasterReliefFactory(address factory) external;

    function setFundEscrow(address fundEscrowAddress) external;

    function addDAOMember(address _member) external;

    function removeDAOMember(address _member) external;

    function isAdmin(address _admin) external view returns (bool);
    function isDAOMember(address _member) external view returns (bool);
    function proposalCount() external view returns (uint256);

    function memberCount() external view returns (uint256);

    function getDAOMembers() external view returns (address[] memory);
}
