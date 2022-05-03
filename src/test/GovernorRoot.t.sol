pragma solidity 0.8.10;

import "ds-test/test.sol";

import "./CheatCodes.sol";
import "../interfaces/IEpochSource.sol";
import "../GovernorRoot.sol";

contract GovernorRootTest is DSTest {

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    GovernorRoot governorRoot;
    IGovernorBranch governorBranch = IGovernorBranch(0x0000000000000000000000000000000000000002);
    IGovernorBranch governorBranch2 = IGovernorBranch(0x0000000000000000000000000000000000000003);

    bytes32 callsHash = bytes32(0x0000000000000000000000000000000000000000000000000000000000000022);
    uint256 branchChainId = 1;
    uint256 branchNonce = 1;
    uint32 epoch = 1;
    uint64 endTimestamp = 5 days;
    bytes32 executionHash = keccak256(abi.encode(
        branchChainId, address(governorBranch), branchNonce, callsHash
    ));
    bytes32 proposalHash = keccak256(abi.encode(
        executionHash,
        abi.encode(epoch, endTimestamp)
    ));

    function setUp() public {
        IGovernorBranch[] memory branches = new IGovernorBranch[](1);
        branches[0] = governorBranch;
        governorRoot = new GovernorRoot(branches);
    }

    function testAddBranch() public {
        cheats.prank(address(governorBranch));
        governorRoot.addBranch(governorBranch2);
        assertTrue(governorRoot.isBranch(governorBranch2));
    }

    function testAddBranchRequireBranch() public {
        cheats.expectRevert("not a branch");
        try governorRoot.addBranch(governorBranch2) {
        } catch Error(string memory) {}
    }

    function testRemoveBranch() public {
        cheats.startPrank(address(governorBranch));
        governorRoot.addBranch(governorBranch2);
        governorRoot.removeBranch(governorBranch2);
        assertTrue(!governorRoot.isBranch(governorBranch2));
        cheats.stopPrank();
    }

    function testRemoveBranchRevert() public {
        cheats.expectRevert("not a branch");
        try governorRoot.addBranch(governorBranch2) {
        } catch Error(string memory) {}
    }

    function testAddVotes() public {
        cheats.prank(address(governorBranch));
        governorRoot.addVotes(
            1,
            2,
            3,
            executionHash,
            epoch,
            endTimestamp
        );

        (
            uint32 epoch,
            uint64 endTimestamp,
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorRoot.proposals(proposalHash);

        assertEq(againstVotes, 1);
        assertEq(forVotes, 2);
        assertEq(abstainVotes, 3);
    }

    function testAddVotesTwice() public {
        cheats.prank(address(governorBranch));
        governorRoot.addVotes(
            1,
            2,
            3,
            executionHash,
            epoch,
            endTimestamp
        );

        cheats.expectRevert("already voted");
        try governorRoot.addVotes(1, 2, 3, executionHash, epoch, endTimestamp) {} catch {}
    }

    function testHasPassed() public {
        cheats.prank(address(governorBranch));
        governorRoot.addVotes(0, 100_000 ether, 0, executionHash, epoch, endTimestamp);

        assertTrue(!governorRoot.hasPassed(proposalHash), "proposal should not have passed");

        cheats.warp(5 days);

        assertTrue(!governorRoot.hasPassed(proposalHash), "proposal should not have passed until grace");

        cheats.warp(5 days + 7 days);
        
        assertTrue(governorRoot.hasPassed(proposalHash), "proposal has passed");
    }
}
