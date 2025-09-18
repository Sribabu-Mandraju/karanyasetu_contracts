// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {INFTBadge} from "./interfaces/INFTBadge.sol";
import {DisasterReliefFactory} from "./DisasterReliefFactory.sol";

contract DisasterDonorBadge is ERC721, INFTBadge {
    uint256 private _nextTokenId;
    address public owner;
    DisasterReliefFactory public _distasterReliefFacotry;
    string private _baseTokenURI;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyReliefContract() {
        //when only the disaster relief contract calls mint then only minting should happen
        require(_distasterReliefFacotry.isDisasterRelief(msg.sender), "Only escrow can mint");
        _;
    }

    constructor() ERC721("DisasterDonorBadge", "DDB") {
        owner = msg.sender;
    }

    function setAllowedContract(address disasterReliefFactory) external onlyOwner {
        _distasterReliefFacotry = DisasterReliefFactory(disasterReliefFactory);
    }

    function mint(address to) external override onlyReliefContract returns (uint256) {
        require(_distasterReliefFacotry.isDisasterRelief(msg.sender), "Not authorized");

        uint256 tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);

        emit BadgeMinted(to, tokenId);
        return tokenId;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    function ownerOf(uint256 tokenId) public view override(ERC721) returns (address) {
        return super.ownerOf(tokenId);
    }

    function totalSupply() external view override returns (uint256) {
        return _nextTokenId;
    }
}
