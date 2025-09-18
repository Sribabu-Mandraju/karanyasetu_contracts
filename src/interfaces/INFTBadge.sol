// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INFTBadge {
    event BadgeMinted(address indexed to, uint256 indexed tokenId);

    function mint(address to) external returns (uint256);
    function totalSupply() external view returns (uint256);

    function setAllowedContract(address disasterReliefFactory) external;
}
