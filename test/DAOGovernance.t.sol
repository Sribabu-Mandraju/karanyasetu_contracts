// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../test/MockUSDC.sol";
import {DAOGovernance, IDAOGovernance} from "../src/DAOGovernance.sol";
import {DAOGovernanceDeployer} from "../script/DAOGovernance.s.sol";
import {DeployMockUSDC} from "../script/MockUSDC.s.sol";
import {IDisasterRelief} from "../src/interfaces/IDisasterRelief.sol";
import {FundEscrow, IFundEscrow} from "../src/FundEscrow.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract DAOConstanst is Test {
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil default account

    // DAO members with labeled mock addresses
    address member1 = makeAddr("member1");
    address member2 = makeAddr("member2");
    address member3 = makeAddr("member3");
    address member4 = makeAddr("member4");
    address member5 = makeAddr("member5");

    address mockUsdc;
    IDAOGovernance daoGovernance;
    IFundEscrow fundEscrow;

    function setUp() public {
        // Deploy governance & fund escrow contracts
        vm.prank(admin);
        DAOGovernanceDeployer daoGovernanceDeployer = new DAOGovernanceDeployer();
        (address _daoGovernance, address _disasterReliefFactory, address _fundEscrow) = daoGovernanceDeployer.run();

        // Get the MockUSDC address used by the FundEscrow contract
        mockUsdc = FundEscrow(_fundEscrow).USDC();
        console.log("Mock USDC address:", mockUsdc);

        daoGovernance = IDAOGovernance(_daoGovernance);
        fundEscrow = IFundEscrow(_fundEscrow);

        // Set factory and escrow in governance
        vm.prank(admin);
        daoGovernance.setDisasterReliefFactory(_disasterReliefFactory);
        vm.prank(admin);
        daoGovernance.setFundEscrow(_fundEscrow);

        // Mint USDC to member1 using the correct MockUSDC contract
        vm.prank(admin);
        MockUSDC(mockUsdc).mint(member1, 100000000e6);
        console.log("Mock USDC balance of member1:", MockUSDC(mockUsdc).balanceOf(member1));

        // Approve and donate to fundEscrow
        vm.prank(member1);
        MockUSDC(mockUsdc).approve(_fundEscrow, 10000e6);
        console.log("Mock USDC approved to fundEscrow");

        uint256 allow = MockUSDC(mockUsdc).allowance(member1, _fundEscrow);
        console.log("approval tokens", allow);

        vm.prank(member1);
        IFundEscrow(_fundEscrow).donate(10000e6);
        console.log("Mock USDC balance of member1 after donation:", MockUSDC(mockUsdc).balanceOf(member1));
    }

    modifier MembersAdded() {
        vm.startPrank(admin);
        daoGovernance.addDAOMember(member1);
        daoGovernance.addDAOMember(member2);
        daoGovernance.addDAOMember(member3);
        daoGovernance.addDAOMember(member4);
        daoGovernance.addDAOMember(member5);
        vm.stopPrank();
        _;
    }

    modifier ProposalCreated() {
        vm.startPrank(member1);
        uint256 proposalId =
            daoGovernance.createProposal("Hudud Cyclone", "Chennai", 6 * 24 * 60 * 60, 1000, "cyclone.jpg");
        assert(proposalId == 1);
        assert(daoGovernance.getProposal(proposalId).id == 1);
        assert(daoGovernance.getProposal(proposalId).duration == 6 * 24 * 60 * 60);
        assert(daoGovernance.getProposal(proposalId).fundsRequested == 1000);
        assert(daoGovernance.getProposal(proposalId).proposer == member1);
        vm.stopPrank();
        _;
    }

    function test_addMembers() public {
        vm.startPrank(admin);
        daoGovernance.addDAOMember(member1);
        daoGovernance.addDAOMember(member2);
        daoGovernance.addDAOMember(member3);
        daoGovernance.addDAOMember(member4);
        daoGovernance.addDAOMember(member5);
        vm.stopPrank();
    }

    function test_CreateProposal() public {
        test_addMembers();
        vm.startPrank(member1);
        uint256 proposalId =
            daoGovernance.createProposal("Hudud Cyclone", "Chennai", 6 * 24 * 60 * 60, 1000, "cyclone.jpg");
        assert(proposalId == 1);
        assert(daoGovernance.getProposal(proposalId).id == 1);
        assert(daoGovernance.getProposal(proposalId).duration == 6 * 24 * 60 * 60);
        assert(daoGovernance.getProposal(proposalId).fundsRequested == 1000);
        assert(daoGovernance.getProposal(proposalId).proposer == member1);
        vm.stopPrank();
    }

    function test_VoteSuccess() public MembersAdded ProposalCreated {
        vm.startPrank(member2);
        daoGovernance.vote(1, true);
        assert(daoGovernance.getProposal(1).forVotes == 1);
        assert(daoGovernance.hasVoted(1, member2) == true);
        vm.stopPrank();
    }

    function test_proposalPassed() public MembersAdded ProposalCreated {
        // 6 members in DAO; at least 4 need to vote
        vm.prank(member2);
        daoGovernance.vote(1, true);

        vm.prank(member3);
        daoGovernance.vote(1, true);

        vm.prank(member4);
        daoGovernance.vote(1, true);

        vm.prank(member5);
        daoGovernance.vote(1, true);

        assert(daoGovernance.getProposal(1).forVotes == 4);
        assert(daoGovernance.getProposal(1).state == IDAOGovernance.ProposalState.Passed);
        console.log("Proposal passed successfully!");

        vm.prank(member1);
        MockUSDC(mockUsdc).approve(0x6187F206E5b64D97E5136B5779683a923EaEB1B4, 10000e6);
        vm.prank(member1);
        IDisasterRelief(0x6187F206E5b64D97E5136B5779683a923EaEB1B4).donate(10e6);
        assert(IDisasterRelief(0x6187F206E5b64D97E5136B5779683a923EaEB1B4).getTotalFunds() == 10e6);
        assert(IERC721(0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3).ownerOf(1) == member1);
    }
}
