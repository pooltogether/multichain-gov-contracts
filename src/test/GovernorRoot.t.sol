pragma solidity 0.8.10;

import "ds-test/test.sol";

import "./CheatCodes.sol";
import "../interfaces/IEpochSource.sol";
import "../GovernorRoot.sol";

contract GovernorRootTest is DSTest {

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    GovernorRoot governorRoot;
    IEpochSource epochSource = IEpochSource(0x0000000000000000000000000000000000000001);
    IGovernorBranch governorBranch = IGovernorBranch(0x0000000000000000000000000000000000000002);
    IGovernorBranch governorBranch2 = IGovernorBranch(0x0000000000000000000000000000000000000003);

    bytes32 callsHash = bytes32(0x0000000000000000000000000000000000000000000000000000000000000022);
    uint256 branchChainId = 1;
    uint256 branchNonce = 1;

    function setUp() public {
        IGovernorBranch[] memory branches = new IGovernorBranch[](1);
        branches[0] = governorBranch;
        governorRoot = new GovernorRoot(epochSource, branches);
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

    function _mockCurrentEpoch(uint epoch) internal {
        cheats.mockCall(
            address(epochSource),
            abi.encodeWithSelector(epochSource.currentEpoch.selector),
            abi.encode(epoch)
        );
    }

    function _createProposal() internal returns (
        uint256 rootNonce,
        bytes32 proposalHash,
        bytes memory data,
        bytes32 executionHash
    ) {
        cheats.startPrank(address(governorBranch));
        _mockCurrentEpoch(1);
        executionHash = keccak256(abi.encode(
            branchChainId, address(governorBranch), branchNonce, callsHash
        ));
        (
            rootNonce,
            proposalHash,
            data
        ) = governorRoot.createProposal(executionHash);
        cheats.stopPrank();
    }

    function testCreateProposal() public {
        (
            uint256 rootNonce,
            bytes32 proposalHash,
            bytes memory data,
            bytes32 executionHash
        ) = _createProposal();

        assertEq0(data, abi.encode(1, 5 days), "epoch and end timestamp encoded");
        assertEq(rootNonce, 1, "root nonce matches");
        assertEq(proposalHash, keccak256(
            abi.encode(
                executionHash,
                rootNonce,
                data
            )
        ), "proposal hash is correct");
        assertTrue(governorRoot.isProposal(proposalHash));
        cheats.stopPrank();
    }

    function testAddVotes() public {
        (
            uint256 rootNonce,
            bytes32 proposalHash,
            bytes memory data,
            bytes32 executionHash
        ) = _createProposal();

        cheats.startPrank(address(governorBranch));
        _mockCurrentEpoch(2);

        governorRoot.addVotes(
            1,
            2,
            3,
            proposalHash
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
        (,bytes32 proposalHash,,) = _createProposal();

        cheats.startPrank(address(governorBranch));
        _mockCurrentEpoch(2);

        governorRoot.addVotes(
            1,
            2,
            3,
            proposalHash
        );

        cheats.expectRevert("already voted");
        try governorRoot.addVotes(1, 2, 3, proposalHash) {} catch {}
    }

    function testAddVotesNonExistentProposal() public {
        cheats.expectRevert("does not exist");
        try governorRoot.addVotes(1, 2, 3, callsHash) {} catch {}
    }

    function testHasPassed() public {
        (,bytes32 proposalHash,,) = _createProposal();
        cheats.startPrank(address(governorBranch));
        _mockCurrentEpoch(2);

        governorRoot.addVotes(0, 100_000 ether, 0, proposalHash);

        assertTrue(!governorRoot.hasPassed(proposalHash), "proposal should not have passed");

        cheats.warp(5 days);

        assertTrue(!governorRoot.hasPassed(proposalHash), "proposal should not have passed until grace");

        cheats.warp(5 days + 7 days);
        
        assertTrue(governorRoot.hasPassed(proposalHash), "proposal has passed");
    }
}
