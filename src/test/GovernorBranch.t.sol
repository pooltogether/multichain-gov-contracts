pragma solidity 0.8.10;

import "ds-test/test.sol";
import "hardhat-core/console.sol";

import "./CheatCodes.sol";
import "../interfaces/IEpochVoter.sol";
import "../GovernorRoot.sol";
import "../GovernorBranch.sol";

contract GovernorBranchTest is DSTest {

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    GovernorBranch governorBranch;
    IEpochVoter epochVoter = IEpochVoter(0x0000000000000000000000000000000000000007);
    IGovernorRoot governorRoot = IGovernorRoot(0x0000000000000000000000000000000000000008);
    bytes32 executionHash = bytes32(0x0000000000000000000000000000000000000000000000000000000000000022);

    function setUp() public {
        cheats.clearMockedCalls();
        governorBranch = new GovernorBranch(epochVoter);
        governorBranch.setGovernorRoot(governorRoot);
    }

    function _mockCurrentEpoch(uint epoch) internal {
        cheats.mockCall(
            address(epochVoter),
            abi.encodeWithSelector(epochVoter.currentEpoch.selector),
            abi.encode(epoch)
        );
    }

    function _mockCurrentVotes(uint112 votes) internal {
        cheats.mockCall(
            address(epochVoter),
            abi.encodeWithSelector(epochVoter.currentVotes.selector, address(this)),
            abi.encode(votes)
        );
    }

    function _mockVotesAtEpoch(uint112 votes, uint32 epoch) internal {
        cheats.mockCall(
            address(epochVoter),
            abi.encodeWithSelector(epochVoter.votesAtEpoch.selector, address(this), epoch),
            abi.encode(votes)
        );
    }

    function _makeCalls() internal returns (GovernorBranch.Call[] memory) {
        GovernorBranch.Call[] memory calls = new GovernorBranch.Call[](1);
        calls[0] = GovernorBranch.Call({
            chainId: block.chainid,
            caller: address(governorBranch),
            target: address(epochVoter),
            value: 0,
            data: abi.encodeWithSelector(epochVoter.currentVotes.selector, address(this))
        });
        return calls;
    }

    function _makeExecution(uint nonce) internal returns (GovernorBranch.Call[] memory calls, bytes32 executionHash) {
        calls = _makeCalls();
        bytes32 callHash = keccak256(
            abi.encode(
                bytes32(0),
                calls[0].chainId,
                calls[0].caller,
                calls[0].target,
                calls[0].value,
                calls[0].data
            )
        );
        executionHash = keccak256(
            abi.encode(
                block.chainid,
                address(governorBranch),
                1,
                callHash
            )
        );
    }

    function testComputeExecutionHash() public {
        (GovernorBranch.Call[] memory calls, bytes32 executionHash) = _makeExecution(1);
        assertEq(governorBranch.computeExecutionHash(calls, 1), executionHash, "exec hash matches");
    }

    function testQueueProposal() public {
        cheats.prank(address(governorRoot));
        cheats.warp(8);
        governorBranch.queueProposal(executionHash);
        (
            uint64 timestamp,
            bool executed
        ) = governorBranch.queuedProposals(executionHash);
        assertEq(timestamp, 8, "timestamp matches");
        assertTrue(!executed, "has not been executed");
    }

    function testExecuteProposal() public {
        cheats.prank(address(governorRoot));
        cheats.warp(8);
        (GovernorBranch.Call[] memory calls, bytes32 executionHash) = _makeExecution(1);
        bytes32 proposalHash = keccak256(
            abi.encode(
                executionHash,
                ""
            )
        );
        governorBranch.queueProposal(proposalHash);
        cheats.expectCall(address(epochVoter), abi.encodeWithSelector(epochVoter.currentVotes.selector, address(this)));
        cheats.mockCall(address(epochVoter), abi.encodeWithSelector(epochVoter.currentVotes.selector, address(this)), abi.encode(10));
        governorBranch.executeProposal(
            block.chainid,
            address(governorBranch),
            1,
            calls,
            ""
        );

        (
            uint64 timestamp,
            bool executed
        ) = governorBranch.queuedProposals(proposalHash);
        assertTrue(executed, "proposal was executed");
    }

    function testVote() public {
        _mockCurrentEpoch(1);
        _mockVotesAtEpoch(10 ether, 0);

        governorBranch.castVote(
            executionHash,
            0,
            5 days,
            1
        );

        bytes32 proposalHash = keccak256(abi.encode(executionHash, abi.encode(0, 5 days)));

        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorBranch.proposalVotes(proposalHash);
        assertEq(forVotes, 10 ether);
    }

    function testVoteEnded() public {
        _mockCurrentEpoch(1);
        _mockVotesAtEpoch(10 ether, 0);
        cheats.warp(10 days);
        cheats.expectRevert("voting ended");
        try governorBranch.castVote(
            executionHash,
            0,
            5 days,
            1
        ) {} catch {}
    }

    function testVoteEpochNotEnded() public {
        _mockCurrentEpoch(0);
        _mockVotesAtEpoch(10 ether, 0);
        cheats.expectRevert("epoch has not ended");
        try governorBranch.castVote(
            executionHash,
            0,
            5 days,
            1
        ) {} catch {}
    }

    function testVoteTwice() public {
        _mockCurrentEpoch(1);
        _mockVotesAtEpoch(10 ether, 0);
        governorBranch.castVote(
            executionHash,
            0,
            5 days,
            1
        );
        cheats.expectRevert("already voted");
        try governorBranch.castVote(
            executionHash,
            0,
            5 days,
            1
        ) {} catch {}
    }

    function testAddVotes() public {
        _mockCurrentEpoch(1);
        _mockVotesAtEpoch(10 ether, 0);
        governorBranch.castVote(
            executionHash,
            0,
            5 days,
            1
        );
        bytes32 proposalHash = keccak256(abi.encode(executionHash, 1, abi.encode(0, 5 days)));
        cheats.expectCall(
            address(governorRoot),
            abi.encodeWithSelector(governorRoot.addVotes.selector, 0, 10 ether, 0, executionHash, 0, 5 days)
        );
        cheats.mockCall(
            address(governorRoot),
            abi.encodeWithSelector(governorRoot.addVotes.selector, 0, 10 ether, 0, executionHash, 0, 5 days),
            abi.encode(true)
        );
        cheats.warp(10 days);
        governorBranch.addVotes(
            executionHash,
            0,
            5 days
        );
    }
}
