# Multichain Governance Contracts

This is the reference implementation for the [Multichain Governance Specification](https://github.com/pooltogether/multichain-gov-proposal-spec). The multichain governance system allows token holders across multiple chains to vote on state changes across chains.

There are three contracts:

- EscrowEpochVoter: ERC20 token wrapper that mitigates double-voting by splitting time into large epochs and tracking minimum balances for the epoch.
- GovernorBranch: users interact with branches to create proposals and vote.
- GovernorRoot: the root combines vote aggregates from branches to determine consensus. If a proposal passes, it can be sent to any branches that require execution.

The flow is like so:

1. Users submit their votes for a proposal to each GovernorBranch.
2. After the end timestamp, the GovernorBranch can submit the vote totals to the GovernorRoot.
3. If the proposal passes (grace period ends and quorum is met) anyone can tell the GovernorRoot to send the "queueProposal" message to a branch. This message includes the proposal hash. The message only needs to be sent to branches that have calls to execute. The GovernorBranch records the proposal hash as queued.
4. Anyone can submit the full execution details to a GovernorBranch to execute the contents of a proposal.

To see the above flow in action please refer to the [end-to-end integration test](./src/test/Integration.t.sol)

**Note: the cross-chain transport layer has not yet been built.**

You can see how this design separates execution from consensus. Inter-chain communication is minimized to the messages:

- Submit vote totals from GovernorBranches to the GovernorRoot.
- Queue proposal from the GovernorRoot to only GovernorBranches that require execution.

# Development

This project uses [Foundry](https://book.getfoundry.sh/).