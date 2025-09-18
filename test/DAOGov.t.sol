// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../test/MockUSDC.sol";
import {DAOGovernance, IDAOGovernance} from "../src/DAOGovernance.sol";
import {FundEscrow, IFundEscrow} from "../src/FundEscrow.sol";
import {DisasterReliefFactory, IDisasterReliefFactory} from "../src/DisasterReliefFactory.sol";
import {DisasterRelief, IDisasterRelief} from "../src/DisasterRelief.sol";
import {DisasterDonorBadge, INFTBadge} from "../src/DisasterDonorBadge.sol";
import {GeneralDonorBadge, INFTBadge} from "../src/GeneralDonorBadge.sol";
import "../../src/LocationDetails.sol";

contract DAOGovTest is Test {
    // Create new instances of these contracts in setUp instead of using addresses
    MockUSDC public usdc;
    GeneralDonorBadge public generalBadge;
    DisasterDonorBadge public disasterBadge;

    IDAOGovernance public daoGovernance;
    IDisasterReliefFactory disasterReliefFactory;
    IFundEscrow fundEscrow;

    // DAO members with labeled mock addresses
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil default account

    address member1 = makeAddr("member1");
    address member2 = makeAddr("member2");
    address member3 = makeAddr("member3");
    address member4 = makeAddr("member4");
    address member5 = makeAddr("member5");

    function setUp() public {
        vm.startPrank(admin);
        // Deploy MockUSDC
        usdc = new MockUSDC();

        // Deploy badge contracts
        generalBadge = new GeneralDonorBadge();
        disasterBadge = new DisasterDonorBadge();
        vm.stopPrank();
        // Deploy Governance contract
        daoGovernance = new DAOGovernance(admin);

        // Deploy disaster relief factory
        disasterReliefFactory = new DisasterReliefFactory(
            address(daoGovernance),
            address(this), // zkverifier address
            address(usdc),
            address(disasterBadge)
        );

        // Deploy fundEscrow
        fundEscrow =
            new FundEscrow(address(disasterReliefFactory), address(generalBadge), address(daoGovernance), address(usdc));

        vm.startPrank(admin);
        // Set factory and escrow in governance
        daoGovernance.setDisasterReliefFactory(address(disasterReliefFactory));
        daoGovernance.setFundEscrow(address(fundEscrow));

        generalBadge.setAllowedContract(address(fundEscrow));
        disasterBadge.setAllowedContract(address(disasterReliefFactory));
        vm.stopPrank();
        // Mint usdc to fundEscrow
        usdc.mint(address(fundEscrow), 100e6);
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
        LocationDetails.Location memory location =
            LocationDetails.Location({latitude: "12.3", longitude: "87.9", radius: "3"});

        vm.startPrank(member1);
        uint256 proposalId = daoGovernance.createProposal("Hudud Cyclone", location, 1000, "cyclone.jpg");
        assert(proposalId == 1);
        assert(daoGovernance.getProposal(proposalId).id == 1);
        assert(daoGovernance.getProposal(proposalId).fundsRequested == 1000);
        assert(daoGovernance.getProposal(proposalId).proposer == member1);
        vm.stopPrank();
        _;
    }

    function test_escrowHasBalance() public {
        uint256 balance = usdc.balanceOf(address(fundEscrow));
        assertEq(balance, 100e6, "FundEscrow should have 100 USDC");
    }

    function test_canDonatToescrow() public {
        vm.startPrank(member1);
        // Mint USDC to member1
        usdc.mint(member1, 100000000e6);
        console.log("Mock USDC balance of member1:", usdc.balanceOf(member1));

        // Approve and donate to fundEscrow
        usdc.approve(address(fundEscrow), 10000e6);
        console.log("Mock USDC approved to fundEscrow");

        uint256 allow = usdc.allowance(member1, address(fundEscrow));
        console.log("approval tokens", allow);

        fundEscrow.donate(10000e6);
        console.log("Mock USDC balance of member1 after donation:", usdc.balanceOf(member1));

        assert(generalBadge.ownerOf(1) == member1);
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

    function test_membersArray() public {
        vm.startPrank(admin);
        daoGovernance.addDAOMember(member1);
        daoGovernance.addDAOMember(member2);
        daoGovernance.addDAOMember(member3);
        daoGovernance.addDAOMember(member4);
        daoGovernance.addDAOMember(member5);
        vm.stopPrank();
        address[] memory members = daoGovernance.getDAOMembers();
        assertEq(members[0], admin, "First member should be member1");
    }

    function test_CreateProposal() public {
        test_addMembers();
        LocationDetails.Location memory location =
            LocationDetails.Location({latitude: "12.3", longitude: "87.9", radius: "3"});
        vm.startPrank(member1);
        uint256 proposalId = daoGovernance.createProposal("Hudud Cyclone", location, 100e6, "cyclone.jpg");
        assert(proposalId == 1);
        assert(daoGovernance.getProposal(proposalId).id == 1);
        assert(daoGovernance.getProposal(proposalId).fundsRequested == 100e6);
        assert(daoGovernance.getProposal(proposalId).proposer == member1);
        vm.stopPrank();
    }

    function test_getPropLen() public {
        vm.startBroadcast();
        address[] memory arr = DisasterReliefFactory(0x6F2dA9b816F80811A4dA21e511cb6235167a33Af).getAllProposals();
        console.log("len of proposals", arr.length);
        vm.stopBroadcast();
    }

    function test_VoteSuccess() public MembersAdded ProposalCreated {
        vm.startPrank(member2);
        daoGovernance.vote(1, true);
        assert(daoGovernance.getProposal(1).forVotes == 1);
        assert(daoGovernance.hasVoted(1, member2) == true);
        vm.stopPrank();
    }

    function test_addDaoMembers() public {
        vm.startPrank(admin);
        daoGovernance.addDAOMember(member1);
        vm.expectRevert();
        daoGovernance.addDAOMember(member1);
        vm.stopPrank();
    }

    function test_deleteDaoMember() public {
        vm.startPrank(admin);
        daoGovernance.addDAOMember(member1);
        daoGovernance.addDAOMember(member2);
        daoGovernance.addDAOMember(member3);
        daoGovernance.addDAOMember(member4);
        assert(daoGovernance.memberCount() == 5);
        daoGovernance.removeDAOMember(member3);

        assert(daoGovernance.isDAOMember(member3) == false);
        assert(daoGovernance.memberCount() == 4);

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

        address proposal1 = DisasterReliefFactory(address(disasterReliefFactory)).getProposal(0);
        //mint 1000e6 to memeber1
        usdc.mint(member1, 1000e6);
        vm.prank(member1);
        usdc.approve(proposal1, 10000e6);
        vm.prank(member1);
        DisasterRelief(proposal1).donate(10e6);
        assert(IDisasterRelief(proposal1).getTotalFunds() == (10e6 + 1000));
        assert(disasterBadge.ownerOf(1) == member1);
    }

    //it reverts bcz donation period is not ended
    function test_VictimRegistrationReverts() public {
        test_proposalPassed();
        address proposal1 = DisasterReliefFactory(address(disasterReliefFactory)).getProposal(0);

        address victim1 = makeAddr("victim1");
        vm.prank(victim1);
        vm.expectRevert();
        IDisasterRelief(proposal1).registerAsVictim("");
        assertFalse(DisasterRelief(proposal1).victims(victim1));
    }

    function test_VictimRegistrationSuccess() public {
        test_proposalPassed();
        address proposal1 = DisasterReliefFactory(address(disasterReliefFactory)).getProposal(0);
        vm.warp(block.timestamp + 8 days);
        address victim1 = makeAddr("victim1");
        // DisasterRelief(proposal1).updateState();
        vm.prank(victim1);
        IDisasterRelief(proposal1).registerAsVictim("");
        assertTrue(DisasterRelief(proposal1).victims(victim1));
    }

    function test_canClaimfunds() public {
        test_proposalPassed();
        address proposal1 = DisasterReliefFactory(address(disasterReliefFactory)).getProposal(0);
        vm.warp(block.timestamp + 8 days);
        address victim1 = makeAddr("victim1");
        // DisasterRelief(proposal1).updateState();
        vm.prank(victim1);
        IDisasterRelief(proposal1).registerAsVictim("");
        assertTrue(DisasterRelief(proposal1).victims(victim1));
        vm.warp(block.timestamp + 10 days + 2 minutes);
        console.log("funds available %e", IDisasterRelief(proposal1).getTotalFunds());
        console.log("funds per victim %e", DisasterRelief(proposal1).amountPerVictim());
        vm.prank(victim1);
        IDisasterRelief(proposal1).withdrawFunds();
        assertTrue(DisasterRelief(proposal1).hasWithdrawn(victim1));
    }

    modifier members3() {
        //now dao has 3 members
        vm.startPrank(admin);
        daoGovernance.addDAOMember(member1);
        daoGovernance.addDAOMember(member2);
        vm.stopPrank();
        _;
    }

    // modifier ProposalCreated1() {
    //     LocationDetails.Location memory location =
    //         LocationDetails.Location({latitude: "12.3", longitude: "87.9", radius: "3"});

    //     vm.startPrank(member1);
    //     uint256 proposalId = daoGovernance.createProposal("Hudud Cyclone", location, 1000, "cyclone.jpg");
    //     assert(proposalId == 1);
    //     assert(daoGovernance.getProposal(proposalId).id == 1);
    //     assert(daoGovernance.getProposal(proposalId).fundsRequested == 1000);
    //     assert(daoGovernance.getProposal(proposalId).proposer == member1);
    //     vm.stopPrank();
    //     _;
    // }

    // function test_isProposalPassed() public members3() ProposalCreated(){
    //     vm.prank(member1);
    //     daoGovernance.vote(1, true);
    //     console.log("For votes",daoGovernance.getProposal(1).forVotes);
    //     console.log("Proposal status",uint256(daoGovernance.getProposal(1).state));
    //     vm.prank(member2);
    //     daoGovernance.vote(1, true);
    //     console.log("For votes",daoGovernance.getProposal(1).forVotes);
    //     console.log("Proposal status",uint256(daoGovernance.getProposal(1).state));
    //     address[] memory contracts_=DisasterReliefFactory(address(disasterReliefFactory)).getAllProposals();
    //     assertTrue(contracts_.length ==1);
    // }

    function test_isProposalPassed1() public members3 ProposalCreated {
        vm.prank(member1);
        daoGovernance.vote(1, true);
        console.log("For votes", daoGovernance.getProposal(1).forVotes);
        console.log("Proposal status", uint256(daoGovernance.getProposal(1).state));
        vm.prank(member2);
        daoGovernance.vote(1, true);
        console.log("For votes", daoGovernance.getProposal(1).forVotes);
        console.log("Proposal status", uint256(daoGovernance.getProposal(1).state));
        // vm.prank(admin);
        // daoGovernance.vote(1, true);
        // console.log("For votes",daoGovernance.getProposal(1).forVotes);
        // console.log("Proposal status",uint256(daoGovernance.getProposal(1).state));
        // console.log("total member",daoGovernance.memberCount());
        //assertTrue(uint256(daoGovernance.getProposal(1).state)==0);
        assertTrue(uint256(daoGovernance.getProposal(1).state) == 1);
        //address[] memory contracts_=DisasterReliefFactory(address(disasterReliefFactory)).getAllProposals();
        //assertTrue(contracts_.length ==1);
    }

    function test_executeProposal1() public members3 ProposalCreated {
        vm.prank(member1);
        daoGovernance.vote(1, true);
        console.log("For votes", daoGovernance.getProposal(1).forVotes);
        console.log("Proposal status", uint256(daoGovernance.getProposal(1).state));
        vm.prank(member2);
        daoGovernance.vote(1, true);
        console.log("For votes", daoGovernance.getProposal(1).forVotes);
        console.log("Proposal status", uint256(daoGovernance.getProposal(1).state));
        vm.prank(admin);
        daoGovernance.executeProposal(1);
        assertTrue(DisasterReliefFactory(address(disasterReliefFactory)).getAllProposals().length == 1);
    }

    function test_env() public {
        DAOGovernance daoGovernance1 = new DAOGovernance(0x4f29fac9891892e0D1f6B9FBE3b0148CF575F2bb);
        assertTrue(uint256(daoGovernance1.getProposalStatus(1)) == 1);

        vm.prank(0xcf744968135c87b91278C0Fe7a38b2459dac9733);
        daoGovernance1.executeProposal(1);
        assertTrue(DisasterReliefFactory(address(disasterReliefFactory)).getAllProposals().length == 1);
    }

    function test_proposalFactLen() public {
        vm.startBroadcast();
        address[] memory arr = DisasterReliefFactory(0x6F2dA9b816F80811A4dA21e511cb6235167a33Af).getAllProposals();
        console.log("len of proposals", arr.length);
        console.log("address of proposal", arr[0]);
        vm.stopBroadcast();
    }
}
