import { expect } from "chai";
import hre from "hardhat";
import { parseEther } from 'viem';

describe("SolidGrowth", function () {
    const addressNull: `0x${string}` = '0x0000000000000000000000000000000000000000';

    async function setupDeploy() {
        const [owner, wallet1, wallet2, wallet3, wallet4, wallet5, wallet6, wallet7,
        wallet8, wallet9, wallet10, wallet11, wallet12] = await hre.viem.getWalletClients();
        const usdt_instance = await hre.viem.deployContract("USDT", []);
        const solidgrowth_instance = await hre.viem.deployContract("SolidGrowth", [usdt_instance.address]);

        return { owner, wallet1, wallet2, wallet3, wallet4, wallet5, wallet6, wallet7,
            wallet8, wallet9, wallet10, wallet11, wallet12, usdt_instance, solidgrowth_instance };
    }

    describe("Deployment", function () {
        it("Deploy token example contract", async function () {
            const { usdt_instance } = await setupDeploy();
            expect(usdt_instance.address).to.have.lengthOf(42);
        });

        it("Deploy SolidGrowth contract", async function () {
            const { solidgrowth_instance } = await setupDeploy();
            expect(solidgrowth_instance.address).to.have.lengthOf(42);
        });
    });

    describe("Investment", async function () {
        it("First investment", async function () {
            const { owner, wallet1, wallet2, usdt_instance, solidgrowth_instance } = await setupDeploy();

            const amountInvest = parseEther("1000");
            await usdt_instance.write.approve([solidgrowth_instance.address, amountInvest], {
                account: wallet1.account.address
            });
            const approveEvents = await usdt_instance.getEvents.Approval();
            expect(approveEvents).to.have.lengthOf(1);
            expect(approveEvents[0].args.owner?.toLowerCase()).to.equal(wallet1.account.address);
            expect(approveEvents[0].args.spender?.toLowerCase()).to.equal(solidgrowth_instance.address);
            const allowance = await usdt_instance.read.allowance([wallet1.account.address, solidgrowth_instance.address]);
            expect(allowance).to.equal(amountInvest);

            await expect(
                solidgrowth_instance.write.invest([addressNull, wallet2.account.address, amountInvest], {
                    account: wallet1.account.address
                })
            ).to.be.rejectedWith("Referrer not found");
            await expect(
                solidgrowth_instance.write.invest([addressNull, owner.account.address, parseEther("10")], {
                    account: wallet1.account.address
                })
            ).to.be.rejectedWith("Investment amount out of range");
            await usdt_instance.write.transfer([wallet1.account.address, amountInvest]);
            await solidgrowth_instance.write.invest([addressNull, owner.account.address, amountInvest], {
                account: wallet1.account.address
            });
            const investEvents = await solidgrowth_instance.getEvents.Invested();
            expect(investEvents).to.have.lengthOf(1);
            expect(investEvents[0].args.developerAddress?.toLowerCase()).to.equal(addressNull);
            expect(investEvents[0].args.referrer?.toLowerCase()).to.equal(owner.account.address);
            expect(investEvents[0].args.investor?.toLowerCase()).to.equal(wallet1.account.address);
            expect(investEvents[0].args.amount).to.equal(amountInvest);
        });

        it("Try 11 investment", async function () {
            const wallets = await hre.viem.getWalletClients();
            const { owner, wallet12, usdt_instance, solidgrowth_instance } = await setupDeploy();
            
            const amountInvest = parseEther("1000");
            await usdt_instance.write.transfer([wallet12.account.address, await usdt_instance.read.balanceOf([owner.account.address])]);
            for (let index = 1; index <= 11; index++) {
                await usdt_instance.write.transfer([wallets[index].account.address, amountInvest], {
                    account: wallet12.account.address
                });
                await usdt_instance.write.approve([solidgrowth_instance.address, amountInvest], {
                    account: wallets[index].account.address
                });
                await solidgrowth_instance.write.invest([addressNull, wallets[index - 1].account.address, amountInvest], {
                    account: wallets[index].account.address
                });
            }
            for (let index = 0; index <= 11; index++) {
                console.log(`${index}. ${wallets[index].account.address} (${Number(await usdt_instance.read.balanceOf([wallets[index].account.address])) / (10 ** 18)} USDT)`);
            }
            console.log(`SolidGrowth: ${solidgrowth_instance.address} (${Number(await usdt_instance.read.balanceOf([solidgrowth_instance.address])) / (10 ** 18)} USDT)`);
        });
    });

    describe("Validate URI", function () {
        it("Update defaultURI & show URI", async function () {
            const { owner, wallet1, wallet2, usdt_instance, solidgrowth_instance } = await setupDeploy();

            const amountInvest = parseEther("1000");
            await usdt_instance.write.approve([solidgrowth_instance.address, amountInvest], {
                account: wallet1.account.address
            });

            await usdt_instance.write.transfer([wallet1.account.address, amountInvest]);
            await solidgrowth_instance.write.invest([addressNull, owner.account.address, amountInvest], {
                account: wallet1.account.address
            });
            expect(await solidgrowth_instance.read.tokenURI([1n])).to.equal("");
            await solidgrowth_instance.write.updateBaseURI(["ipfs://test"]);
            expect(await solidgrowth_instance.read.tokenURI([1n])).to.equal("ipfs://test");
        });
    });
});
