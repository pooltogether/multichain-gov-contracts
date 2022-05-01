pragma solidity 0.8.10;

import "./EpochVoter.sol";
import "./interfaces/IGovernorRootProxy.sol";
import "./interfaces/IGovernorBranchProxy.sol";

contract GovernorRoot is IGovernorRootProxy {

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

    mapping(IGovernorBranchProxy => bool) branches;
    mapping(bytes32 => Proposal) proposals;

    EpochVoter public epochVoter;

    constructor(EpochVoter _epochVoter) {
        epochVoter = _epochVoter;
    }

    function requestProposal(
        uint branchChainId,
        address branchAddress,
        uint branchNonce,
        bytes32 callsHash
    ) external requireBranch(msg.sender) {
        createProposal(
            branchChainId,
            branchAddress,
            branchNonce,
            callsHash
        );
    }

    function createProposal(
        uint branchChainId,
        address branchAddress,
        uint branchNonce,
        bytes32 callsHash
    ) public requireBranch(msg.sender) returns (
        uint256 rootNonce,
        bytes32 proposalHash,
        bytes memory data
    ) {
        nonce += 1;
        rootNonce = nonce;
        uint32 epoch = epochVoter.currentEpoch();
        uint64 endTimestamp = uint64(block.timestamp + VOTE_DURATION);
        data = abi.encode(epoch, endTimestamp);
        proposalHash = keccak256(
            abi.encode(
                rootNonce,
                branchChainId,
                branchAddress,
                branchNonce,
                callsHash,
                data
            )
        );
        proposals[proposalHash].epoch = epoch;
        proposals[proposalHash].endTimestamp = endTimestamp;
    }

    function addVotes(
        uint256 branchChainId,
        address branchAddress,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bytes32 proposalHash
    ) external override requireBranch(msg.sender) {
        Proposal memory proposal = proposals[proposalHash];
        require(!hasVoted[proposalHash][msg.sender], "already voted");
        require(proposal.endTimestamp > 0, "does not exist");

        proposal.abstainVotes += abstainVotes;
        proposal.forVotes += forVotes;
        proposal.againstVotes += againstVotes;

        proposals[proposalHash] = proposal;
        hasVoted[proposalHash][msg.sender] = true;
    }

    function hasPassed(bytes32 proposalHash) public view returns (bool) {
        return (
            block.timestamp > (proposals[proposalHash].endTimestamp + GRACE_PERIOD) &&
            (proposals[proposalHash].forVotes + proposals[proposalHash].abstainVotes) > QUORUM
        );
    }

    function queueProposal(bytes32 _proposalHash, IGovernorBranchProxy _branch) external requireBranch(address(_branch)) {
        require(hasPassed(_proposalHash), "has not passed");
        _branch.queueProposal(_proposalHash);
    }

    modifier requireBranch(address _branch) {
        require(branches[IGovernorBranchProxy(_branch)], "not a branch");
        _;
    }

}
