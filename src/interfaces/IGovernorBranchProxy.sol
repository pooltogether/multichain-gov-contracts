pragma solidity 0.8.10;

interface IGovernorBranchProxy {

    function queueProposal(
        bytes32 proposalHash
    ) external;

}
