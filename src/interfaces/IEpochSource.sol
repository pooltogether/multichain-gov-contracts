pragma solidity 0.8.10;

interface IEpochSource {
    function currentEpoch() external view returns (uint32);
}
