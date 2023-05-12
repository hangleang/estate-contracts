import { expect } from "chai";
import { deployments, ethers, getChainId } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { EstateContract } from "../types";
import { getContract } from "../utils/helpers";
import sales from "./sale_info.json";
import rental from "./rent_info.json";

describe("Estate Contract testcase", function () {
  before(async function () {
    this.accounts = await ethers.getSigners();
    this.chainId = await getChainId();
  });

  describe("Sale all element", function () {
    before(async function () {
      await deployments.fixture(["EstateContract"]);
      this.estate = await getContract<EstateContract>("EstateContract");
      this.name = await this.estate.name();
      expect(await this.estate.owner()).to.be.equal(this.accounts[0].address);
    });

    sales.forEach((sale, idx) => {
      it("element", async function () {
        /**
         * Account[1] (lister) creates signature
         */
        const nonce = await this.accounts[1].getTransactionCount("latest");
        const signature = await this.accounts[1]._signTypedData(
          // Domain
          {
            name: this.name,
            version: "1.0.0",
            chainId: this.chainId,
            verifyingContract: this.estate.address,
          },
          // Types
          {
            NFTForSale: [
              { name: "lister", type: "address" },
              { name: "price", type: "uint256" },
              { name: "uri", type: "string" },
              { name: "nonce", type: "uint256" },
            ],
          },
          // Value
          { ...sale, lister: this.accounts[1].address, nonce },
        );
        /**
         * Account[2] (buyer) buy the token using signature
         */
        await expect(
          this.estate
            .connect(this.accounts[2])
            .sale(this.accounts[2].address, this.accounts[1].address, sale.price, sale.uri, nonce, signature, {
              value: sale.price,
            }),
        )
          .to.emit(this.estate, "NFTSale")
          .withArgs(this.accounts[1].address, this.accounts[2].address, sale.price, idx, sale.uri);

        expect(await this.estate.ownerOf(idx)).to.eq(this.accounts[2].address);
      });
    });
  });

  describe("Replay attack", function () {
    before(async function () {
      await deployments.fixture(["EstateContract"]);
      this.estate = await getContract<EstateContract>("EstateContract");
      this.name = await this.estate.name();

      // list sale #0
      this.firstSale = sales[0];
      this.firstSale.nonce = await this.accounts[1].getTransactionCount("latest");
      this.firstSale.signature = await this.accounts[1]._signTypedData(
        // Domain
        {
          name: this.name,
          version: "1.0.0",
          chainId: this.chainId,
          verifyingContract: this.estate.address,
        },
        // Types
        {
          NFTForSale: [
            { name: "lister", type: "address" },
            { name: "price", type: "uint256" },
            { name: "uri", type: "string" },
            { name: "nonce", type: "uint256" },
          ],
        },
        // Value
        { ...this.firstSale, lister: this.accounts[1].address },
      );
    });

    it("mint once - success", async function () {
      await expect(
        this.estate.sale(
          this.accounts[2].address,
          this.accounts[1].address,
          this.firstSale.price,
          this.firstSale.uri,
          this.firstSale.nonce,
          this.firstSale.signature,
          {
            value: this.firstSale.price,
          },
        ),
      )
        .to.emit(this.estate, "NFTSale")
        .withArgs(this.accounts[1].address, this.accounts[2].address, this.firstSale.price, 0, this.firstSale.uri);
    });

    it("mint twice - failure", async function () {
      await expect(
        this.estate.sale(
          this.accounts[2].address,
          this.accounts[1].address,
          this.firstSale.price,
          this.firstSale.uri,
          this.firstSale.nonce,
          this.firstSale.signature,
          {
            value: this.firstSale.price,
          },
        ),
      ).to.be.revertedWith("Invalid/Used signature");
    });
  });

  describe("Rent all element", function () {
    before(async function () {
      await deployments.fixture(["EstateContract"]);
      this.estate = await getContract<EstateContract>("EstateContract");
      this.name = await this.estate.name();
      expect(await this.estate.owner()).to.be.equal(this.accounts[0].address);
    });

    rental.forEach((rent, idx) => {
      it("element", async function () {
        const { rentDuration, ...rentInfo } = rent;
        /**
         * Account[1] (lister) creates signature
         */
        const nonce = await this.accounts[1].getTransactionCount("latest");
        const signature = await this.accounts[1]._signTypedData(
          // Domain
          {
            name: this.name,
            version: "1.0.0",
            chainId: this.chainId,
            verifyingContract: this.estate.address,
          },
          // Types
          {
            NFTForRentWithMint: [
              { name: "lister", type: "address" },
              { name: "pricePerUnit", type: "uint256" },
              { name: "timeUnit", type: "uint64" },
              { name: "minDuration", type: "uint64" },
              { name: "maxDuration", type: "uint64" },
              { name: "uri", type: "string" },
              { name: "nonce", type: "uint256" },
            ],
          },
          // Value
          { ...rentInfo, lister: this.accounts[1].address, nonce },
        );
        /**
         * Account[2] (renter) rent the token using signature
         */
        const totalPrice = ethers.BigNumber.from(rent.pricePerUnit).mul(rent.rentDuration).div(rent.timeUnit);
        const expiredAt = ethers.BigNumber.from(await time.latest())
          .add(rentDuration)
          .add(1);
        await expect(
          this.estate
            .connect(this.accounts[2])
            .rentWithMint(
              this.accounts[2].address,
              this.accounts[1].address,
              rent.pricePerUnit,
              rent.timeUnit,
              rent.minDuration,
              rent.maxDuration,
              rentDuration,
              rent.uri,
              nonce,
              signature,
              {
                value: totalPrice,
              },
            ),
        )
          .to.emit(this.estate, "NFTRent")
          .withArgs(this.accounts[1].address, this.accounts[2].address, totalPrice, idx, rent.uri, expiredAt);

        expect(await this.estate.ownerOf(idx)).to.eq(this.accounts[1].address);
        expect(await this.estate.userOf(idx)).to.eq(this.accounts[2].address);
      });
    });
  });

  describe("Frontrun", function () {
    before(async function () {
      await deployments.fixture(["EstateContract"]);
      this.estate = await getContract<EstateContract>("EstateContract");
      this.name = await this.estate.name();

      // list sale #0
      this.firstRent = rental[0];
      this.firstRent.nonce = await this.accounts[1].getTransactionCount("latest");

      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { rentDuration, ...rentInfo } = this.firstRent;
      this.firstRent.signature = await this.accounts[1]._signTypedData(
        // Domain
        {
          name: this.name,
          version: "1.0.0",
          chainId: this.chainId,
          verifyingContract: this.estate.address,
        },
        // Types
        {
          NFTForRentWithMint: [
            { name: "lister", type: "address" },
            { name: "pricePerUnit", type: "uint256" },
            { name: "timeUnit", type: "uint64" },
            { name: "minDuration", type: "uint64" },
            { name: "maxDuration", type: "uint64" },
            { name: "uri", type: "string" },
            { name: "nonce", type: "uint256" },
          ],
        },
        // Value
        { ...rentInfo, lister: this.accounts[1].address },
      );
    });

    it("mint with wrong signer - failure", async function () {
      const totalPrice = ethers.BigNumber.from(this.firstRent.pricePerUnit)
        .mul(this.firstRent.rentDuration)
        .div(this.firstRent.timeUnit);
      await expect(
        this.estate
          .connect(this.accounts[2])
          .rentWithMint(
            this.accounts[2].address,
            this.accounts[0].address,
            this.firstRent.pricePerUnit,
            this.firstRent.timeUnit,
            this.firstRent.minDuration,
            this.firstRent.maxDuration,
            this.firstRent.rentDuration,
            this.firstRent.uri,
            this.firstRent.nonce,
            this.firstRent.signature,
            {
              value: totalPrice,
            },
          ),
      ).to.be.revertedWith("Invalid/Used signature");
    });

    it("list/mint with the same account - failure", async function () {
      const totalPrice = ethers.BigNumber.from(this.firstRent.pricePerUnit)
        .mul(this.firstRent.rentDuration)
        .div(this.firstRent.timeUnit);
      await expect(
        this.estate
          .connect(this.accounts[1])
          .rentWithMint(
            this.accounts[1].address,
            this.accounts[1].address,
            this.firstRent.pricePerUnit,
            this.firstRent.timeUnit,
            this.firstRent.minDuration,
            this.firstRent.maxDuration,
            this.firstRent.rentDuration,
            this.firstRent.uri,
            this.firstRent.nonce,
            this.firstRent.signature,
            {
              value: totalPrice,
            },
          ),
      ).to.be.revertedWith("Invalid address");
    });
  });
});
