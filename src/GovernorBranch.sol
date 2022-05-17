pragma solidity 0.8.10;

import "./interfaces/IEpochVoter.sol";
import "./interfaces/IGovernorRoot.sol";
import "./interfaces/IGovernorBranch.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

contract GovernorBranch is IGovernorBranch {

    enum VoteType {
        Against,
        For,
        Abstain
    }

    event BranchCreatedProposal(
        bytes32 indexed executionHash,
        uint256 indexed branchNonce,
        Call[] calls,
        bytes message
    );

    event QueuedProposal(
        bytes32 indexed proposalHash
    );

    event ExecutedProposal(
        bytes32 indexed executionHash,
        bytes32 indexed proposalHash
    );

    struct Call {
        uint256 chainId;
        address caller;
        address target;
        uint256 value;
        bytes data;
    }

    struct Proposal {
        uint64 timestamp;
        bool executed;
    }

    struct ProposalVote {
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
    }
    
    mapping(bytes32 => mapping(address => bool)) hasVoted;

    uint256 public constant THRESHOLD = 10 ether;

    mapping(bytes32 => Proposal) public queuedProposal;
    mapping(bytes32 => ProposalVote) public proposalVotes;

    uint256 nonce;
    IEpochVoter public immutable epochVoter;
    IGovernorRoot public governorRoot;

    constructor(IEpochVoter _epochVoter) {
        epochVoter = _epochVoter;
    }

    function setGovernorRoot(IGovernorRoot _governorRoot) external {
        governorRoot = _governorRoot;
    }

    function computeExecutionHash(
        Call[] calldata calls,
        bytes calldata message,
        uint256 nonce
    ) public returns (bytes32) {
        bytes32 callsHash = hashCalls(calls);
        return keccak256(abi.encode(
            block.chainid,
            address(this),
            nonce,
            callsHash
        ));
    }

    function createProposal(
        Call[] calldata calls,
        bytes calldata message
    ) external returns (bytes32 executionHash, uint256 branchNonce) {
        require(epochVoter.currentVotes(msg.sender) >= THRESHOLD, "does not have min votes");
        branchNonce = nonce + 1;
        nonce = branchNonce;
        executionHash = computeExecutionHash(calls, message, branchNonce);
        governorRoot.createProposal(executionHash);

        emit BranchCreatedProposal(executionHash, branchNonce, calls, message);
    }

    function queueProposal(bytes32 proposalHash) external override requireRoot(msg.sender) {
        queuedProposal[proposalHash] = Proposal({
            timestamp: uint64(block.timestamp),
            executed: false
        });

        emit QueuedProposal(proposalHash);
    }

    function executeProposal(
        uint256 branchChainId,
        address branchAddress,
        uint256 branchNonce,
        Call[] calldata calls,
        uint256 rootNonce,
        uint32 startEpoch,
        uint64 endTimestamp
    ) external {
        bytes32 callsHash = hashCalls(calls);
        bytes32 executionHash = keccak256(abi.encode(
            branchChainId,
            branchAddress,
            branchNonce,
            callsHash
        ));
        bytes32 proposalHash = _computeProposalHash(
            executionHash,
            rootNonce,
            startEpoch,
            endTimestamp
        );
        Proposal memory proposal = queuedProposal[proposalHash];
        require(proposal.timestamp > 0, "proposal has not been queued");
        require(!proposal.executed, "proposal has already executed");
        for (uint i = 0; i < calls.length; i++) {
            if (calls[i].chainId == block.chainid && calls[i].caller == address(this)) {
                (bool success, bytes memory result) = calls[i].target.call{value: calls[i].value}(calls[i].data);
                Address.verifyCallResult(success, result, "unable to execute");
            }
        }
        proposal.executed = true;
        queuedProposal[proposalHash] = proposal;

        emit ExecutedProposal(executionHash, proposalHash);
    }

    function castVote(
        bytes32 executionHash,
        uint256 rootNonce,
        uint32 startEpoch,
        uint64 endTimestamp,
        uint8 support
    ) external {
        require(block.timestamp < endTimestamp, "voting ended");
        bytes32 proposalHash = _computeProposalHash(
            executionHash,
            rootNonce,
            startEpoch,
            endTimestamp
        );
        require(epochVoter.currentEpoch() > startEpoch, "epoch has not ended");
        require(!hasVoted[proposalHash][msg.sender], "already voted");

        if (support == uint8(VoteType.Abstain)) {
            proposalVotes[proposalHash].abstainVotes += epochVoter.votesAtEpoch(msg.sender, startEpoch);
        } else if (support == uint8(VoteType.Against)) {
            proposalVotes[proposalHash].againstVotes += epochVoter.votesAtEpoch(msg.sender, startEpoch);
        } else if (support == uint8(VoteType.For)) {
            proposalVotes[proposalHash].forVotes += epochVoter.votesAtEpoch(msg.sender, startEpoch);
        }

        hasVoted[proposalHash][msg.sender] = true;
    }

    function addVotes(
        bytes32 executionHash,
        uint256 rootNonce,
        uint32 startEpoch,
        uint64 endTimestamp
    ) external {
        require(block.timestamp >= endTimestamp, "vote has not ended");
        bytes32 proposalHash = _computeProposalHash(
            executionHash,
            rootNonce,
            startEpoch,
            endTimestamp
        );
        ProposalVote memory proposalVote = proposalVotes[proposalHash];

        governorRoot.addVotes(
            proposalVote.againstVotes,
            proposalVote.forVotes,
            proposalVote.abstainVotes,
            proposalHash
        );
    }

    function hashCalls(Call[] calldata calls) internal view returns (bytes32) {
        bytes32 result;
        for (uint i = 0; i < calls.length; i++) {
            result = keccak256(
                abi.encode(
                    result,
                    calls[i].chainId,
                    calls[i].caller,
                    calls[i].target,
                    calls[i].value,
                    calls[i].data
                )
            );
        }
        return result;
    }

    function _computeProposalHash(
        bytes32 executionHash,
        uint256 rootNonce,
        uint32 startEpoch,
        uint64 endTimestamp
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                executionHash,
                rootNonce,
                startEpoch,
                endTimestamp
            )
        );
    }

    modifier requireRoot(address _account) {
        require(_account == address(governorRoot), "only governor root");
        _;
    }

}
