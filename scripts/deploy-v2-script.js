let { ethers } = require("hardhat");

async function main() {
    let [owner] = await ethers.getSigners();

    let provider = "0x88757f2f99175387ab4c6a4b3067c77a695b0349";
    let bat = "0x2d12186Fbb9f9a8C28B3FfdD4c42920f8539D738";
    let FlashLoanAaveV2 = await ethers.getContractFactory("FlashLoanAaveV2");
    let flashLoanAaveV2 = await FlashLoanAaveV2.deploy(provider,{ gasLimit: 8000000 });
    await flashLoanAaveV2.deployed();
    console.log("flashLoanAaveV2:" + flashLoanAaveV2.address);

    let loanAmount = ethers.utils.parseUnits("1000", 18); //借1000个BAT
    await flashLoanAaveV2.flashSwap(bat, loanAmount, { gasLimit: 8000000 });
    console.log("已发起AAVE-V2闪电贷");
}   

    // We recommend this pattern to be able to use async/await everywhere
    // and properly handle errors.
    main()
        .then(() => process.exit(0))
        .catch(error => {
            console.error(error);
            process.exit(1);
        });
 