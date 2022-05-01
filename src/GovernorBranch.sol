pragma solidity 0.8.10;

import "./EpochVoter.sol";
import "./interfaces/IGovernorRootProxy.sol";
import "./interfaces/IGovernorBranchProxy.sol";

contract GovernorBranch is IGovernorBranchProxy {
    
    enum VoteType {
        Against,
        For,
        Abstain
    }

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
        mapping(address => bool) hasVoted;
    }

    uint256 public constant THRESHOLD = 10 ether;

    mapping(bytes32 => Proposal) queuedProposals;
    mapping(bytes32 => ProposalVote) proposalVotes;

    uint256 nonce;
    EpochVoter public immutable epochVoter;
    IGovernorRootProxy public immutable governorRoot;

    constructor(EpochVoter _epochVoter, IGovernorRootProxy _governorRoot) {
        epochVoter = _epochVoter;
        governorRoot = _governorRoot;
    }

    function requestProposal(
        Call[] calldata calls,
        bytes calldata message
    ) external returns (uint256) {
        require(epochVoter.currentVotes(msg.sender) > THRESHOLD, "does not have min votes");
        nonce += 1;

        governorRoot.requestProposal(
            block.chainid,
            address(this),
            nonce,
            hashCalls(calls)
        );
    }

    function queueProposal(bytes32 proposalHash) external override {
        queuedProposals[proposalHash] = Proposal({
            timestamp: uint64(block.timestamp),
            executed: false
        });
    }

    function executeProposal(
        uint256 rootNonce,
        uint256 branchChainId,
        address branchAddress,
        uint256 branchNonce,
        Call[] calldata calls,
        bytes calldata data
    ) external {
        bytes32 proposalHash = keccak256(
            abi.encode(
                rootNonce,
                branchChainId,
                branchAddress,
                branchNonce,
                hashCalls(calls),
                data
            )
        );
        Proposal memory proposal = queuedProposals[proposalHash];
        require(proposal.timestamp > 0, "proposal has not been queued");
        require(!proposal.executed, "proposal has already executed");
        for (uint i = 0; i < calls.length; i++) {
            if (calls[i].chainId == block.chainid && calls[i].caller == address(this)) {
                calls[i].target.call{value: calls[i].value}(calls[i].data);
            }
        }
        proposal.executed = true;
        queuedProposals[proposalHash] = proposal;
    }

    function vote(
        uint256 rootNonce,
        uint256 branchChainId,
        address branchAddress,
        uint256 branchNonce,
        Call[] calldata calls,
        uint32 startEpoch,
        uint64 endTimestamp,
        uint8 support
    ) external {
        bytes32 proposalHash = keccak256(
            abi.encode(
                rootNonce,
                branchChainId,
                branchAddress,
                branchNonce,
                hashCalls(calls),
                abi.encode(startEpoch, endTimestamp)
            )
        );

        if (support == uint8(VoteType.Abstain)) {
            proposalVotes[proposalHash].abstainVotes += epochVoter.votesAtEpoch(msg.sender, startEpoch);
        } else if (support == uint8(VoteType.Against)) {
            proposalVotes[proposalHash].againstVotes += epochVoter.votesAtEpoch(msg.sender, startEpoch);
        } else if (support == uint8(VoteType.For)) {
            proposalVotes[proposalHash].forVotes += epochVoter.votesAtEpoch(msg.sender, startEpoch);
        }
        proposalVotes[proposalHash].hasVoted[msg.sender] = true;
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

}
