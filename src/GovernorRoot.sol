pragma solidity 0.8.10;

import "./interfaces/IEpochSource.sol";
import "./interfaces/IGovernorRoot.sol";
import "./interfaces/IGovernorBranch.sol";

contract GovernorRoot is IGovernorRoot {

    uint256 public nonce;

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

    IEpochSource public epochSource;

    constructor(IEpochSource _epochSource, IGovernorBranch[] memory _branches) {
        epochSource = _epochSource;
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

    function requestProposal(
        bytes32 executionHash
    ) external override returns (bool) {
        createProposal(executionHash);
        return true;
    }

    function createProposal(
        bytes32 executionHash
    ) public requireBranch(msg.sender) returns (
        uint256 rootNonce,
        bytes32 proposalHash,
        bytes memory data
    ) {
        rootNonce = nonce + 1;
        nonce = rootNonce;
        uint32 epoch = epochSource.currentEpoch();
        uint64 endTimestamp = uint64(block.timestamp + VOTE_DURATION);
        data = abi.encode(epoch, endTimestamp);
        proposalHash = keccak256(
            abi.encode(
                executionHash,
                rootNonce,
                data
            )
        );
        proposals[proposalHash].epoch = epoch;
        proposals[proposalHash].endTimestamp = endTimestamp;
    }

    function addVotes(
        uint256 againstVotes,
        uint256 forVotes,
        uint256 abstainVotes,
        bytes32 proposalHash
    ) external override requireBranch(msg.sender) returns (bool) {
        Proposal memory proposal = proposals[proposalHash];
        require(!hasVoted[proposalHash][msg.sender], "already voted");
        require(proposal.endTimestamp > 0, "does not exist");

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
