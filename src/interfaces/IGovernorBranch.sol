pragma solidity 0.8.10;

interface IGovernorBranch {

    function queueProposal(
        bytes32 proposalHash
    ) external;

}
