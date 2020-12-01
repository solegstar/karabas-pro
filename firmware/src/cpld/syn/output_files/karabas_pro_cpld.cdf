/* Quartus II 64-Bit Version 13.0.1 Build 232 06/12/2013 Service Pack 1 SJ Web Edition */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Cfg)
		Device PartName(EPM3128AT100) Path("D:/GitHub/karabas-pro/firmware/src/cpld/syn/output_files/") File("karabas_pro_cpld.pof") MfrSpec(OpMask(7));
	P ActionCode(Ign)
		Device PartName(EP4CE6E22) MfrSpec(OpMask(0) FullPath("D:/GitHub/karabas-pro/firmware/src/fpga/profi/syn/karabas_pro.sof"));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;
