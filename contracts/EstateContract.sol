// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "./extensions/ERC4907.sol";

contract EstateContract is
    ERC4907,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721URIStorage,
    EIP712,
    ERC2981,
    Pausable,
    Ownable
{
    using Counters for Counters.Counter;
    using SafeCast for uint256;

    event NFTSale(address indexed lister, address indexed buyer, uint256 price, uint256 indexed tokenId, string uri);
    event NFTRent(
        address indexed lister,
        address indexed renter,
        uint256 totalPrice,
        uint256 indexed tokenId,
        string uri,
        uint64 expiredAt
    );

    Counters.Counter private _tokenIdCounter;

    bytes32 private constant NFT_SALE_TYPE_HASH =
        keccak256("NFTForSale(address lister,uint256 price,string uri,uint256 nonce)");

    bytes32 private constant NFT_RENT_MINT_TYPE_HASH =
        keccak256(
            "NFTForRentWithMint(address lister,uint256 pricePerUnit,uint64 timeUnit,uint64 minDuration,uint64 maxDuration,string uri,uint256 nonce)"
        );
    bytes32 private constant NFT_RENT_TYPE_HASH =
        keccak256(
            "NFTForRent(address lister,uint256 tokenId,uint256 pricePerUnit,uint64 timeUnit,uint64 minDuration,uint64 maxDuration,uint256 nonce)"
        );

    mapping(bytes => bool) private usedSignature;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _version,
        address _royaltyRecipient,
        uint96 _royaltyBps
    ) ERC4907(_name, _symbol) EIP712(_name, _version) {
        _setDefaultRoyalty(_royaltyRecipient, _royaltyBps);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function tokenId() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function sale(
        address to,
        address lister,
        uint256 price,
        string memory uri,
        uint256 nonce,
        bytes calldata signature
    ) external payable whenNotPaused {
        require(lister != to, "Invalid address");
        require(_verify(lister, _hashNFTSale(lister, price, uri, nonce), signature), "Invalid/Used signature");
        require(msg.value >= price, "Insufficient balance");

        usedSignature[signature] = true;

        uint256 _tokenId = _mintWithURI(to, uri);

        _transferWithRefund(lister, price);

        emit NFTSale(lister, to, price, _tokenId, uri);
    }

    function rent(
        address to,
        address lister,
        uint256 _tokenId,
        uint256 pricePerUnit,
        uint64 timeUnit,
        uint64 minDuration,
        uint64 maxDuration,
        uint64 rentDuration,
        uint256 nonce,
        bytes calldata signature
    ) external payable whenNotPaused {
        require(lister != to, "Invalid address");
        require(rentDuration >= minDuration && rentDuration <= maxDuration, "Invalid duration");
        require(
            _verify(
                lister,
                _hashNFTRent(lister, _tokenId, pricePerUnit, timeUnit, minDuration, maxDuration, nonce),
                signature
            ),
            "Invalid/Used signature"
        );
        require(userOf(_tokenId) == address(0), "TokenId already rent out");

        string memory uri = tokenURI(_tokenId);
        uint256 totalPrice = (pricePerUnit * rentDuration) / timeUnit;
        require(msg.value >= totalPrice, "Insufficient balance");

        // then, set user role to renter (user)
        uint64 expiredAt = block.timestamp.toUint64() + rentDuration;
        setUser(_tokenId, to, expiredAt);

        usedSignature[signature] = true;

        _transferWithRefund(lister, totalPrice);

        emit NFTRent(lister, to, totalPrice, _tokenId, uri, expiredAt);
    }

    function rentWithMint(
        address to,
        address lister,
        uint256 pricePerUnit,
        uint64 timeUnit,
        uint64 minDuration,
        uint64 maxDuration,
        uint64 rentDuration,
        string memory uri,
        uint256 nonce,
        bytes calldata signature
    ) external payable whenNotPaused {
        require(lister != to, "Invalid address");
        require(rentDuration >= minDuration && rentDuration <= maxDuration, "Invalid duration");
        require(
            _verify(
                lister,
                _hashNFTRentWithMint(lister, pricePerUnit, timeUnit, minDuration, maxDuration, uri, nonce),
                signature
            ),
            "Invalid/Used signature"
        );

        uint256 totalPrice = (pricePerUnit * rentDuration) / timeUnit;
        require(msg.value >= totalPrice, "Insufficient balance");

        // first, mint NFT to lister (owner)
        uint256 _tokenId = _mintWithURI(lister, uri);

        // then, set user role to renter (user)
        uint64 expiredAt = block.timestamp.toUint64() + rentDuration;
        UserInfo storage info = _users[_tokenId];
        info.user = to;
        info.expires = expiredAt;

        usedSignature[signature] = true;

        _transferWithRefund(lister, totalPrice);

        emit NFTRent(lister, to, totalPrice, _tokenId, uri, expiredAt);
    }

    function _hashNFTSale(
        address _lister,
        uint256 _price,
        string memory _uri,
        uint256 _nonce
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(NFT_SALE_TYPE_HASH, _lister, _price, keccak256(bytes(_uri)), _nonce))
            );
    }

    function _hashNFTRent(
        address _lister,
        uint256 _tokenId,
        uint256 _pricePerUnit,
        uint64 _timeUnit,
        uint64 _minDuration,
        uint64 _maxDuration,
        uint256 _nonce
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        NFT_RENT_TYPE_HASH,
                        _lister,
                        _tokenId,
                        _pricePerUnit,
                        _timeUnit,
                        _minDuration,
                        _maxDuration,
                        _nonce
                    )
                )
            );
    }

    function _hashNFTRentWithMint(
        address _lister,
        uint256 _pricePerUnit,
        uint64 _timeUnit,
        uint64 _minDuration,
        uint64 _maxDuration,
        string memory _uri,
        uint256 _nonce
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        NFT_RENT_MINT_TYPE_HASH,
                        _lister,
                        _pricePerUnit,
                        _timeUnit,
                        _minDuration,
                        _maxDuration,
                        keccak256(bytes(_uri)),
                        _nonce
                    )
                )
            );
    }

    function _verify(address signer, bytes32 digest, bytes memory signature) internal view returns (bool) {
        return !usedSignature[signature] && SignatureChecker.isValidSignatureNow(signer, digest, signature);
    }

    function _mintWithURI(address to, string memory uri) internal returns (uint256) {
        uint256 _tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);

        return _tokenId;
    }

    function _transferWithRefund(address to, uint256 amount) internal {
        uint256 refundAmount = msg.value - amount;

        (bool sent, ) = to.call{ value: amount }("");
        require(sent, "Failed to transfer");

        (bool refunded, ) = msg.sender.call{ value: refundAmount }("");
        require(refunded, "Failed to refund");
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 _tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC4907, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, _tokenId, batchSize);
    }

    function _burn(uint256 _tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(_tokenId);
        _resetTokenRoyalty(_tokenId);
    }

    function tokenURI(uint256 _tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC4907, ERC2981, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
