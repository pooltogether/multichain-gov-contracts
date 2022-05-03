pragma solidity 0.8.10;

import "./interfaces/IEpochSource.sol";
import "./interfaces/IGovernorRoot.sol";
import "./interfaces/IGovernorBranch.sol";

import "hardhat-core/console.sol";

contract GovernorRoot is IGovernorRoot {

    struct Proposal {
        uint32 epoch;
        uint64 endTimestamp;
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
    }

    mapping(bytes32 => mapping(address => bool)) hasVoted;

    uint256 public constant QUORUM = 100_000 ether;
    uint256 public constant VOTE_DURATION = 5 days;
    uint256 public constant GRACE_PERIOD = 7 days;

    mapping(IGovernorBranch => bool) branches;
    mapping(bytes32 => Proposal) public proposals;

    constructor(IGovernorBranch[] memory _branches) {
        for (uint i = 0; i < _branches.length; i++) {
            branches[_branches[i]] = true;
        }
    }

    function addBranch(IGovernorBranch _branch) external requireBranch(msg.sender) {
        branches[_branch] = true;
    }

    function removeBranch(IGovernorBranch _branch) external requireBranch(msg.sender) {
        branches[_branch] = false;
    }

    function isBranch(IGovernorBranch _branch) external view returns (bool) {
        return branches[_branch];
    }

    function addVotes(
        uint256 againstVotes,
        uint256 forVotes,
        uint256 abstainVotes,
        bytes32 executionHash,
        uint32 epoch,
        uint64 endTimestamp
    ) external override requireBranch(msg.sender) returns (bool) {
        bytes32 proposalHash = keccak256(
            abi.encode(
                executionHash,
                abi.encode(epoch, endTimestamp)
            )
        );
        require(!hasVoted[proposalHash][msg.sender], "already voted");

        Proposal memory proposal = proposals[proposalHash];
        proposal.epoch = epoch;
        proposal.endTimestamp = endTimestamp;
        proposal.abstainVotes += abstainVotes;
        proposal.forVotes += forVotes;
        proposal.againstVotes += againstVotes;
        proposals[proposalHash] = proposal;

        hasVoted[proposalHash][msg.sender] = true;

        return true;
    }

    function isProposal(bytes32 proposalHash) public view returns (bool) {
        return proposals[proposalHash].endTimestamp > 0;
    }

    function hasPassed(bytes32 proposalHash) public view returns (bool) {
        return (
            (block.timestamp >= proposals[proposalHash].endTimestamp + GRACE_PERIOD) &&
            (proposals[proposalHash].forVotes + proposals[proposalHash].abstainVotes >= QUORUM)
        );
    }

    function queueProposal(bytes32 _proposalHash, IGovernorBranch _branch) external requireBranch(address(_branch)) {
        require(hasPassed(_proposalHash), "has not passed");
        _branch.queueProposal(_proposalHash);
    }

    modifier requireBranch(address _branch) {
        require(branches[IGovernorBranch(_branch)], "not a branch");
        _;
    }

}
